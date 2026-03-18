#!/bin/sh
WEBIF_USER="root"
WEBIF_PASS="1980Rafael"
URL="http://127.0.0.1/web/powerstate?newstate=0"
wget -q -O /dev/null "$URL" 2>/dev/null || wget -q -O /dev/null "$URL" --user="$WEBIF_USER" --password="$WEBIF_PASS" 2>/dev/null
exit 0
