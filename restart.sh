#!/bin/bash

while true; do
    packetshare_pid=$(pidof "PacketShare.exe")
    if [ -n "$packetshare_pid" ]; then
        echo "PacketShare.exe were running."
    else
        echo "PacketShare.exe not running. Restarting..."
        wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
        echo "First restarting."
        sleep 30
        pkill -9 -f PacketShare.exe
        sleep 10
        wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
        echo "Second restarting."
        sleep 30
        echo "PacketShare.exe restarted."
    fi
    sleep 10
done
