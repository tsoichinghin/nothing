#!/bin/bash

while true; do
    counter=0
    for i in {1..500}; do
        counter=$((counter + 1))
        echo "Times $counter"
        packetshare_pid=$(pidof "PacketShare.exe")
        if [ -n "$packetshare_pid" ]; then
            echo "PacketShare.exe were running."
        else
            echo "PacketShare.exe not running. Restarting..."
            wine ~/.wine/drive_c/Program\ Files/PacketShare/PacketShare.exe &
            sleep 30
            python3 ~/check.py
            echo "PacketShare.exe restarted."
        fi
        sleep 10
    done
    python3 ~/check.py
    echo "The loading window was checked."
done
