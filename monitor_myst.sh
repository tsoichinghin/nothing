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
            docker restart "$container"
        done
        sleep 10
        containers=$(docker ps --filter "name=myst" --format "{{.Names}}")
        if [ -z "$containers" ]; then
            echo "No myst containers available after starting."
            sleep 3600
            continue
        fi
    fi

    current_time=$(date +%s)
    if [ "$current_time" -ge "$next_payout_date" ]; then
        echo "Payout time reached, processing withdrawals for all containers..."
        for container in $containers; do
            echo "Processing withdrawal for container: $container"
            provider_id=$(docker exec "$container" myst cli identities list 2>/dev/null | grep -oE "0x[0-9a-fA-F]{40}" | head -n 1)
            if [ -z "$provider_id" ]; then
                echo "Failed to get provider_id for $container, skipping withdrawal"
                continue
            fi
            echo "Provider ID for withdrawal: $provider_id"
            docker exec "$container" myst cli identities settle "$provider_id"
            echo "Withdrawal attempted for $container"
        done
        current_time=$(date +%s)
        next_payout_date=$((current_time + 30*24*60*60))
        echo "Next payout date updated: $(date -d @$next_payout_date)"
    fi

    for container in $containers; do
        echo "Processing container: $container"

        if docker logs --tail 10 "$container" 2>&1 | grep -i "timeout"; then
            echo "Timeout detected in $container, restarting..."
            docker restart "$container"
            echo "Waiting 60 seconds for $container to restart..."
            sleep 60
        fi

        provider_id=""
        provider_id=$(docker exec "$container" myst cli identities list 2>/dev/null | grep -oE "0x[0-9a-fA-F]{40}" | head -n 1)
        if [ -z "$provider_id" ]; then
            echo "Failed to get provider_id for $container, raw output:"
            docker exec "$container" myst cli identities list 2>&1 | cat -A
            echo "Container status:"
            docker ps -a --filter "name=$container"
            continue
        fi
        echo "Provider ID for $container: $provider_id"

        missing_services=""
        scraping_count=0
        quic_scraping_count=0
        service_list=$(docker exec "$container" myst cli service list 2>/dev/null)
        if [ -n "$service_list" ]; then
            scraping_count=$(echo "$service_list" | grep -c "Type: scraping")
            quic_scraping_count=$(echo "$service_list" | grep -c "Type: quic_scraping")

            if [ "$scraping_count" -ne 1 ] || [ "$quic_scraping_count" -ne 1 ]; then
                while IFS= read -r line; do
                    if echo "$line" | grep -q "Type: scraping\|Type: quic_scraping"; then
                        service_id=$(echo "$line" | awk '{print $3}')
                        echo "Stopping service ID $service_id in $container (scraping or quic_scraping)"
                        docker exec "$container" myst cli service stop "$service_id"
                        sleep 2
                    fi
                done <<< "$service_list"
                echo "Starting service scraping in $container..."
                docker exec "$container" myst cli service start "$provider_id" scraping
                sleep 2
            fi

            for service in $SERVICES; do
                if [ "$service" != "scraping" ] && [ "$service" != "quic_scraping" ]; then
                    if ! echo "$service_list" | grep -q "Type: $service"; then
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
                docker exec "$container" myst cli service start "$provider_id" "$service"
                sleep 2
            fi
        done
        echo "Service restart completed for $container"
    done

    echo "Sleeping for 3 hour..."
    sleep 172800
done
