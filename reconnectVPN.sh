#!/bin/sh
WEBIF_USER="root"
WEBIF_PASS="1980Rafael"

webif_get() {
    local url="$1"
    local out=""
    out="$(wget -q -O - "$url" 2>/dev/null)"
    if [ $? -ne 0 ] && [ -n "$WEBIF_USER" ] && [ -n "$WEBIF_PASS" ]; then
        out="$(wget -q -O - "$url" --user="$WEBIF_USER" --password="$WEBIF_PASS" 2>/dev/null)"
    fi
    printf "%s" "$out"
}

CURRENT_REF="$(webif_get "http://127.0.0.1/web/getcurrent" | sed -n 's/.*<e2servicereference>\(.*\)<\/e2servicereference>.*/\1/p')"

if [ -x /etc/init.d/wireguard ]; then
    /etc/init.d/wireguard restart > /dev/null 2>&1
elif command -v wg-quick > /dev/null 2>&1; then
    wg-quick down wg0 > /dev/null 2>&1
    sleep 2
    wg-quick up wg0 > /dev/null 2>&1
fi

sleep 4

if [ -n "$CURRENT_REF" ]; then
    webif_get "http://127.0.0.1/web/zap?sRef=$CURRENT_REF" > /dev/null 2>&1
    sleep 2
    webif_get "http://127.0.0.1/web/zap?sRef=$CURRENT_REF" > /dev/null 2>&1
fi

exit 0
