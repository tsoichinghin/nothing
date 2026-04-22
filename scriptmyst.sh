#!/bin/bash

# ==================== 設定區 ====================
ROUND_COUNT=0
START_NUMBER=0
END_NUMBER=0
BATCH_SIZE=50
SLEEP_BETWEEN_BATCH=900          # 15 分鐘 = 900 秒
MIN_RUNNING_SECONDS=600           # 至少運行 10 分鐘 = 600 秒
DOCKER_IMAGE="tsoichinghin/ovpnmyst:latest"

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
    local name="myst${num}"
    local net="vpn${num}"

    # 先檢查 network 是否存在，不存在則建立
    docker network ls -q -f name="^${net}$" | grep -q . || {
        echo "建立 network: ${net}"
        docker network create "${net}" >/dev/null 2>&1
    }

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 啟動容器 tm${num} (OVPN: ${ovpn_file})"

    docker run -d --restart always \
        --name "${name}" \
        --network "${net}" \
        --log-driver json-file --log-opt max-size=10m \
        --cap-add=NET_ADMIN --device=/dev/net/tun \
        --cpu-period=100000 --cpu-quota=5000 \
        --memory="32m" \
        -v /root/ovpn:/vpn \
        -v /root/mystcsv:/output \
        -v /root/myst/"${name}":/root/.mysterium \
        -e OVPN_FILE="${ovpn_file}" \
        -e CONTAINER_NAME="${name}" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1

    # 檢查是否真的啟動成功
    sleep 5
    if ! docker ps --filter "name=${name}" --format '{{.Status}}' | grep -q "Up"; then
        echo "容器 ${name} 啟動失敗，跳過..."
    fi
}

# 檢查一批容器的健康狀態
check_batch() {
    local start=$1
    local end=$2

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待 ${SLEEP_BETWEEN_BATCH} 秒後檢查 ${start} ~ ${end} 的全量 Log..."

    sleep "${SLEEP_BETWEEN_BATCH}"

    for (( num=start; num<=end; num++ )); do
        local name="myst${num}"

        # 1. 檢查容器是否存在
        if ! docker ps -a -q -f name="^${name}$" | grep -q .; then
            echo "容器 ${name} 不存在，跳過..."
            continue
        fi

        # 2. 獲取該容器的所有 Log 並檢查關鍵字
        # 移除 --tail 代表從頭開始讀
        if docker logs "${name}" 2>&1 | grep -q "Starting Mysterium service..."; then
            echo "容器 ${name} 正常：已在歷史紀錄中找到啟動成功字樣。"
        else
            echo "容器 ${name} 異常：全量 Log 中未發現啟動字樣，正在刪除..."
            docker rm -f "${name}" >/dev/null 2>&1
        fi
    done
}

withdraw() {
    echo "===== 提款程序開始 ====="
    containers=$(docker ps --filter "name=myst" --format "{{.Names}}")
    for container in $containers; do
        echo "正在處理容器: $container"
        ids=$(docker exec "$container" curl -s http://localhost:4050/identities | jq -r '.identities[].id' 2>/dev/null)

        if [ -z "$ids" ] || [ "$ids" = "null" ]; then
            echo "無法從 $container 提取任何 ID，跳過"
            continue
        fi

        for provider_id in $ids; do
            echo "正在對 ID: $provider_id 進行結算 (settle)..."
            if ! timeout 300 docker exec "$container" myst cli identities settle "$provider_id"; then
                echo "[WARNING] 容器 $container 提款超時或失敗 (ID: $provider_id)"
            fi
        done
        echo "$container 提款動作執行完畢"
    done
}

# ==================== 主流程 ====================
while true; do
    echo "===== 容器重啟腳本開始 ====="
    ROUND_COUNT=$((ROUND_COUNT + 1))
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

    if [ "$ROUND_COUNT" -ge 60 ]; then
      withdraw
      ROUND_COUNT = 0
    fi
done
