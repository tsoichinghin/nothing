#!/bin/bash

CGROUP_NAME="feeling_surf_viewer"

while true; do
    PID=$(pgrep FeelingSurfView)
    if [ -n "$PID" ]; then
        echo "$PID" | sudo tee -a "/sys/fs/cgroup/cpu/${CGROUP_NAME}/tasks"
    else
        echo "FeelingSurfViewer process not found"
    fi
    sleep 1
done
