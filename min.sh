#!/bin/bash

echo "Enter the program!"

function check_cpu_usage_higher_20 {
    echo "CPU usage history: ${cpu_usage_history[@]}"
    for usage in "${cpu_usage_history[@]}"; do
        if (( usage > 20 )); then
            return 0
        fi
    done
    return 1
}

while true; do
    packetshare_pid=$(pidof PacketShare.exe)
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
            packetshare_cpu_usage=$(top -b -n 1 -d 1 -p $packetshare_pid | grep $packetshare_pid | awk '{print $9}')
            packetshare_cpu_usage=${packetshare_cpu_usage%.*}
            echo "CPU usage: $packetshare_cpu_usage"
            cpu_usage_history+=("$packetshare_cpu_usage")
            if [ ${#cpu_usage_history[@]} -gt 10 ]; then
                cpu_usage_history=("${cpu_usage_history[@]:1}")
            fi
            sleep 1
        done
        check_cpu_usage_higher_20
        if check_cpu_usage_higher_20; then
            echo "At least one second in past 10 second of CPU usage greater than 20% after minimize or the window even not found. It means doesn't minimize or error."
            echo "PacketShare.exe terminating..."
            kill "$packetshare_pid"
            sleep 1
            wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
            packetshare_pid=$(pidof PacketShare.exe)
            cpulimit -p "$packetshare_pid" -l 10 &
            sleep 30
            echo "PacketShare.exe restarted."
        else
            echo "There was no one second in the past 10 seconds when CPU usage was higher than 20%."
            echo "PacketShare.exe CPU usage is normal."
        fi
    else
        echo "PacketShare.exe not running. Restarting..."
        wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
        packetshare_pid=$(pidof PacketShare.exe)
        cpulimit -p "$packetshare_pid" -l 10 &
        sleep 30
    fi
    sleep 2
done
