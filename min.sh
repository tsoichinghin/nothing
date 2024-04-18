#!/bin/bash

echo "Enter the program!"

while true; do
    window_id=$(xdotool search --name "PacketShare")
    packetshare_pid=$(pgrep -f "PacketShare.exe" || true)
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
            sleep 1
        done
        check_cpu_usage_below_10() {
            echo "CPU usage history: ${cpu_usage_history[@]}"
            for usage in "${cpu_usage_history[@]}"; do
                if (( usage < 10 )); then
                    return 0
                fi
            done
            return 1
        }
        if check_cpu_usage_below_10; then
            echo "There was at least one second in the past 10 seconds when CPU usage was below 10%."
            echo "PacketShare.exe CPU usage is normal."
        else
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
        fi
    else
        echo "PacketShare.exe not running. Restarting..."
        wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
        packetshare_pid=$(pgrep -f "PacketShare.exe" || true)
        cpulimit -p "$packetshare_pid" -l 10 &
        sleep 30
    fi
    sleep 2
done
