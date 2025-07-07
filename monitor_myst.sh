#!/bin/bash

SERVICES="dvpn scraping quic_scraping wireguard data_transfer"
current_time=$(date +%s)
next_payout_date=$((current_time + 30*24*60*60))
echo "Initial next payout date: $(date -d @$next_payout_date)" | tee -a /var/log/monitor_myst.log

# 函數：處理 Docker 重啟後的容器
handle_docker_restart() {
  echo "Handling Docker restart at $(date)" | tee -a /var/log/monitor_myst.log

  # 移除 Exited 或 Restarting 容器
  local output
  output=$(timeout 300 docker ps -a --filter "status=exited" --filter "status=restarting" --filter "name=myst|vpni" --format "{{.Names}}" 2>&1)
  local exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Error getting container list: $output" | tee -a /var/log/monitor_myst.log
    echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
    sudo systemctl restart docker
    echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
    sleep 60
    return 1
  fi
  for c in $output; do
    echo "Removing $c (status: Exited or Restarting)..." | tee -a /var/log/monitor_myst.log
    output=$(timeout 300 docker rm -f "$c" 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to remove $c, killing process..." | tee -a /var/log/monitor_myst.log
      local CONTAINER_PID
      CONTAINER_PID=$(timeout 300 docker inspect "$c" 2>&1 | jq -r .[0].State.Pid 2>/dev/null)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$CONTAINER_PID" | grep -qi "Error response from daemon"; then
        echo "Failed to inspect $c: $CONTAINER_PID" | tee -a /var/log/monitor_myst.log
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
        return 1
      fi
      [ -n "$CONTAINER_PID" ] && [ "$CONTAINER_PID" != "0" ] && sudo kill -9 "$CONTAINER_PID"
      output=$(timeout 300 docker rm -f "$c" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to remove $c after kill: $output" | tee -a /var/log/monitor_myst.log
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
        return 1
      fi
    fi
  done

  # 獲取所有 /root/ovpn 中的 container_number
  all_numbers=($(ls /root/ovpn/ip*.ovpn 2>/dev/null | grep -oE '[0-9]+' | sort -n))
  ovpn_count=${#all_numbers[@]}
  echo "Found $ovpn_count OVPN files: ${all_numbers[*]}" | tee -a /var/log/monitor_myst.log

  # 獲取最小 container_number
  min_container_number=${all_numbers[0]}
  [ -z "$min_container_number" ] && {
    echo "No OVPN files found, exiting handle_docker_restart" | tee -a /var/log/monitor_myst.log
    return 1
  }

  # 獲取現有 myst 和 vpni 容器
  local myst_numbers vpni_numbers
  output=$(timeout 300 docker ps -a --filter "name=myst" --format "{{.Names}}" 2>&1 | grep -oE '[0-9]+$' | sort -n)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Error getting myst containers: $output" | tee -a /var/log/monitor_myst.log
    echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
    sudo systemctl restart docker
    echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
    sleep 60
    return 1
  fi
  myst_numbers=($output)
  output=$(timeout 300 docker ps -a --filter "name=vpni" --format "{{.Names}}" 2>&1 | grep -oE '[0-9]+$' | sort -n)
  exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Error getting vpni containers: $output" | tee -a /var/log/monitor_myst.log
    echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
    sudo systemctl restart docker
    echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
    sleep 60
    return 1
  fi
  vpni_numbers=($output)
  echo "Existing myst containers: ${myst_numbers[*]}" | tee -a /var/log/monitor_myst.log
  echo "Existing vpni containers: ${vpni_numbers[*]}" | tee -a /var/log/monitor_myst.log

  # 找出缺失的 container_number（若 myst 或 vpni 任一缺失）
  missing_numbers=()
  for num in "${all_numbers[@]}"; do
    if ! echo "${myst_numbers[@]}" | grep -qw "$num" || ! echo "${vpni_numbers[@]}" | grep -qw "$num"; then
      missing_numbers+=("$num")
    fi
  done
  echo "Missing container numbers: ${missing_numbers[*]}" | tee -a /var/log/monitor_myst.log

  # 為缺失的 container_number 分配 myst_port 並重新啟動
  for num in "${missing_numbers[@]}"; do
    myst_port=$((40001 + num - min_container_number))
    ovpn_file="/root/ovpn/ip${num}.ovpn"
    if [ ! -f "$ovpn_file" ]; then
      echo "OVPN file $ovpn_file not found, skipping container $num" | tee -a /var/log/monitor_myst.log
      continue
    fi

    # 如果 myst{num} 或 vpni{num} 存在，先移除
    if echo "${myst_numbers[@]}" | grep -qw "$num"; then
      echo "Removing existing myst$num..." | tee -a /var/log/monitor_myst.log
      output=$(timeout 300 docker rm -f "myst$num" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to remove myst$num: $output" | tee -a /var/log/monitor_myst.log
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
        return 1
      fi
    fi
    if echo "${vpni_numbers[@]}" | grep -qw "$num"; then
      echo "Removing existing vpni$num..." | tee -a /var/log/monitor_myst.log
      output=$(timeout 300 docker rm -f "vpni$num" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to remove vpni$num: $output" | tee -a /var/log/monitor_myst.log
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
        return 1
      fi
    fi

    echo "Restarting vpni$num and myst$num with myst_port $myst_port..." | tee -a /var/log/monitor_myst.log
    output=$(timeout 300 docker run -d --restart always --network vpn${num} --cpu-period=100000 --cpu-quota=10000 \
      --log-driver json-file --log-opt max-size=10m -p ${myst_port}:4449 \
      --cap-add=NET_ADMIN --device=/dev/net/tun --memory="32m" \
      -v /root/ovpn:/vpn -e OVPN_FILE="${ovpn_file}" --name vpni${num} tsoichinghin/ovpn:latest 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to start vpni${num}: $output" | tee -a /var/log/monitor_myst.log
      continue
    fi
    output=$(timeout 300 docker run -d --restart always --network container:vpni${num} --cpu-period=100000 \
      --log-driver json-file --log-opt max-size=10m --memory="32m" \
      --cpu-quota=10000 --name myst${num} --cap-add NET_ADMIN \
      -v myst${num}:/var/lib/mysterium-node tsoichinghin/myst:latest \
      --ui.address=0.0.0.0 --tequilapi.address=0.0.0.0 service --agreed-terms-and-conditions 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to start myst${num}: $output" | tee -a /var/log/monitor_myst.log
    fi
  done
}

# 函數：檢查容器狀態
check_container_status() {
  local container=$1
  local cmd=$2
  local output
  output=$(timeout 180 docker $cmd "$container" 2>&1)
  local exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Error executing docker $cmd $container: $output" | tee -a /var/log/monitor_myst.log
    echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
    sudo systemctl restart docker
    echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
    sleep 60
    handle_docker_restart
    return 1
  fi
  return 0
}

# 函數：日誌檢查
check_container_logs() {
  local container=$1
  local output
  output=$(timeout 180 docker logs --tail 10 "$container" 2>&1)
  local exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Failed to get logs for $container: $output" | tee -a /var/log/monitor_myst.log
    if ! check_container_status "$container" "restart"; then
      return 1
    fi
    sleep 60
  elif echo "$output" | grep -qi "timeout"; then
    echo "Timeout detected in $container, restarting..." | tee -a /var/log/monitor_myst.log
    if ! check_container_status "$container" "restart"; then
      return 1
    fi
    sleep 60
  fi
  return 0
}

while true; do
  echo "Checking myst containers at $(date)" | tee -a /var/log/monitor_myst.log
  local output
  output=$(timeout 180 docker ps --filter "name=myst" --format "{{.Names}}" 2>&1)
  local exit_code=$?
  if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
    echo "Error getting running myst containers: $output" | tee -a /var/log/monitor_myst.log
    echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
    sudo systemctl restart docker
    echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
    sleep 60
    handle_docker_restart
    continue
  fi
  containers=$output
  if [ -z "$containers" ]; then
    echo "No running myst containers found. Checking stopped containers..." | tee -a /var/log/monitor_myst.log
    output=$(timeout 180 docker ps -a --filter "name=myst" --filter "status=exited" --format "{{.Names}}" 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Error getting stopped myst containers: $output" | tee -a /var/log/monitor_myst.log
      echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
      sudo systemctl restart docker
      echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
      sleep 60
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
    output=$(timeout 180 docker ps --filter "name=myst" --format "{{.Names}}" 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Error getting running myst containers after starting: $output" | tee -a /var/log/monitor_myst.log
      echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
      sudo systemctl restart docker
      echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
      sleep 60
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
    output=$(timeout 180 docker exec "$container" curl -s http://localhost:4050/identities -o /tmp/identities.json 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to get identities for $container: $output" | tee -a /var/log/monitor_myst.log
      echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
      sudo systemctl restart docker
      echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
      sleep 60
      handle_docker_restart
      continue
    fi
    output=$(timeout 180 docker exec "$container" jq -r '.identities[0].id' /tmp/identities.json 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to parse provider_id for $container: $output" | tee -a /var/log/monitor_myst.log
      echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
      sudo systemctl restart docker
      echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
      sleep 60
      handle_docker_restart
      continue
    fi
    provider_id=$(echo "$output" | tr -d '\r')
    if [ -z "$provider_id" ] || [ "$provider_id" = "null" ]; then
      echo "Failed to get provider_id for $container, raw output:" | tee -a /var/log/monitor_myst.log
      output=$(timeout 180 docker exec "$container" cat /tmp/identities.json 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to cat identities.json for $container: $output" | tee -a /var/log/monitor_myst.log
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
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
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
        handle_docker_restart
        continue
      else
        echo "$output" | tee -a /var/log/monitor_myst.log
      fi
      echo "Container status:" | tee -a /var/log/monitor_myst.log
      output=$(timeout 180 docker ps -a --filter "name=$container" 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to get container status for $container: $output" | tee -a /var/log/monitor_myst.log
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
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
    output=$(timeout 180 docker exec "$container" curl -s http://localhost:4050/services -o /tmp/services.json 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to get services for $container: $output" | tee -a /var/log/monitor_myst.log
      echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
      sudo systemctl restart docker
      echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
      sleep 60
      handle_docker_restart
      continue
    fi
    output=$(timeout 180 docker exec "$container" jq -r '.[].type' /tmp/services.json 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to parse services for $container: $output" | tee -a /var/log/monitor_myst.log
      echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
      sudo systemctl restart docker
      echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
      sleep 60
      handle_docker_restart
      continue
    fi
    service_list=$output
    scraping_count=$(echo "$service_list" | grep -ci "^scraping$")
    quic_scraping_count=$(echo "$service_list" | grep -ci "^quic_scraping$")
    if [ "$scraping_count" -ne 1 ] || [ "$quic_scraping_count" -ne 1 ]; then
      while IFS= read -r line; do
        if echo "$line" | grep -qi "^scraping$\|^quic_scraping$"; then
          output=$(timeout 180 docker exec "$container" jq -r ".[] | select(.type == \"$line\") | .id" /tmp/services.json 2>&1)
          exit_code=$?
          if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
            echo "Failed to parse service ID for $line in $container: $output" | tee -a /var/log/monitor_myst.log
            echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
            sudo systemctl restart docker
            echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
            sleep 60
            handle_docker_restart
            continue 2
          fi
          service_id=$output
          if [ -n "$service_id" ]; then
            echo "Stopping service ID $service_id in $container ($line)" | tee -a /var/log/monitor_myst.log
            output=$(timeout 180 docker exec "$container" curl -s -X DELETE http://localhost:4050/services/$service_id 2>&1)
            exit_code=$?
            if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
              echo "Failed to stop service $service_id in $container: $output" | tee -a /var/log/monitor_myst.log
              echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
              sudo systemctl restart docker
              echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
              sleep 60
              handle_docker_restart
              continue 2
            fi
            sleep 2
          fi
        fi
      done <<< "$service_list"
      if [ "$scraping_count" -ne 1 ]; then
        echo "Starting service scraping in $container..." | tee -a /var/log/monitor_myst.log
        output=$(timeout 180 docker exec "$container" curl -X POST http://localhost:4050/services -H "Content-Type: application/json" -d "{\"provider_id\": \"$provider_id\", \"type\": \"scraping\"}" -o /tmp/response_start_scraping.json 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to start scraping in $container with curl: $output" | tee -a /var/log/monitor_myst.log
          echo "Trying CLI..." | tee -a /var/log/monitor_myst.log
          output=$(timeout 600 docker exec "$container" myst cli service start "$provider_id" scraping 2>&1)
          exit_code=$?
          if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
            echo "Failed to start scraping with CLI in $container: $output" | tee -a /var/log/monitor_myst.log
            echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
            sudo systemctl restart docker
            echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
            sleep 60
            handle_docker_restart
            continue
          fi
        fi
        sleep 2
      fi
      if [ "$quic_scraping_count" -ne 1 ]; then
        echo "Starting service quic_scraping in $container..." | tee -a /var/log/monitor_myst.log
        output=$(timeout 180 docker exec "$container" curl -X POST http://localhost:4050/services -H "Content-Type: application/json" -d "{\"provider_id\": \"$provider_id\", \"type\": \"quic_scraping\"}" -o /tmp/response_start_quic_scraping.json 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to start quic_scraping in $container with curl: $output" | tee -a /var/log/monitor_myst.log
          echo "Trying CLI..." | tee -a /var/log/monitor_myst.log
          output=$(timeout 600 docker exec "$container" myst cli service start "$provider_id" quic_scraping 2>&1)
          exit_code=$?
          if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
            echo "Failed to start quic_scraping with CLI in $container: $output" | tee -a /var/log/monitor_myst.log
            echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
            sudo systemctl restart docker
            echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
            sleep 60
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
        output=$(timeout 180 docker exec "$container" curl -X POST http://localhost:4050/services -H "Content-Type: application/json" -d "{\"provider_id\": \"$provider_id\", \"type\": \"$service\"}" -o /tmp/response_start_${service}.json 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to start $service in $container with curl: $output" | tee -a /var/log/monitor_myst.log
          echo "Trying CLI..." | tee -a /var/log/monitor_myst.log
          output=$(timeout 600 docker exec "$container" myst cli service start "$provider_id" "$service" 2>&1)
          exit_code=$?
          if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
            echo "Failed to start $service with CLI in $container: $output" | tee -a /var/log/monitor_myst.log
            echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
            sudo systemctl restart docker
            echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
            sleep 60
            handle_docker_restart
            continue
          fi
        fi
        sleep 2
      fi
    done
    echo "Service check and restart completed for $container" | tee -a /var/log/monitor_myst.log
    output=$(timeout 180 docker exec "$container" rm -f /tmp/identities.json /tmp/services.json /tmp/response_start_*.json 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
      echo "Failed to clean up files for $container: $output" | tee -a /var/log/monitor_myst.log
      echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
      sudo systemctl restart docker
      echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
      sleep 60
      handle_docker_restart
      continue
    fi
  done

  # 提現流程
  current_time=$(date +%s)
  if [ "$current_time" -ge "$next_payout_date" ]; then
    echo "Payout time reached, processing withdrawals for all containers..." | tee -a /var/log/monitor_myst.log
    for container in $containers; do
      echo "Processing withdrawal for container: $container" | tee -a /var/log/monitor_myst.log
      output=$(timeout 180 docker exec "$container" curl -s http://localhost:4050/identities -o /tmp/identities.json 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to get identities for $container: $output" | tee -a /var/log/monitor_myst.log
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
        handle_docker_restart
        continue
      fi
      output=$(timeout 180 docker exec "$container" jq -r '.identities[0].id' /tmp/identities.json 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to parse provider_id for $container: $output" | tee -a /var/log/monitor_myst.log
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
        handle_docker_restart
        continue
      fi
      provider_id=$(echo "$output" | tr -d '\r')
      if [ -z "$provider_id" ] || [ "$provider_id" = "null" ]; then
        echo "Failed to get provider_id for $container, raw output:" | tee -a /var/log/monitor_myst.log
        output=$(timeout 180 docker exec "$container" cat /tmp/identities.json 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to cat identities.json for $container: $output" | tee -a /var/log/monitor_myst.log
          echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
          sudo systemctl restart docker
          echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
          sleep 60
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
          echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
          sudo systemctl restart docker
          echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
          sleep 60
          handle_docker_restart
          continue
        else
          echo "$output" | tee -a /var/log/monitor_myst.log
        fi
        echo "Container status:" | tee -a /var/log/monitor_myst.log
        output=$(timeout 180 docker ps -a --filter "name=$container" 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
          echo "Failed to get container status for $container: $output" | tee -a /var/log/monitor_myst.log
          echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
          sudo systemctl restart docker
          echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
          sleep 60
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
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
        handle_docker_restart
        continue
      else
        echo "Withdrawal attempted for $container: $output" | tee -a /var/log/monitor_myst.log
      fi
      output=$(timeout 180 docker exec "$container" rm -f /tmp/identities.json 2>&1)
      exit_code=$?
      if [ $exit_code -ne 0 ] || echo "$output" | grep -qi "Error response from daemon"; then
        echo "Failed to clean up identities.json for $container: $output" | tee -a /var/log/monitor_myst.log
        echo "Restarting Docker service..." | tee -a /var/log/monitor_myst.log
        sudo systemctl restart docker
        echo "Waiting 60 seconds for Docker to restart..." | tee -a /var/log/monitor_myst.log
        sleep 60
        handle_docker_restart
        continue
      fi
    done
    current_time=$(date +%s)
    next_payout_date=$((current_time + 30*24*60*60))
    echo "Next payout date updated: $(date -d @$next_payout_date)" | tee -a /var/log/monitor_myst.log
  fi

  echo "Sleeping for 3 hours..." | tee -a /var/log/monitor_myst.log
  sleep 10800
done
