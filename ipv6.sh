#!/bin/bash

ipv6_info=$(ip -6 addr show)
ipv6_addresses=()
threshold=20

while IFS= read -r line; do
    if [[ $line == *inet6* ]]; then
        ipv6_address=$(echo $line | awk '{print $2}')
        if [[ ${#ipv6_address} -le $threshold ]] || [[ ! $ipv6_address == */* ]]; then
            continue
        fi
        ipv6_addresses+=("$ipv6_address")
        echo "ipv6_address: $ipv6_address"
    fi
done <<< "$ipv6_info"

i=0

for ipv6_address in "${ipv6_addresses[@]}"; do
    if [[ $ipv6_address == */* ]]; then
        prefix=$(echo "$ipv6_address" | cut -d'/' -f1)
        prefix_length=$(echo "$ipv6_address" | cut -d'/' -f2)
        echo "Prefix: $prefix, Prefix Length: $prefix_length"
        shortened_prefix=$(echo "$prefix" | awk -v len="$prefix_length" '
            BEGIN {
                FS = ":"
                OFS = ":"
            }
            {
                output = ""
                for (i = 1; i <= len/16; i++) {
                    output = output $i ":"
                }
                sub(/:$/, "", output)
                print output
            }
        ')
        echo "Shortened prefix: $shortened_prefix"
        subnet="$shortened_prefix/$prefix_length"
        echo "Subnet: $subnet"
        if [[ $subnet == 2607:* ]]; then
            network_name="isp"
        else
            network_name="n$((i + 1))"
            ((i++))
        fi
        docker network create "$network_name" --driver bridge --subnet "$subnet"
        echo "docker network create $network_name --driver bridge --subnet $subnet"
    else
        echo "IPv6 address $ipv6_address is not in the expected format."
    fi
done

echo "Docker network created."
