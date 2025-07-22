#!/bin/bash

SERVICES="dvpn scraping quic_scraping wireguard data_transfer"
current_time=$(date +%s)
if [ ! -f /root/next_payout_date.txt ]; then
  next_payout_date=$((current_time + 30*24*60*60))
  echo "$next_payout_date" > /root/next_payout_date.txt
  echo "Initial next payout date: $(date -d @$next_payout_date)" | tee -a /var/log/monitor_myst.log
fi

# 函數：檢查 Docker 服務狀態
check_docker_service() {
  echo "Checking Docker service status..." | tee -a /var/log/monitor_myst.log
  if ! systemctl is-active --quiet docker; then
    echo "Docker service is not active, attempting to start..." | tee -a /var/log/monitor_myst.log
    output=$(timeout 600 sudo systemctl start docker 2>&1)
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
      echo "Failed to start Docker service: $output" | tee -a /var/log/monitor_myst.log
      echo "Systemctl start docker timed out, initiating reboot..." | tee -a /var/log/monitor_myst.log
      sudo reboot
      return 1
    fi
    sleep 10
    if ! systemctl is-active --quiet docker; then
      echo "Docker service still not active after start attempt" | tee -a /var/log/monitor_myst.log
      return 1
    fi
  fi
  echo "Docker service is active" | tee -a /var/log/monitor_myst.log
  return 0
}

restart_myst() {
  local container=$1
  echo "Restarting container $container..." | tee -a /var/log/monitor_myst.log
  output=$(timeout 300 docker rm -f "$container" 2>&1)
  local exit_code=$?
  if [ $exit_code -eq 0 ] && ! echo "$output" | grep -qi "Error response from daemon"; then
    echo "Container $container remove successfully" | tee -a /var/log/monitor_myst.log
    output=$(timeout 300 docker run -d --restart always --network container:vpni${container#myst} --cpu-period=100000 \
      --log-driver json-file --log-opt max-size=50m --log-opt max-file=3 --memory="64m" \
      --cpu-quota=10000 --name ${container} --cap-add NET_ADMIN \
      -v ${container}:/var/lib/mysterium-node tsoichinghin/myst:latest \
      --ui.address=0.0.0.0 --tequilapi.address=0.0.0.0 --data-dir=/var/lib/mysterium-node \
      service --agreed-terms-and-conditions 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to start myst container $container: $output" | tee -a /var/log/monitor_myst.log
      return 1
    fi
    return 0
  else
    echo "Failed to remove container $container: $output" | tee -a /var/log/monitor_myst.log
    return 1
  fi
}

# 函數：安全重啟 Docker 服務
restart_docker_service() {
  echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
  output=$(timeout 600 sudo systemctl restart docker 2>&1)
  local exit_code=$?
  if [ $exit_code -eq 0 ] && ! echo "$output" | grep -qi "Error"; then
    echo "Docker service restarted successfully" | tee -a /var/log/monitor_myst.log
    echo "Waiting 60 seconds for Docker to stabilize..." | tee -a /var/log/monitor_myst.log
    sleep 60
    if check_docker_service; then
      echo "Docker service is active after restart" | tee -a /var/log/monitor_myst.log
      return 0
    fi
    echo "Docker service not active after restart, proceeding to stop/start..." | tee -a /var/log/monitor_myst.log
  else
    echo "Failed to restart Docker service (exit code: $exit_code): $output" | tee -a /var/log/monitor_myst.log
  fi
  echo "All attempts to restart Docker failed, initiating system reboot..." | tee -a /var/log/monitor_myst.log
  sudo reboot
  return 1
}

docker_network_recreate() {
  local container=$1
  echo "Recreating Docker network for container $container..." | tee -a /var/log/monitor_myst.log
  rm=$(timeout 240 docker network rm vpn$container 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Failed to remove network vpn$container: $rm" | tee -a /var/log/monitor_myst.log
    return 1
  fi
  echo "Network vpn$container removed successfully" | tee -a /var/log/monitor_myst.log
  create=$(timeout 240 docker network create vpn$container 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Failed to create network vpn$container: $create" | tee -a /var/log/monitor_myst.log
    return 1
  fi
  echo "Network vpn$container created successfully" | tee -a /var/log/monitor_myst.log
  return 0
}

# 函數：清理容器元數據（包括元數據目錄和 myst.db）
clean_container_metadata() {
  local container=$1
  local volume_path="/var/lib/docker/volumes/${container}/_data/mainnet/db/myst.db"
  if [ -f "$volume_path" ]; then
    # 備份 myst.db
    local backup_dir="/root/backup_myst/backup_myst${num}_$(date +%F_%H%M%S)"
    echo "Backing up myst.db for $container to $backup_dir..." | tee -a /var/log/monitor_myst.log
    mkdir -p "$backup_dir"
    cp -r "/var/lib/docker/volumes/${container}/_data" "$backup_dir" 2>&1 | tee -a /var/log/monitor_myst.log
    if [ $? -ne 0 ]; then
      echo "Failed to backup myst.db for $container" | tee -a /var/log/monitor_myst.log
      return 1
    fi
    # 刪除 myst.db
    echo "Removing myst.db for $container..." | tee -a /var/log/monitor_myst.log
    rm -f "$volume_path" 2>&1 | tee -a /var/log/monitor_myst.log
    if [ $? -ne 0 ]; then
      echo "Failed to remove myst.db for $container" | tee -a /var/log/monitor_myst.log
      return 1
    fi
  else
    echo "No myst.db file found for $container at $volume_path" | tee -a /var/log/monitor_myst.log
  fi
}

# 函數：移除容器（僅執行 docker rm -f 和進程殺死）
remove_container() {
  local container=$1
  local max_attempts=3
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt to remove container $container..." | tee -a /var/log/monitor_myst.log
    output=$(timeout 300 docker rm -f "$container" 2>&1)
    local exit_code=$?
    if [ $exit_code -eq 0 ] && ! echo "$output" | grep -qi "Error response from daemon"; then
      echo "Successfully removed $container" | tee -a /var/log/monitor_myst.log
      return 0
    fi
    echo "Failed to remove $container: $output" | tee -a /var/log/monitor_myst.log

    # 檢查是否為“removal in progress”錯誤
    if echo "$output" | grep -qi "removal of container.*is already in progress"; then
      echo "Container $container is stuck in removal, attempting cleanup..." | tee -a /var/log/monitor_myst.log
      output=$(timeout 240 docker stop "$container" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] && echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to stop $container: $output" | tee -a /var/log/monitor_myst.log
      fi
      sleep 5
    fi

    # 嘗試殺死容器進程
    local CONTAINER_PID
    CONTAINER_PID=$(timeout 300 docker inspect "$container" 2>&1 | jq -r .[0].State.Pid 2>/dev/null)
    exit_code=$?
    if [ $exit_code -eq 0 ] && [ -n "$CONTAINER_PID" ] && [ "$CONTAINER_PID" != "0" ]; then
      echo "Killing container process PID $CONTAINER_PID for $container..." | tee -a /var/log/monitor_myst.log
      sudo kill -9 "$CONTAINER_PID" 2>/dev/null
      sleep 5
    else
      echo "Failed to inspect $container or no valid PID: $CONTAINER_PID" | tee -a /var/log/monitor_myst.log
    fi

    # 再次嘗試移除
    output=$(timeout 300 docker rm -f "$container" 2>&1)
    exit_code=$?
    if [ $exit_code -eq 0 ] && ! echo "$output" | grep -qi "Error response from daemon"; then
      echo "Successfully removed $container after retry" | tee -a /var/log/monitor_myst.log
      return 0
    fi

    echo "Retry $attempt failed for $container: $output" | tee -a /var/log/monitor_myst.log
    attempt=$((attempt + 1))
    sleep 10
  done

  echo "Failed to remove $container after $max_attempts attempts, skipping..." | tee -a /var/log/monitor_myst.log
  return 1
}

# 函數：處理 Docker 重啟後的容器
handle_docker_restart() {
  echo "Handling Docker restart at $(date)" | tee -a /var/log/monitor_myst.log

  # 獲取所有處於 exited 或 restarting 狀態的 myst 和 vpni 容器
  local output
  output=$(timeout 300 docker ps -a --filter "name=myst|vpni" --filter "status=exited" --filter "status=restarting" --filter "status=created" --filter "status=dead" --format "{{.Names}}" 2>&1)
  local exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Error getting container list: $output" | tee -a /var/log/monitor_myst.log
    if ! restart_docker_service; then
      echo "Exiting handle_docker_restart due to Docker service failure" | tee -a /var/log/monitor_myst.log
      return 1
    fi
    # 重試獲取容器列表
    output=$(timeout 300 docker ps -a --filter "name=myst|vpni" --filter "status=exited" --filter "status=restarting" --filter "status=created" --filter "status=dead" --format "{{.Names}}" 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Error getting container list after Docker restart: $output" | tee -a /var/log/monitor_myst.log
      return 1
    fi
  fi

  # 從容器名稱中提取數字列表
  local numbers=()
  for c in $output; do
    num=$(echo "$c" | grep -oE '[0-9]+$')
    if [ -n "$num" ] && ! [[ " ${numbers[*]} " =~ " $num " ]]; then
      numbers+=("$num")
    fi
  done
  echo "Found containers with numbers: ${numbers[*]}" | tee -a /var/log/monitor_myst.log

  # 移除所有 myst 和 vpni 容器並清理元數據
  for num in "${numbers[@]}"; do
    # 檢查 myst 容器是否存在
    if docker ps -a --filter "name=^myst$num$" --format "{{.ID}}" | grep -q .; then
      output=$(timeout 300 docker rm -f "myst$num" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] && ! echo "$output" | grep -qi "No such container"; then
        echo "Failed to remove myst$num: $output" | tee -a /var/log/monitor_myst.log
        # 僅在非 "No such container" 錯誤時重啟 Docker
        echo "Restarting Docker service due to removal failure..." | tee -a /var/log/monitor_myst.log
        output=$(timeout 600 sudo systemctl restart docker 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ]; then
          echo "Failed to restart Docker service or timed out: $output" | tee -a /var/log/monitor_myst.log
          echo "Systemctl restart docker timed out, initiating reboot..." | tee -a /var/log/monitor_myst.log
          sudo reboot
          return 1
        fi
        sleep 10
        if ! check_docker_service; then
          echo "Docker service failed to restart, initiating reboot..." | tee -a /var/log/monitor_myst.log
          sudo reboot
          return 1
        fi
        # 重試移除
        if docker ps -a --filter "name=^myst$num$" --format "{{.ID}}" | grep -q .; then
          output=$(timeout 300 docker rm -f "myst$num" 2>&1)
          exit_code=$?
          if [ $exit_code -ne 0 ] && ! echo "$output" | grep -qi "No such container"; then
            echo "Failed to remove myst$num after Docker restart: $output" | tee -a /var/log/monitor_myst.log
            continue
          fi
        fi
      fi
    else
      echo "Container myst$num does not exist, skipping removal" | tee -a /var/log/monitor_myst.log
    fi
    # 檢查 vpni 容器是否存在
    if docker ps -a --filter "name=^vpni$num$" --format "{{.ID}}" | grep -q .; then
      output=$(timeout 300 docker rm -f "vpni$num" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] && ! echo "$output" | grep -qi "No such container"; then
        echo "Failed to remove vpni$num: $output" | tee -a /var/log/monitor_myst.log
        echo "Restarting Docker service due to removal failure..." | tee -a /var/log/monitor_myst.log
        output=$(timeout 600 sudo systemctl restart docker 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ]; then
          echo "Failed to restart Docker service or timed out: $output" | tee -a /var/log/monitor_myst.log
          echo "Systemctl restart docker timed out, initiating reboot..." | tee -a /var/log/monitor_myst.log
          sudo reboot
          return 1
        fi
        sleep 10
        if ! check_docker_service; then
          echo "Docker service failed to restart, initiating reboot..." | tee -a /var/log/monitor_myst.log
          sudo reboot
          return 1
        fi
        # 重試移除
        if docker ps -a --filter "name=^vpni$num$" --format "{{.ID}}" | grep -q .; then
          output=$(timeout 300 docker rm -f "vpni$num" 2>&1)
          exit_code=$?
          if [ $exit_code -ne 0 ] && ! echo "$output" | grep -qi "No such container"; then
            echo "Failed to remove vpni$num after Docker restart: $output" | tee -a /var/log/monitor_myst.log
            continue
          fi
        fi
      fi
    else
      echo "Container vpni$num does not exist, skipping removal" | tee -a /var/log/monitor_myst.log
    fi
    # 清理元數據和重建網絡
    clean_container_metadata "myst$num"
    docker_network_recreate "$num"
  done

  # 再次檢查是否有處於 exited 或 restarting 狀態的容器
  output=$(timeout 300 docker ps -a --filter "name=myst|vpni" --filter "status=exited" --filter "status=restarting" --filter "status=created" --filter "status=dead" --format "{{.Names}}" 2>&1)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Error getting container list for second check: $output" | tee -a /var/log/monitor_myst.log
    return 1
  fi
  local residual_numbers=()
  for c in $output; do
    num=$(echo "$c" | grep -oE '[0-9]+$')
    if [ -n "$num" ] && ! [[ " ${residual_numbers[*]} " =~ " $num " ]]; then
      residual_numbers+=("$num")
    fi
  done
  if [ ${#residual_numbers[@]} -gt 0 ]; then
    echo "Found residual containers in exited or restarting state: ${residual_numbers[*]}" | tee -a /var/log/monitor_myst.log
    for num in "${residual_numbers[@]}"; do
      output=$(timeout 300 docker rm -f "myst$num" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to remove residual myst$num: $output" | tee -a /var/log/monitor_myst.log
        continue
      fi
      output=$(timeout 300 docker rm -f "vpni$num" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to remove residual vpni$num: $output" | tee -a /var/log/monitor_myst.log
        continue
      fi
      clean_container_metadata "myst$num"
      docker_network_recreate "$num"
    done
  fi

  # 獲取所有 /root/ovpn 中的 container_number
  local all_numbers
  all_numbers=($(ls /root/ovpn/ip*.ovpn 2>/dev/null | grep -oE '[0-9]+' | sort -n))
  local ovpn_count=${#all_numbers[@]}
  echo "Found $ovpn_count OVPN files: ${all_numbers[*]}" | tee -a /var/log/monitor_myst.log

  # 獲取最小 container_number
  local min_container_number=${all_numbers[0]}
  [ -z "$min_container_number" ] && {
    echo "No OVPN files found, exiting handle_docker_restart" | tee -a /var/log/monitor_myst.log
    return 1
  }

  # 獲取當前存在的容器數字
  local existing_vpni_numbers=()
  output=$(timeout 300 docker ps -a --filter "name=vpni" --format "{{.Names}}" 2>/dev/null)
  for c in $output; do
    num=$(echo "$c" | grep -oE '[0-9]+$')
    if [ -n "$num" ] && ! [[ " ${existing_vpni_numbers[*]} " =~ " $num " ]]; then
      existing_vpni_numbers+=("$num")
    fi
  done
  echo "Existing myst containers: ${existing_vpni_numbers[*]}" | tee -a /var/log/monitor_myst.log

  # 計算缺失的數字（在 all_numbers 中但不在 existing_numbers 中）
  local missing_vpni_numbers=()
  for num in "${all_numbers[@]}"; do
    if ! [[ " ${existing_vpni_numbers[*]} " =~ " $num " ]]; then
      missing_vpni_numbers+=("$num")
    fi
  done
  echo "Missing vpni container numbers: ${missing_vpni_numbers[*]}" | tee -a /var/log/monitor_myst.log

  # 獲取當前存在的容器數字
  local existing_myst_numbers=()
  output=$(timeout 300 docker ps -a --filter "name=myst" --format "{{.Names}}" 2>/dev/null)
  for c in $output; do
    num=$(echo "$c" | grep -oE '[0-9]+$')
    if [ -n "$num" ] && ! [[ " ${existing_myst_numbers[*]} " =~ " $num " ]]; then
      existing_myst_numbers+=("$num")
    fi
  done
  echo "Existing myst containers: ${existing_myst_numbers[*]}" | tee -a /var/log/monitor_myst.log

  # 計算缺失的數字（在 all_numbers 中但不在 existing_numbers 中）
  local missing_myst_numbers=()
  for num in "${all_numbers[@]}"; do
    if ! [[ " ${existing_myst_numbers[*]} " =~ " $num " ]]; then
      missing_myst_numbers+=("$num")
    fi
  done
  echo "Missing myst container numbers: ${missing_myst_numbers[*]}" | tee -a /var/log/monitor_myst.log

  # 為缺失的容器創建 vpni 和 myst
  # vpni
  for num in "${missing_vpni_numbers[@]}"; do
    local myst_port=$((40001 + num - min_container_number))
    local ovpn_file_path="/root/ovpn/ip${num}.ovpn"
    local ovpn_file="ip${num}.ovpn"
    if [ ! -f "$ovpn_file_path" ]; then
      echo "OVPN file $ovpn_file_path not found, skipping container $num" | tee -a /var/log/monitor_myst.log
      continue
    fi

    echo "Starting vpni$num ..." | tee -a /var/log/monitor_myst.log
    output=$(timeout 300 docker run -d --restart always --network vpn${num} --cpu-period=100000 --cpu-quota=10000 \
      --log-driver json-file --log-opt max-size=50m --log-opt max-file=3 -p ${myst_port}:4449 \
      --cap-add=NET_ADMIN --device=/dev/net/tun --memory="64m" \
      -v /root/ovpn:/vpn -e OVPN_FILE=${ovpn_file} --name vpni${num} tsoichinghin/ovpn:latest 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to start vpni${num}: $output" | tee -a /var/log/monitor_myst.log
      if echo "$output" | grep -qi "port is already allocated"; then
        echo "Port conflict detected, rebooting system..." | tee -a /var/log/monitor_myst.log
        reboot
      fi
      continue
    fi
  done

  # myst
  for num in "${missing_myst_numbers[@]}"; do
    local myst_port=$((40001 + num - min_container_number))
    echo "Starting myst$num with myst_port $myst_port..." | tee -a /var/log/monitor_myst.log
    output=$(timeout 300 docker run -d --restart always --network container:vpni${num} --cpu-period=100000 \
      --log-driver json-file --log-opt max-size=50m --log-opt max-file=3 --memory="64m" \
      --cpu-quota=10000 --name myst${num} --cap-add NET_ADMIN \
      -v myst${num}:/var/lib/mysterium-node tsoichinghin/myst:latest \
      --ui.address=0.0.0.0 --tequilapi.address=0.0.0.0 --data-dir=/var/lib/mysterium-node \
      service --agreed-terms-and-conditions 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to start myst${num}: $output" | tee -a /var/log/monitor_myst.log
      if echo "$output" | grep -qi "cannot join network of a non running container"; then
        echo "Non-running container network error detected, rebooting system..." | tee -a /var/log/monitor_myst.log
        reboot
      fi
    fi
  done
}

# 函數：檢查容器狀態
check_container_status() {
  local container=$1
  local cmd=$2
  local output
  output=$(timeout 240 docker $cmd "$container" 2>&1)
  local exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Error executing docker $cmd $container: $output" | tee -a /var/log/monitor_myst.log
    if ! restart_docker_service; then
      echo "Exiting check_container_status due to Docker service failure" | tee -a /var/log/monitor_myst.log
      return 1
    fi
    handle_docker_restart
    return 1
  fi
  return 0
}

# 函數：檢查容器日誌
check_container_logs() {
  local container=$1
  local output
  output=$(timeout 240 docker logs --tail 10 "$container" 2>&1)
  local exit_code=$?
  if [ $exit_code -eq 124 ]; then
    echo "Timeout occurred when getting logs for $container, rebooting system..." | tee -a /var/log/monitor_myst.log
    restart_docker_service
    sleep 60
    handle_docker_restart
    output=$(timeout 240 docker logs --tail 10 "$container" 2>&1)
    exit_code=$?
    if [ $exit_code -eq 124 ]; then
      echo "Second timeout occurred for $container logs, rebooting system now..." | tee -a /var/log/monitor_myst.log
      sudo reboot
      return 1
    fi
  fi
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Failed to get logs for $container: $output" | tee -a /var/log/monitor_myst.log
    if ! check_container_status "$container" "restart"; then
      return 1
    fi
    sleep 60
  else
    # 檢查容器狀態是否為 exited 或 restarting
    local container_status
    container_status=$(docker ps -a --filter "name=$container" --format "{{.Status}}" 2>/dev/null)
    if [[ "$container_status" =~ Exited|Restarting|Dead|Created ]]; then
      echo "Container $container is in $container_status status, triggering handle_docker_restart..." | tee -a /var/log/monitor_myst.log
      handle_docker_restart
      return 1
    fi
  fi
  return 0
}

# 主循環
first_run=true
while true; do
  echo "Checking myst containers at $(date)" | tee -a /var/log/monitor_myst.log
  if [ "$first_run" = true ]; then
    restart_docker_service
    if check_docker_service; then
      echo "Docker service is already running, skipping restart..." | tee -a /var/log/monitor_myst.log
    else
      echo "Docker service not running, attempting to start..." | tee -a /var/log/monitor_myst.log
      if ! restart_docker_service; then
        echo "Failed to start Docker service, retrying in next loop" | tee -a /var/log/monitor_myst.log
        sleep 10
        continue
      fi
    fi
    handle_docker_restart
    echo "Waiting for 60 seconds before first run..." | tee -a /var/log/monitor_myst.log
    sleep 60
    echo "First run completed, proceeding with monitoring..." | tee -a /var/log/monitor_myst.log
    first_run=false
  fi
  handle_docker_restart
  output=$(timeout 240 docker ps --filter "name=myst" --format "{{.Names}}" 2>&1)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Error getting running myst containers: $output" | tee -a /var/log/monitor_myst.log
    if ! restart_docker_service; then
      echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
      sleep 10
      continue
    fi
    handle_docker_restart
    continue
  fi
  containers=$output
  if [ -z "$containers" ]; then
    echo "No running myst containers found. Checking stopped containers..." | tee -a /var/log/monitor_myst.log
    output=$(timeout 240 docker ps -a --filter "name=myst" --filter "status=exited" --filter "status=restarting" --filter "status=created" --filter "status=dead" --format "{{.Names}}" 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Error getting stopped myst containers: $output" | tee -a /var/log/monitor_myst.log
      if ! restart_docker_service; then
        echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
        sleep 10
        continue
      fi
      handle_docker_restart
      continue
    fi
    stopped_containers=$output
    for container in $stopped_containers; do
      echo "Starting stopped container: $container" | tee -a /var/log/monitor_myst.log
      if ! check_container_status "$container" "start"; then
        continue
      fi
    done
    sleep 10
    output=$(timeout 240 docker ps --filter "name=myst" --format "{{.Names}}" 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Error getting running myst containers after starting: $output" | tee -a /var/log/monitor_myst.log
      if ! restart_docker_service; then
        echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
        sleep 10
        continue
      fi
      handle_docker_restart
      continue
    fi
    containers=$output
    if [ -z "$containers" ]; then
      echo "No myst containers available after starting." | tee -a /var/log/monitor_myst.log
      handle_docker_restart
      continue
    fi
  fi
  for container in $containers; do
    echo "Processing container: $container" | tee -a /var/log/monitor_myst.log
    if ! check_container_logs "$container"; then
      continue
    fi
    output=$(timeout 240 docker exec "$container" curl -s http://localhost:4050/identities -o /tmp/identities.json 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to get identities for $container: $output" | tee -a /var/log/monitor_myst.log
      if ! restart_myst $container; then
        echo "Failed to restart myst container $container, checking Docker service..." | tee -a /var/log/monitor_myst.log
        if ! restart_docker_service; then
          echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
          sleep 10
          continue
        fi
        handle_docker_restart
        continue
      fi
      echo "Container $container restarted successfully, waiting 60 second and checking identities again..." | tee -a /var/log/monitor_myst.log
      sleep 60
      output=$(timeout 240 docker exec "$container" curl -s http://localhost:4050/identities -o /tmp/identities.json 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to get identities for $container after restart: $output" | tee -a /var/log/monitor_myst.log
        if ! restart_docker_service; then
          echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
          sleep 10
          continue
        fi
        handle_docker_restart
        continue
      fi
      echo "Identities fetched successfully for $container after restart" | tee -a /var/log/monitor_myst.log
    fi
    output=$(timeout 240 docker exec "$container" jq -r '.identities[0].id' /tmp/identities.json 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to parse provider_id for $container: $output" | tee -a /var/log/monitor_myst.log
      if ! restart_docker_service; then
        echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
        sleep 10
        continue
      fi
      handle_docker_restart
      continue
    fi
    provider_id=$(echo "$output" | tr -d '\r')
    if [ -z "$provider_id" ] || [ "$provider_id" = "null" ]; then
      echo "Failed to get provider_id for $container, raw output:" | tee -a /var/log/monitor_myst.log
      output=$(timeout 240 docker exec "$container" cat /tmp/identities.json 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to cat identities.json for $container: $output" | tee -a /var/log/monitor_myst.log
        if ! restart_docker_service; then
          echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
          sleep 10
          continue
        fi
        handle_docker_restart
        continue
      else
        echo "$output" | tee -a /var/log/monitor_myst.log
      fi
      echo "Trying CLI..." | tee -a /var/log/monitor_myst.log
      output=$(timeout 600 docker exec "$container" myst cli identities list 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to run myst cli identities list for $container: $output" | tee -a /var/log/monitor_myst.log
        if ! restart_docker_service; then
          echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
          sleep 10
          continue
        fi
        handle_docker_restart
        continue
      else
        echo "$output" | tee -a /var/log/monitor_myst.log
      fi
      echo "Container status:" | tee -a /var/log/monitor_myst.log
      output=$(timeout 240 docker ps -a --filter "name=$container" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to get container status for $container: $output" | tee -a /var/log/monitor_myst.log
        if ! restart_docker_service; then
          echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
          sleep 10
          continue
        fi
        handle_docker_restart
        continue
      else
        echo "$output" | tee -a /var/log/monitor_myst.log
      fi
      continue
    fi
    echo "Provider ID for $container: $provider_id" | tee -a /var/log/monitor_myst.log
    missing_services=""
    scraping_count=0
    quic_scraping_count=0
    output=$(timeout 240 docker exec "$container" curl -s http://localhost:4050/services -o /tmp/services.json 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to get services for $container: $output" | tee -a /var/log/monitor_myst.log
      if ! restart_docker_service; then
        echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
        sleep 10
        continue
      fi
      handle_docker_restart
      continue
    fi
    output=$(timeout 240 docker exec "$container" jq -r '.[].type' /tmp/services.json 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to parse services for $container: $output" | tee -a /var/log/monitor_myst.log
      if ! restart_docker_service; then
        echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
        sleep 10
        continue
      fi
      handle_docker_restart
      continue
    fi
    service_list=$output
    scraping_count=$(echo "$service_list" | grep -ci "^scraping$")
    quic_scraping_count=$(echo "$service_list" | grep -ci "^quic_scraping$")
    if [ "$scraping_count" -ne 1 ] || [ "$quic_scraping_count" -ne 1 ]; then
      while IFS= read -r line; do
        if echo "$line" | grep -qi "^scraping$\|^quic_scraping$"; then
          output=$(timeout 240 docker exec "$container" jq -r ".[] | select(.type == \"$line\") | .id" /tmp/services.json 2>&1)
          exit_code=$?
          if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
            echo "Failed to parse service ID for $line in $container: $output" | tee -a /var/log/monitor_myst.log
            if ! restart_docker_service; then
              echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
              sleep 10
              continue
            fi
            handle_docker_restart
            continue 2
          fi
          service_id=$output
          if [ -n "$service_id" ]; then
            echo "Stopping service ID $service_id in $container ($line)" | tee -a /var/log/monitor_myst.log
            output=$(timeout 240 docker exec "$container" curl -s -X DELETE http://localhost:4050/services/$service_id 2>&1)
            exit_code=$?
            if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
              echo "Failed to stop service $service_id in $container: $output" | tee -a /var/log/monitor_myst.log
              if ! restart_docker_service; then
                echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
                sleep 10
                continue
              fi
              handle_docker_restart
              continue 2
            fi
            sleep 2
          fi
        fi
      done <<< "$service_list"
      if [ "$scraping_count" -ne 1 ]; then
        echo "Starting service scraping in $container..." | tee -a /var/log/monitor_myst.log
        output=$(timeout 240 docker exec "$container" curl -X POST http://localhost:4050/services -H "Content-Type: application/json" -d "{\"provider_id\": \"$provider_id\", \"type\": \"scraping\"}" -o /tmp/response_start_scraping.json 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to start scraping in $container with curl: $output" | tee -a /var/log/monitor_myst.log
          echo "Trying CLI..." | tee -a /var/log/monitor_myst.log
          output=$(timeout 600 docker exec "$container" myst cli service start "$provider_id" scraping 2>&1)
          exit_code=$?
          if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
            echo "Failed to start scraping with CLI in $container: $output" | tee -a /var/log/monitor_myst.log
            if ! restart_docker_service; then
              echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
              sleep 10
              continue
            fi
            handle_docker_restart
            continue
          fi
        fi
        sleep 2
      fi
      if [ "$quic_scraping_count" -ne 1 ]; then
        echo "Starting service quic_scraping in $container..." | tee -a /var/log/monitor_myst.log
        output=$(timeout 240 docker exec "$container" curl -X POST http://localhost:4050/services -H "Content-Type: application/json" -d "{\"provider_id\": \"$provider_id\", \"type\": \"quic_scraping\"}" -o /tmp/response_start_quic_scraping.json 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to start quic_scraping in $container with curl: $output" | tee -a /var/log/monitor_myst.log
          echo "Trying CLI..." | tee -a /var/log/monitor_myst.log
          output=$(timeout 600 docker exec "$container" myst cli service start "$provider_id" quic_scraping 2>&1)
          exit_code=$?
          if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
            echo "Failed to start quic_scraping with CLI in $container: $output" | tee -a /var/log/monitor_myst.log
            if ! restart_docker_service; then
              echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
              sleep 10
              continue
            fi
            handle_docker_restart
            continue
          fi
        fi
        sleep 2
      fi
    fi
    for service in $SERVICES; do
      if [ "$service" != "scraping" ] && [ "$service" != "quic_scraping" ]; then
        if ! echo "$service_list" | grep -qi "^$service$"; then
          missing_services="$missing_services $service"
        fi
      fi
    done
    for service in $missing_services; do
      if [ "$service" != "scraping" ] && [ "$service" != "quic_scraping" ]; then
        echo "Starting service $service in $container..." | tee -a /var/log/monitor_myst.log
        output=$(timeout 240 docker exec "$container" curl -X POST http://localhost:4050/services -H "Content-Type: application/json" -d "{\"provider_id\": \"$provider_id\", \"type\": \"$service\"}" -o /tmp/response_start_${service}.json 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to start $service in $container with curl: $output" | tee -a /var/log/monitor_myst.log
          echo "Trying CLI..." | tee -a /var/log/monitor_myst.log
          output=$(timeout 600 docker exec "$container" myst cli service start "$provider_id" "$service" 2>&1)
          exit_code=$?
          if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
            echo "Failed to start $service with CLI in $container: $output" | tee -a /var/log/monitor_myst.log
            if ! restart_docker_service; then
              echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
              sleep 10
              continue
            fi
            handle_docker_restart
            continue
          fi
        fi
        sleep 2
      fi
    done
    echo "Service check and restart completed for $container" | tee -a /var/log/monitor_myst.log
    output=$(timeout 240 docker exec "$container" rm -f /tmp/identities.json /tmp/services.json /tmp/response_start_*.json 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to clean up files for $container: $output" | tee -a /var/log/monitor_myst.log
      if ! restart_docker_service; then
        echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
        sleep 10
        continue
      fi
      handle_docker_restart
      continue
    fi
  done
  current_time=$(date +%s)
  if [ -f /root/next_payout_date.txt ]; then
    next_payout_date=$(cat /root/next_payout_date.txt)
  else
    next_payout_date=$((current_time + 30*24*60*60))
    echo "$next_payout_date" > /root/next_payout_date.txt
  fi
  if [ "$current_time" -ge "$next_payout_date" ]; then
    echo "Payout time reached, processing withdrawals for all containers..." | tee -a /var/log/monitor_myst.log
    for container in $containers; do
      echo "Processing withdrawal for container: $container" | tee -a /var/log/monitor_myst.log
      output=$(timeout 240 docker exec "$container" curl -s http://localhost:4050/identities -o /tmp/identities.json 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to get identities for $container: $output" | tee -a /var/log/monitor_myst.log
        if ! restart_myst $container; then
          echo "Failed to restart myst container $container, checking Docker service..." | tee -a /var/log/monitor_myst.log
          if ! restart_docker_service; then
            echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
            sleep 10
            continue
          fi
          handle_docker_restart
          continue
        fi
        echo "Container $container restarted successfully, waiting 60 second and checking identities again..." | tee -a /var/log/monitor_myst.log
        sleep 60
        output=$(timeout 240 docker exec "$container" curl -s http://localhost:4050/identities -o /tmp/identities.json 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to get identities for $container after restart: $output" | tee -a /var/log/monitor_myst.log
          if ! restart_docker_service; then
            echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
            sleep 10
            continue
          fi
          handle_docker_restart
          continue
        fi
        echo "Identities fetched successfully for $container after restart" | tee -a /var/log/monitor_myst.log
      fi
      output=$(timeout 240 docker exec "$container" jq -r '.identities[0].id' /tmp/identities.json 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to parse provider_id for $container: $output" | tee -a /var/log/monitor_myst.log
        if ! restart_docker_service; then
          echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
          sleep 10
          continue
        fi
        handle_docker_restart
        continue
      fi
      provider_id=$(echo "$output" | tr -d '\r')
      if [ -z "$provider_id" ] || [ "$provider_id" = "null" ]; then
        echo "Failed to get provider_id for $container, raw output:" | tee -a /var/log/monitor_myst.log
        output=$(timeout 240 docker exec "$container" cat /tmp/identities.json 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to cat identities.json for $container: $output" | tee -a /var/log/monitor_myst.log
          if ! restart_docker_service; then
            echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
            sleep 10
            continue
          fi
          handle_docker_restart
          continue
        else
          echo "$output" | tee -a /var/log/monitor_myst.log
        fi
        echo "Trying CLI..." | tee -a /var/log/monitor_myst.log
        output=$(timeout 600 docker exec "$container" myst cli identities list 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to run myst cli identities list for $container: $output" | tee -a /var/log/monitor_myst.log
          if ! restart_docker_service; then
            echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
            sleep 10
            continue
          fi
          handle_docker_restart
          continue
        else
          echo "$output" | tee -a /var/log/monitor_myst.log
        fi
        echo "Container status:" | tee -a /var/log/monitor_myst.log
        output=$(timeout 240 docker ps -a --filter "name=$container" 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to get container status for $container: $output" | tee -a /var/log/monitor_myst.log
          if ! restart_docker_service; then
            echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
            sleep 10
            continue
          fi
          handle_docker_restart
          continue
        else
          echo "$output" | tee -a /var/log/monitor_myst.log
        fi
        continue
      fi
      echo "Provider ID for withdrawal: $provider_id" | tee -a /var/log/monitor_myst.log
      output=$(timeout 600 docker exec "$container" myst cli identities settle "$provider_id" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Withdrawal failed for $container: $output" | tee -a /var/log/monitor_myst.log
        if ! restart_docker_service; then
          echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
          sleep 10
          continue
        fi
        handle_docker_restart
        continue
      else
        echo "Withdrawal attempted for $container: $output" | tee -a /var/log/monitor_myst.log
      fi
      output=$(timeout 240 docker exec "$container" rm -f /tmp/identities.json 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to clean up identities.json for $container: $output" | tee -a /var/log/monitor_myst.log
        if ! restart_docker_service; then
          echo "Exiting loop due to Docker service failure" | tee -a /var/log/monitor_myst.log
          sleep 10
          continue
        fi
        handle_docker_restart
        continue
      fi
    done
    current_time=$(date +%s)
    next_payout_date=$((current_time + 30*24*60*60))
    echo "$next_payout_date" > /root/next_payout_date.txt
    echo "Next payout date updated: $(date -d @$next_payout_date)" | tee -a /var/log/monitor_myst.log
  fi
  echo "Sleeping for 6 hours..." | tee -a /var/log/monitor_myst.log
  sleep 21600
done
