#!/bin/bash

while true; do
    if dpkg-query -W -f='${Status}' postfix 2>/dev/null | grep -q "install ok installed"; then
        echo "Postfix detected. Removing..."
        sudo apt-get remove --purge -y postfix
    fi
    if dpkg-query -W -f='${Status}' sendmail 2>/dev/null | grep -q "install ok installed"; then
        echo "Sendmail detected. Removing..."
        sudo apt-get remove --purge -y sendmail
    fi
    if npm list -g | grep -q "haraka"; then
        echo "Haraka detected. Uninstalling..."
        sudo npm uninstall -g Haraka
    fi
done
