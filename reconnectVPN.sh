#!/bin/sh

if [ -x /etc/init.d/wireguard ]; then
    /etc/init.d/wireguard restart > /dev/null 2>&1
elif command -v wg-quick > /dev/null 2>&1; then
    wg-quick down wg0 > /dev/null 2>&1
    sleep 2
    wg-quick up wg0 > /dev/null 2>&1
fi

sleep 4

exit 0
