#!/bin/sh

REPO_URL="$1"
[ -n "$REPO_URL" ] || REPO_URL="https://raw.githubusercontent.com/djgueto/autoinstalador/main"

PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/NCQuickActions"
PLUGIN_FILE="$PLUGIN_DIR/plugin.py"
INIT_FILE="$PLUGIN_DIR/__init__.py"

echo "========================================="
echo " NC Quick Actions - Instalador"
echo "========================================="

mkdir -p "$PLUGIN_DIR"
: > "$INIT_FILE"

wget --no-check-certificate "$REPO_URL/nc_quick_actions_plugin.py" -O "$PLUGIN_FILE"
if [ ! -s "$PLUGIN_FILE" ]; then
    rm -f "$PLUGIN_FILE"
    echo "ERROR: No se pudo descargar el plugin"
    exit 1
fi

python -m py_compile "$PLUGIN_FILE" > /dev/null 2>&1 || python3 -m py_compile "$PLUGIN_FILE" > /dev/null 2>&1 || true

echo "Plugin instalado en $PLUGIN_DIR"
exit 0
