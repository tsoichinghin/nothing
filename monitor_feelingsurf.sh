#!/bin/bash

while true; do
    PIDS=$(pgrep FeelingSurfView)
    if [ -n "$PIDS" ]; then
        for PID in $PIDS; do
            if ! pgrep -q -f "cpulimit -p $PID"; then
                cpulimit -p "$PID" -l 1 &
            fi
        done
    else
        echo "FeelingSurfView process not found"
    fi

    sleep 1
done
