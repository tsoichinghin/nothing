#!/bin/bash

echo "Enter the program!"

while true; do
    packetshare_pid=$(pgrep -f "PacketShare.exe" || true)
    window_id=$(xdotool search --name "PacketShare")
    if [ -n "$packetshare_pid" ]; then
        if [ -n "$window_id" ]; then
            pkill -9 -f cpulimit
            cpulimit -p "$packetshare_pid" -l 10 &
            echo "cpulimit command executed for PacketShare.exe with PID $packetshare_pid"
            devilspie2 /home/tch/.config/devilspie2/min.lua &
            devilspie2_pid=$!
            sleep 30
            kill $devilspie2_pid
            echo "PacketShare window minimized."
        else
            echo "PacketShare window not found."
        fi
        cpu_usage_history=()
        for i in {1..10}; do
            packetshare_cpu_usage=$(ps -p "$packetshare_pid" -o %cpu | tail -n 1 | awk '{printf "%d", $1}')
            echo "CPU usage: $packetshare_cpu_usage"
            cpu_usage_history+=("$packetshare_cpu_usage")
            if [ ${#cpu_usage_history[@]} -gt 10 ]; then
                cpu_usage_history=("${cpu_usage_history[@]:1}")
            fi
            sleep 1
        done
        while true; do
            echo "CPU usage history: ${cpu_usage_history[@]}"
            for usage in "${cpu_usage_history[@]}"; do
                if [ "$usage" -lt 10 ]; then
                    echo "There was at least one second in the past 10 seconds when CPU usage was below 10%."
                    echo "PacketShare.exe CPU usage is normal."
                    break
                fi
            done
            echo "CPU usage was not below 10% in the past 10 seconds."
            echo "CPU usage greater than 10% after minimize or the window even not found. It means doesn't minimize or error."
            echo "PacketShare.exe terminating..."
            kill "$packetshare_pid"
            sleep 1
            wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
            packetshare_pid=$(pgrep -f "PacketShare.exe" || true)
            cpulimit -p "$packetshare_pid" -l 10 &
            sleep 30
            echo "PacketShare.exe restarted."
            break
        done
    else
        echo "PacketShare.exe not running. Restarting..."
        wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
        packetshare_pid=$(pgrep -f "PacketShare.exe" || true)
        cpulimit -p "$packetshare_pid" -l 10 &
        sleep 30
    fi
    sleep 2
done
