#!/bin/bash
SERVICES="dvpn scraping quic_scraping wireguard data_transfer"
current_time=$(date +%s)
next_payout_date=$((current_time + 30*24*60*60))
echo "Initial next payout date: $(date -d @$next_payout_date)"
while true; do
  echo "Checking myst containers at $(date)"
  containers=$(docker ps --filter "name=myst" --format "{{.Names}}")
  if [ -z "$containers" ]; then
    echo "No running myst containers found. Checking stopped containers..."
    stopped_containers=$(docker ps -a --filter "name=myst" --filter "status=exited" --format "{{.Names}}")
    for container in $stopped_containers; do
      echo "Starting stopped container: $container"
      docker start "$container" || echo "Failed to start container $container"
    done
    sleep 10
    containers=$(docker ps --filter "name=myst" --format "{{.Names}}")
    if [ -z "$containers" ]; then
      echo "No myst containers available after starting."
      sleep 10800
      continue
    fi
  fi
  current_time=$(date +%s)
  if [ "$current_time" -ge "$next_payout_date" ]; then
    echo "Payout time reached, processing withdrawals for all containers..."
    for container in $containers; do
      echo "Processing withdrawal for container: $container"
      if docker exec "$container" curl -s http://localhost:4050/identities -o /tmp/identities.json 2>/dev/null; then
        provider_id=$(docker exec "$container" jq -r '.identities[0].id' /tmp/identities.json 2>/dev/null | tr -d '\r')
      fi
      if [ -z "$provider_id" ] || [ "$provider_id" = "null" ]; then
        echo "Failed to get provider_id for $container, raw output:"
        docker exec "$container" cat /tmp/identities.json 2>/dev/null || echo "No API output available"
        echo "Trying CLI..."
        docker exec "$container" myst cli identities list 2>&1
        echo "Container status:"
        docker ps -a --filter "name=$container"
        continue
      fi
      echo "Provider ID for withdrawal: $provider_id"
      docker exec "$container" myst cli identities settle "$provider_id"
      echo "Withdrawal attempted for $container"
      docker exec "$container" rm -f /tmp/identities.json 2>/dev/null
    done
    current_time=$(date +%s)
    next_payout_date=$((current_time + 30*24*60*60))
    echo "Next payout date updated: $(date -d @$next_payout_date)"
  fi
  for container in $containers; do
    echo "Processing container: $container"
    if docker logs --tail 10 "$container" 2>/dev/null | grep -qi "timeout"; then
      echo "Timeout detected in $container, restarting..."
      docker restart "$container" || echo "Failed to restart container $container"
      echo "Waiting 60 seconds for $container to restart..."
      sleep 60
    fi
    if docker exec "$container" curl -s http://localhost:4050/identities -o /tmp/identities.json 2>/dev/null; then
      provider_id=$(docker exec "$container" jq -r '.identities[0].id' /tmp/identities.json 2>/dev/null | tr -d '\r')
    fi
    if [ -z "$provider_id" ] || [ "$provider_id" = "null" ]; then
      echo "Failed to get provider_id for $container, raw output:"
      docker exec "$container" cat /tmp/identities.json 2>/dev/null || echo "No API output available"
      echo "Trying CLI..."
      docker exec "$container" myst cli identities list 2>&1
      echo "Container status:"
      docker ps -a --filter "name=$container"
      continue
    fi
    echo "Provider ID for $container: $provider_id"
    missing_services=""
    scraping_count=0
    quic_scraping_count=0
    if docker exec "$container" curl -s http://localhost:4050/services -o /tmp/services.json 2>/dev/null; then
      service_list=$(docker exec "$container" jq -r '.[].type' /tmp/services.json 2>/dev/null | tr -d '\r')
      scraping_count=$(echo "$service_list" | grep -ci "^scraping$")
      quic_scraping_count=$(echo "$service_list" | grep -ci "^quic_scraping$")
      if [ "$scraping_count" -ne 1 ] || [ "$quic_scraping_count" -ne 1 ]; then
        while IFS= read -r line; do
          if echo "$line" | grep -qi "^scraping$\|^quic_scraping$"; then
            service_id=$(docker exec "$container" jq -r ".[] | select(.type == \"$line\") | .id" /tmp/services.json 2>/dev/null)
            if [ -n "$service_id" ]; then
              echo "Stopping service ID $service_id in $container ($line)"
              docker exec "$container" curl -s -X DELETE http://localhost:4050/services/$service_id 2>/dev/null || echo "Failed to stop service $service_id"
              sleep 2
            fi
          fi
        done <<< "$service_list"
        if [ "$scraping_count" -ne 1 ]; then
          echo "Starting service scraping in $container..."
          docker exec "$container" curl -X POST http://localhost:4050/services -H "Content-Type: application/json" -d "{\"provider_id\": \"$provider_id\", \"type\": \"scraping\"}" -o /tmp/response_start_scraping.json 2>/dev/null || {
            echo "Failed to start scraping in $container with curl, trying CLI..."
            docker exec "$container" myst cli service start "$provider_id" scraping
          }
          sleep 2
        fi
        if [ "$quic_scraping_count" -ne 1 ]; then
          echo "Starting service quic_scraping in $container..."
          docker exec "$container" curl -X POST http://localhost:4050/services -H "Content-Type: application/json" -d "{\"provider_id\": \"$provider_id\", \"type\": \"quic_scraping\"}" -o /tmp/response_start_quic_scraping.json 2>/dev/null || {
            echo "Failed to start quic_scraping in $container with curl, trying CLI..."
            docker exec "$container" myst cli service start "$provider_id" quic_scraping
          }
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
    else
      echo "Failed to get services for $container, assuming all services are missing"
      missing_services="$SERVICES"
    fi
    for service in $missing_services; do
      if [ "$service" != "scraping" ] && [ "$service" != "quic_scraping" ]; then
        echo "Starting service $service in $container..."
        docker exec "$container" curl -X POST http://localhost:4050/services -H "Content-Type: application/json" -d "{\"provider_id\": \"$provider_id\", \"type\": \"$service\"}" -o /tmp/response_start_${service}.json 2>/dev/null || {
          echo "Failed to start $service in $container with curl, trying CLI..."
          docker exec "$container" myst cli service start "$provider_id" "$service"
        }
        sleep 2
      fi
    done
    echo "Service check and restart completed for $container"
    docker exec "$container" rm -f /tmp/identities.json /tmp/identity_status.json /tmp/services.json /tmp/response_start_*.json 2>/dev/null
  done
  echo "Sleeping for 3 hours..."
  sleep 10800
done
