#!/bin/bash

tmux new-session -d -s edit_session 'fleetshare configure'
sleep 5  
tmux send-keys -t edit_session '2d881781-20c2-43a8-91f4-6f6f7bfedf0a' C-m
sleep 5
IP=$(hostname -I | awk '{print $1}')
tmux send-keys -t edit_session "$IP" C-m
sleep 3
tmux send-keys -t edit_session C-o
sleep 3
tmux send-keys -t edit_session C-m
sleep 3
tmux send-keys -t edit_session C-x 
sleep 3
tmux kill-session -t edit_session
