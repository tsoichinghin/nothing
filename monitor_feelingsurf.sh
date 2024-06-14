#!/bin/bash

CGROUP_NAME="feeling_surf_viewer"

while true; do
    PID=$(pgrep FeelingSurfView)

    if [ -n "$PID" ]; then
        echo "Found FeelingSurfViewer process with PID: $PID"
        for PID in $PIDS; do
            echo "$PID" > "/sys/fs/cgroup/cpu/${CGROUP_NAME}/tasks"
        done
    else
        echo "FeelingSurfViewer process not found"
    fi

    sleep 2
done
