#!/bin/bash

echo "Enter the program!"

function check_cpu_usage_below_10 {
    echo "CPU usage history: ${cpu_usage_history[@]}"
    count_below_10=0
    for usage in "${cpu_usage_history[@]}"; do
        if (( usage < 10 )); then
            count_below_10=$((count_below_10 + 1))
        fi
    done
    if (( count_below_10 >= 5 )); then
        return 0
    else
        return 1
    fi
}

while true; do
    packetshare_pid=$(pidof "PacketShare.exe")
    window_id=$(xdotool search --name "PacketShare")
    if [ -n "$packetshare_pid" ]; then
        if [ -n "$window_id" ]; then
            pkill -9 -f cpulimit
            cpulimit -p "$packetshare_pid" -l 20 &
            echo "cpulimit command executed for PacketShare.exe with PID $packetshare_pid"
            cpu_usage_history=()
            for i in {1..10}; do
                packetshare_cpu_usage=$(top -b -n 1 -d 1 -p $packetshare_pid | grep $packetshare_pid | awk '{print $9}')
                packetshare_cpu_usage=${packetshare_cpu_usage%.*}
                echo "CPU usage: $packetshare_cpu_usage"
                cpu_usage_history+=("$packetshare_cpu_usage")
                if [ ${#cpu_usage_history[@]} -gt 10 ]; then
                    cpu_usage_history=("${cpu_usage_history[@]:1}")
                fi
                sleep 1
            done
            check_cpu_usage_below_10
            if check_cpu_usage_below_10; then
               echo "CPU usage at least 5 seconds in past 10 seconds are below 10%."
               echo "CPU usage normal."
            else
               xdotool windowactivate "$window_id"
               echo "PacketShare window activated."
               sleep 10
               devilspie2 /home/tch/.config/devilspie2/min.lua &
               echo "PacketShare window minimized."
               sleep 30
               pkill -9 -f devilspie2
            fi
        else
            echo "PacketShare window not found."
        fi
    else
        echo "PacketShare.exe not running. Restarting..."
        wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
        packetshare_pid=$(pidof "PacketShare.exe")
        cpulimit -p "$packetshare_pid" -l 20 &
        sleep 30
    fi
    sleep 2
done
