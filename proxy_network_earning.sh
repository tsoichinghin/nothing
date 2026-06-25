#!/bin/bash

# ==================== 設定區 ====================
PROXY_FILE="/root/ip.txt"

# 軟體帳密與 Token 設定
TM_TOKEN="Nwma6KuxfvF/jJUsBCtyl/3cHfIoEA8oxdBA7RkgKN0="
PS_CID="84Vb"
RP_EMAIL="tsoichinghin@gmail.com"
RP_API_KEY="a17ebebc-ad88-40ba-ba85-9eaee015e1f4"
VPS="wse1"
# ===============================================

# 檢查 ip.txt 是否存在
if [ ! -f "$PROXY_FILE" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')]【錯誤】找不到 $PROXY_FILE，請先建立該檔案並填入 Proxy 清單！"
  exit 1
fi

# 刪除所有現有容器
cleanup_all() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 正在強制刪除所有現有容器..."
  docker rm -f $(docker ps -a -q) 2>/dev/null || true
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 所有容器已清除。"
}

main() {
  # 計數器，用來生成容器編號
  number=1

  # 逐行讀取 ip.txt
  while IFS= read -r line || [ -n "$line" ]; do
    # 忽略空行
    [ -z "$line" ] && continue

    ip=$(echo "$line" | cut -d':' -f1)
    port=$(echo "$line" | cut -d':' -f2)
    username=$(echo "$line" | cut -d':' -f3)
    password=$(echo "$line" | cut -d':' -f4)

    echo "--------------------------------------------------"
    echo "正在部署第 $number 組多重收益矩陣..."
    echo "Proxy IP: $ip:$port"
    echo "設備名稱: $VPS-ip$number"
    echo "--------------------------------------------------"

    # 1. 啟動 Traffmonetizer (tm)
    docker run -d \
      --name "tm$number" \
      --restart always \
      --cpu-period=100000 --cpu-quota=10000 \
      --cap-add=NET_ADMIN \
      -e PROXY_IP="$ip" \
      -e PROXY_PORT="$port" \
      -e PROXY_USER="$username" \
      -e PROXY_PASSWORD="$password" \
      -e TM_TOKEN="$TM_TOKEN" \
      -e DEVICE_NAME="$VPS-$number" \
      tsoichinghin/proxytm:latest

    # 2. 啟動 PacketStream (ps)
    docker run -d \
      --name "psc$number" \
      --restart always \
      --cpu-period=100000 --cpu-quota=10000 \
      --cap-add=NET_ADMIN \
      -e PROXY_IP="$ip" \
      -e PROXY_PORT="$port" \
      -e PROXY_USER="$username" \
      -e PROXY_PASSWORD="$password" \
      -e CID="$PS_CID" \
      tsoichinghin/proxypsc:latest
    
    # 3. 啟動 Repocket (rp)
    docker run -d \
      --name "rp$number" \
      --restart always \
      --cpu-period=100000 --cpu-quota=10000 \
      --cap-add=NET_ADMIN \
      -e PROXY_IP="$ip" \
      -e PROXY_PORT="$port" \
      -e PROXY_USER="$username" \
      -e PROXY_PASSWORD="$password" \
      -e RP_EMAIL="$RP_EMAIL" \
      -e RP_API_KEY="$RP_API_KEY" \
      tsoichinghin/proxyrp:latest

    number=$((number + 1))

    sleep 5

  done < "$PROXY_FILE"

  echo "=============================================="
  echo "【成功】所有 $(((number - 1))) 組多重收益矩陣部署完成！"
  echo "共啟動了 $(((number - 1) * 3)) 個容器。"
  echo "=============================================="
}

# ==================== 主流程 ====================
while true; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== 容器重啟腳本開始 ====="
  check_and_create_networks
  cleanup_all
  main
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== 所有批次處理完成 ====="
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 腳本結束"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 執行完成，等待 12 小時..."
  sleep 43200
done
