#!/bin/bash

while true; do
    counter=0
    for i in {1..500}; do
        counter=$((counter + 1))
        echo "Times $counter"
        packetshare_pid=$(pidof "PacketShare.exe")
        if [ -n "$packetshare_pid" ]; then
            echo "PacketShare.exe were running."
            cpu_usage=$(top -b -n 1 -p "$packetshare_pid" | awk 'NR>7 {print $9}')
            cpu_usage=${cpu_usage%%.*}
            if [ "$cpu_usage" -gt 80 ]; then
                echo "CPU usage is $cpu_usage%. Terminating PacketShare.exe."
                pkill -9 "PacketShare.exe"
            fi
        fi
        sleep 10
    done
done
