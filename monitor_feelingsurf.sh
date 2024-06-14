#!/bin/bash

CGROUP_NAME="feeling_surf_viewer"

while true; do
    PIDS=$(pgrep FeelingSurfView)
    if [ -n "$PIDS" ]; then
        echo "$PIDS" | sudo tee -a "/sys/fs/cgroup/cpu/${CGROUP_NAME}/tasks"
    else
        echo "FeelingSurfViewer process not found"
    fi
    sleep 1
done
