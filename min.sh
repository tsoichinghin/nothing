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
        packetshare_cpu_usage=$(ps -p "$packetshare_pid" -o %cpu | tail -n 1 | awk '{printf "%d", $1}')
        echo "cpu usage is $packetshare_cpu_usage"
        if [ "$packetshare_cpu_usage" -gt 10 ]; then
            echo "CPU usage greater than 10 after minimize or the window even not found. It means doesn't minimize or error."
            echo "PacketShare.exe terminating..."
            kill "$packetshare_pid"
            wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
            echo "PacketShare.exe restarted."
        else
            echo "PacketShare.exe CPU usage is normal."
        fi
    else
        echo "PacketShare.exe not running. Restarting..."
        wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
    fi
    sleep 2
done
