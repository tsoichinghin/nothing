#!/bin/bash

echo "Enter the program!"

while true; do
    window_id=$(xdotool search --name "PacketShare")
    if [ -n "$window_id" ]; then
        packetshare_pid=$(pgrep -f "PacketShare.exe" || true)
        if [ -n "$packetshare_pid" ]; then
            cpulimit -p "$packetshare_pid" -l 10 &
            echo "cpulimit command executed for PacketShare.exe with PID $packetshare_pid"
        else
            echo "PacketShare.exe not running"
        fi
        devilspie2 --debug /home/tch/min.lua
        echo "PacketShare window minimized."
    else
        echo "PacketShare window not found."
    fi
    sleep 5
done
