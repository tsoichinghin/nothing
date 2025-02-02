#!/bin/bash

while true; do
    if ! docker ps -a | grep -q "qmcgaw/gluetun"; then
        initial_pid=$(docker ps -a -q)
        sleep 60
        current_pid=$(docker ps -a -q)
        if [ -n "$initial_pid" ] && [ -n "$current_pid" ]; then
            if [ "$initial_pid" == "$current_pid" ]; then
                reboot
            fi
        fi
        sleep 60
    else
        break
    fi
done
