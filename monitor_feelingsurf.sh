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
        sudo awk -v pids="$PIDS" 'BEGIN {split(pids, a, " ")} {if (!($1 in a)) print $1}' "$CGROUP_PATH/tasks" | sudo tee "$CGROUP_PATH/tasks" > /dev/null
        for PID in $PIDS; do
            if ! sudo grep -q "^$PID$" "$CGROUP_PATH/tasks"; then
                echo "Adding PID $PID to $CGROUP_PATH/tasks"
                echo "$PID" | sudo tee -a "$CGROUP_PATH/tasks"
            fi
        done
    else
        echo "FeelingSurfViewer process not found"
        sudo truncate -s 0 "$CGROUP_PATH/tasks"
    fi
    sleep 1
done
