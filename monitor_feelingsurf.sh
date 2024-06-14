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
        echo "$PIDS" | sudo tee "$CGROUP_PATH/tasks"
    else
        echo "FeelingSurfViewer process not found"
    fi
    sleep 1
done
