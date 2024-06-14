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
        sudo truncate -s 0 "$CGROUP_PATH/tasks"
        for PID in $PIDS; do
            echo "$PID" | sudo tee -a "$CGROUP_PATH/tasks"
        done
    else
        echo "FeelingSurfViewer process not found"
        sudo truncate -s 0 "$CGROUP_PATH/tasks"
    fi
    sleep 2
done
