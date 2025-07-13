#!/bin/bash

# 日誌文件
LOG_FILE="/var/log/monitor_myst.log"
# 輸出 CSV 文件
SUCCESS_CSV="/root/channel_address.csv"
FAIL_CSV="/root/fail_channel_address_container.csv"
# 臨時文件存放 identities.json
TEMP_FILE="/tmp/identities.json"

# 確保日誌文件存在
touch "$LOG_FILE"
echo "Starting channel address collection at $(date)" | tee -a "$LOG_FILE"

# 獲取所有 myst 容器名稱
if [ -s "$FAIL_CSV" ]; then
  # 從 FAIL_CSV 讀取每行當做容器名稱，並以空白為分隔合併成一行字串
  containers=$(awk 'NF' "$FAIL_CSV" | xargs)
  echo "Using containers from $FAIL_CSV: $containers" | tee -a "$LOG_FILE"
else
  # 使用 docker ps 查詢 myst 容器
  containers=$(timeout 240 docker ps --filter "name=myst" --format "{{.Names}}" 2>&1)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$containers" | grep -qi "Error response from daemon"; then
    echo "Error getting container list: $containers" | tee -a "$LOG_FILE"
    exit 1
  fi
fi

# 如果沒有 myst 容器，記錄並退出
if [ -z "$containers" ]; then
  echo "No myst containers found" | tee -a "$LOG_FILE"
  exit 0
fi

# 處理每個容器
for container in $containers; do
  echo "Processing container $container..." | tee -a "$LOG_FILE"

  # 獲取 provider_id
  output=$(timeout 240 docker exec "$container" curl -s http://localhost:4050/identities -o "$TEMP_FILE" 2>&1)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Failed to get identities for $container: $output" | tee -a "$LOG_FILE"
    echo "$container" >> "$FAIL_CSV"
    continue
  fi
  output=$(timeout 240 docker exec "$container" jq -r '.identities[0].id' "$TEMP_FILE" 2>&1)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Failed to parse identities for $container: $output" | tee -a "$LOG_FILE"
    echo "$container" >> "$FAIL_CSV"
    continue
  fi

  # 清理 identities.json
  clean=$(timeout 240 docker exec "$container" rm -f /tmp/identities.json 2>&1)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$clean" | grep -qi "Error response from daemon"; then
    echo "Failed to clean up identities.json for $container: $clean" | tee -a "$LOG_FILE"
  else
    echo "Cleaned up identities.json for $container" | tee -a "$LOG_FILE"
  fi

  # 提取 provider_id
  provider_id=$(echo "$output" | tr -d '\r')
  if [ -z "$provider_id" ] || [ "$provider_id" = "null" ]; then
    echo "No valid provider_id found for $container" | tee -a "$LOG_FILE"
    echo "$container" >> "$FAIL_CSV"
    continue
  fi
  echo "Provider ID for $container: $provider_id" | tee -a "$LOG_FILE"

  # 獲取 channel address
  output=$(timeout 900 docker exec "$container" myst cli identities get "$provider_id" 2>&1)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error"; then
    echo "Failed to get channel address for $container: $output" | tee -a "$LOG_FILE"
    echo "$container" >> "$FAIL_CSV"
    continue
  fi

  # 提取 channel address
  channel_address=$(echo "$output" | grep "Channel address" | awk -F': ' '{print $2}' | tr -d '[:space:]')
  if [ -z "$channel_address" ]; then
    echo "No channel address found for $container" | tee -a "$LOG_FILE"
    echo "$container" >> "$FAIL_CSV"
    continue
  fi
  echo "Channel address for $container: $channel_address" | tee -a "$LOG_FILE"

  # 寫入成功 CSV
  echo "$container,$channel_address" >> "$SUCCESS_CSV"

done

echo "Channel address collection completed at $(date)" | tee -a "$LOG_FILE"
echo "Success CSV: $SUCCESS_CSV" | tee -a "$LOG_FILE"
echo "Fail CSV: $FAIL_CSV" | tee -a "$LOG_FILE"
