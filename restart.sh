#!/bin/bash

SMTP_SERVER="smtp.office365.com"
SMTP_PORT=587
EMAIL_FROM="tsoivm@outlook.com"
EMAIL_TO="tsoichinghin@gmail.com"
SUBJECT="$(hostname) PacketShare.exe Terminated"

while true; do
    counter=0
    for i in {1..500}; do
        counter=$((counter + 1))
        echo "Times $counter"
        packetshare_pid=$(pidof "PacketShare.exe")
        if [ -n "$packetshare_pid" ]; then
            echo "PacketShare.exe were running."
            cpu_usage=$(top -b -n 1 -p "$packetshare_pid" | awk 'NR>7 {print $9}')
            cpu_usage=${cpu_usage%%.*}
            if [ "$cpu_usage" -gt 30 ]; then
                echo "CPU usage is $cpu_usage%. Terminating PacketShare.exe."
                pkill -9 "PacketShare.exe"
                echo -e "Subject:$SUBJECT\n\nPacketShare.exe was terminated due to high CPU usage ($cpu_usage%)." | \
                    msmtp --host=$SMTP_SERVER --port=$SMTP_PORT --auth=on --user=$EMAIL_FROM --passwordeval="echo $EMAIL_PASSWORD" --tls=on $EMAIL_TO
            fi
        else:
            echo -e "Subject:$SUBJECT\n\nPacketShare.exe was terminated due to high CPU usage ($cpu_usage%)." | \
                msmtp --host=$SMTP_SERVER --port=$SMTP_PORT --auth=on --user=$EMAIL_FROM --passwordeval="echo $EMAIL_PASSWORD" --tls=on $EMAIL_TO
        fi
        sleep 10
    done
done
