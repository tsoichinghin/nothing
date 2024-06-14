#!/bin/bash

CGROUP_NAME="feeling_surf_viewer"
CGROUP_PATH="/sys/fs/cgroup/cpu/${CGROUP_NAME}"

sudo mkdir -p "$CGROUP_PATH"

while true; do
    PIDS=$(pgrep FeelingSurfView)
    if [ -n "$PIDS" ]; then
        echo "PIDs found: $PIDS"
        for PID in $PIDS; do
            if ! grep -q "$PID" "$CGROUP_PATH/tasks"; then
                echo "Writing PID $PID to $CGROUP_PATH/tasks"
                echo "$PID" | sudo tee "$CGROUP_PATH/tasks"
            fi
        done
    else
        echo "FeelingSurfViewer process not found"
    fi
    sleep 1
done
