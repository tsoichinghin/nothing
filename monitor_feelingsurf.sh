#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

CGROUP_NAME="feeling_surf_viewer"
CGROUP_PATH="/sys/fs/cgroup/cpu/${CGROUP_NAME}"

while true; do
    PIDS=$(pgrep FeelingSurfView)
    if [ -n "$PIDS" ]; then
        for PID in $PIDS; do
            if ! sudo grep -q "^$PID$" "$CGROUP_PATH/tasks"; then
                echo "Adding PID $PID to $CGROUP_PATH/tasks"
                echo "$PID" | sudo tee -a "$CGROUP_PATH/tasks"
            fi
        done
    else
        echo "FeelingSurfViewer process not found"
    fi
    sleep 1
done
