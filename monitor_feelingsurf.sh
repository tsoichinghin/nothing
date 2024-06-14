#!/bin/bash

CGROUP_NAME="feeling_surf_viewer"

while true; do
    PIDS=$(pgrep FeelingSurfView)
    if [ -n "$PIDS" ]; then
        for PID in $PIDS; do
            echo "$PID" | sudo tee -a "/sys/fs/cgroup/cpu/${CGROUP_NAME}/tasks"
        done
    else
        echo "FeelingSurfViewer process not found"
    fi
    sleep 1
done
