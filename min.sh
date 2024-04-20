#!/bin/bash

echo "Enter the program!"

while true; do
    packetshare_pid=$(pidof "PacketShare.exe")
    window_id=$(xdotool search --name "PacketShare")
    if [ -n "$packetshare_pid" ]; then
        if [ -n "$window_id" ]; then
            pkill -9 -f cpulimit
            cpulimit -p "$packetshare_pid" -l 15 &
            echo "cpulimit command executed for PacketShare.exe with PID $packetshare_pid"
            devilspie2 /home/tch/.config/devilspie2/max.lua &
            max_pid=$!
            sleep 30
            kill "$max_pid"
            devilspie2 /home/tch/.config/devilspie2/min.lua &
            min_pid=$!
            sleep 30
            kill "$min_pid"
            echo "PacketShare window minimized."
        else
            echo "PacketShare window not found."
        fi
    else
        echo "PacketShare.exe not running. Restarting..."
        wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
        packetshare_pid=$(pidof "PacketShare.exe")
        cpulimit -p "$packetshare_pid" -l 15 &
        sleep 30
    fi
    sleep 2
done
