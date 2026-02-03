#!/bin/bash

# ==================== 設定區 ====================
START_NUMBER=0
END_NUMBER=0
BATCH_SIZE=50
SLEEP_BETWEEN_BATCH=900          # 15 分鐘 = 900 秒
MIN_RUNNING_SECONDS=600           # 至少運行 10 分鐘 = 600 秒
DOCKER_IMAGE="tsoichinghin/ovpn-traff:latest"
TOKEN="b6UZLbAQ3BpAX02rVwk/H0qtRURyE5YHUi2OQnIZD7o="

# ==================== 函數 ====================

# 刪除所有現有容器
cleanup_all() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 正在強制刪除所有現有容器..."
    docker rm -f $(docker ps -a -q) 2>/dev/null || true
    echo "所有容器已清除。"
}

# 啟動單個容器
start_container() {
    local num=$1
    local ovpn_file="ip${num}.ovpn"
    local name="tm${num}"
    local net="vpn${num}"
    local device="tm${num}"

    # 先檢查 network 是否存在，不存在則建立
    docker network ls -q -f name="^${net}$" | grep -q . || {
        echo "建立 network: ${net}"
        docker network create "${net}" >/dev/null 2>&1
    }

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 啟動容器 tm${num} (OVPN: ${ovpn_file})"

    docker run -d --restart always --name "${name}" \
        --network "${net}" \
        --cpu-period=100000 --cpu-quota=10000 \
        --log-driver json-file --log-opt max-size=10m \
        --cap-add=NET_ADMIN --device=/dev/net/tun \
        --memory="32m" \
        -v /root/ovpn:/vpn \
        -e OVPN_FILE="${ovpn_file}" \
        -e TM_TOKEN="${TOKEN}" \
        -e DEVICE_NAME="${device}" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1

    # 檢查是否真的啟動成功
    sleep 5
    if ! docker ps --filter "name=${name}" --format '{{.Status}}' | grep -q "Up"; then
        echo "容器 tm${num} 啟動失敗，跳過..."
    fi
}

# 檢查一批容器的健康狀態
check_batch() {
    local start=$1
    local end=$2

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待 ${SLEEP_BETWEEN_BATCH} 秒後檢查 ${start} ~ ${end} ..."

    sleep "${SLEEP_BETWEEN_BATCH}"

    for (( num=start; num<=end; num++ )); do
        local name="tm${num}"

        if ! docker ps -q -f name="^${name}$" | grep -q .; then
            # 容器不存在（可能已退出）
            echo "容器 ${name} 不存在，跳過..."
            continue
        fi

        local status=$(docker inspect --format '{{.State.Status}}' "${name}")
        local started_at=$(docker inspect --format '{{.State.StartedAt}}' "${name}")
        local running_sec=$(($(date +%s) - $(date -d "${started_at}" +%s)))

        if [[ "${status}" == "restarting" ]] || [[ ${running_sec} -lt ${MIN_RUNNING_SECONDS} ]]; then
            echo "容器 ${name} 異常 (status=${status}, running=${running_sec}s)，刪除..."
            docker rm -f "${name}" >/dev/null 2>&1
        else
            echo "容器 ${name} 正常 (running=${running_sec}s)"
        fi
    done
}

# ==================== 主流程 ====================
while true; do
    echo "===== 容器重啟腳本開始 ====="
    echo "範圍: ${START_NUMBER} ~ ${END_NUMBER}"
    echo "每批: ${BATCH_SIZE} 個，批間等待: ${SLEEP_BETWEEN_BATCH}s"

    cleanup_all

    current=$START_NUMBER
    while [ $current -le $END_NUMBER ]; do
        batch_end=$((current + BATCH_SIZE - 1))
        if [ $batch_end -gt $END_NUMBER ]; then
            batch_end=$END_NUMBER
        fi

        echo "===== 處理批次: ${current} ~ ${batch_end} ====="

        for ((num=current; num<=batch_end; num++)); do
            start_container "$num"
        done

        check_batch "$current" "$batch_end"

        current=$((batch_end + 1))
    done

    echo "===== 所有批次處理完成 ====="
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 腳本結束"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 執行完成，等待 12 小時..."
    sleep 43200
done
