#!/bin/bash

ipv6_info=$(ip -6 addr show)

ipv6_addresses=()

while IFS= read -r line; do
    if [[ $line == *inet6* ]]; then
        ipv6_address=$(echo $line | awk '{print $2}')
        ipv6_addresses+=("$ipv6_address")
    fi
done <<< "$ipv6_info"
echo "ipv6_address: $ipv6_address"

for i in "${!ipv6_addresses[@]}"; do
    ipv6_subnet="${ipv6_addresses[$i]}"
    subnet="${ipv6_subnet%/*}/64"
    echo "Subnet: $subnet"
    docker network create "n$((i + 1))" --driver bridge --subnet "$subnet"
done

echo "Docker network created."
