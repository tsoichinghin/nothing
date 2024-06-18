#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

CGROUP_NAME="bighits"
CGROUP_PATH="/sys/fs/cgroup/cpu/${CGROUP_NAME}"

while true; do
    render_pids=$(pgrep BigHits4URender)
    viewer_pids=$(pgrep BigHits4UViewer)
    if [ -n "$render_pids" ] or [ -n "$viewer_pids" ]; then
        sudo truncate -s 0 "$CGROUP_PATH/tasks"
        for render_pid in $render_pids; do
            echo "$render_pid" | sudo tee -a "$CGROUP_PATH/tasks"
        done
        for viewer_pid in $viewer_pids; do
            echo "$viewer_pids" | sudo tee -a "$CGROUP_PATH/tasks"
        done
    else
        echo "BitHits process not found"
        sudo truncate -s 0 "$CGROUP_PATH/tasks"
    fi
    sleep 2
done
