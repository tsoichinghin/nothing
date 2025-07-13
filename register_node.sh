#!/bin/bash

# 日誌文件
LOG_FILE="/var/log/monitor_myst.log"
# 輸出 CSV 文件
FAIL_CSV="/root/fail_register.csv"
# 臨時文件存放 identities.json
TEMP_FILE="/tmp/identities.json"
# 固定的 withdrawal address
WITHDRAWAL_ADDRESS="0x9Fb7c364de014ED5499B48Db498b62720E8FD9E8"

# 確保日誌文件存在
touch "$LOG_FILE"
echo "Starting node registration at $(date)" | tee -a "$LOG_FILE"

# 獲取所有 myst 容器名稱
output=$(timeout 240 docker ps --filter "name=myst" --format "{{.Names}}" 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
  echo "Error getting container list: $output" | tee -a "$LOG_FILE"
  exit 1
fi

# 如果沒有 myst 容器，記錄並退出
if [ -z "$output" ]; then
  echo "No myst containers found" | tee -a "$LOG_FILE"
  exit 0
fi

# 處理每個容器
for container in $output; do
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
  clean=$(timeout 240 docker exec "$container" rm -f /tmp/identities.json 2>&1)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$clean" | grep -qi "Error response from daemon"; then
    echo "Failed to clean up identities.json for $container: $clean" | tee -a "$LOG_FILE"
  else
    echo "Cleaned up identities.json for $container" | tee -a "$LOG_FILE"
  fi
  provider_id=$(echo "$output" | tr -d '\r')
  if [ -z "$provider_id" ] || [ "$provider_id" = "null" ]; then
    echo "No valid provider_id found for $container" | tee -a "$LOG_FILE"
    echo "$container" >> "$FAIL_CSV"
    continue
  fi
  echo "Provider ID for $container: $provider_id" | tee -a "$LOG_FILE"

  max_attempts=5
  attempt=1
  registration_status=""
  output=$(timeout 900 docker exec "$container" myst cli identities register "$provider_id" "$WITHDRAWAL_ADDRESS" 2>&1)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error"; then
    echo "Failed to register identity for $container: $output" | tee -a "$LOG_FILE"
    echo "$container" >> "$FAIL_CSV"
    continue
  fi
  echo "Identity registration attempted for $container" | tee -a "$LOG_FILE"
  while [ $attempt -le $max_attempts ]; do
    output=$(timeout 900 docker exec "$container" myst cli identities get "$provider_id" 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error"; then
      echo "Failed to check registration status for $container (attempt $attempt): $output" | tee -a "$LOG_FILE"
      echo "$container" >> "$FAIL_CSV"
      break
    fi

    # 提取 Registration Status
    registration_status=$(echo "$output" | grep "Registration Status" | awk -F': ' '{print $2}' | tr -d '[:space:]')
    if [ "$registration_status" = "Registered" ]; then
      echo "Container $container is Registered" | tee -a "$LOG_FILE"
      break
    elif [ "$registration_status" = "InProgress" ]; then
      echo "Container $container registration InProgress (attempt $attempt), waiting 60 seconds..." | tee -a "$LOG_FILE"
      if [ $attempt -eq $max_attempts ]; then
        echo "Container $container still InProgress after $max_attempts attempts, adding to fail CSV" | tee -a "$LOG_FILE"
        echo "$container" >> "$FAIL_CSV"
        break
      fi
      sleep 60
      attempt=$((attempt + 1))
    elif [ "$registration_status" = "Unregistered" ]; then
      echo "Container $container registration Unregistered (attempt $attempt), waiting 60 seconds..." | tee -a "$LOG_FILE"
      if [ $attempt -eq $max_attempts ]; then
        echo "Container $container still InProgress after $max_attempts attempts, adding to fail CSV" | tee -a "$LOG_FILE"
        echo "$container" >> "$FAIL_CSV"
        break
      fi
      sleep 60
      attempt=$((attempt + 1))
    else
      echo "Container $container is not Registered, status: $registration_status" | tee -a "$LOG_FILE"
      echo "$container" >> "$FAIL_CSV"
      break
    fi
  done
done

echo "Node registration completed at $(date)" | tee -a "$LOG_FILE"
echo "Fail CSV: $FAIL_CSV" | tee -a "$LOG_FILE"
