#!/bin/sh

# ==============================================================================
# SCRIPT DE AUTO-INSTALACION ENIGMA2
# ==============================================================================
# Este script descarga e instala todos los componentes necesarios desde GitHub.
# Debe ser ejecutado en el decodificador Enigma2.
#
# Uso: wget -O - https://raw.githubusercontent.com/USUARIO/REPO/main/install.sh | sh
# ==============================================================================

# ------------------------------------------------------------------------------
# CONFIGURACION DEL REPOSITORIO (CAMBIAR ESTO ANTES DE SUBIR A GITHUB)
# ------------------------------------------------------------------------------
REPO_URL="https://raw.githubusercontent.com/djgueto/autoinstalador/main"

# ------------------------------------------------------------------------------
# COLORES Y FUNCIONES DE LOG
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# ------------------------------------------------------------------------------
# SOLICITAR DATOS AL USUARIO
# ------------------------------------------------------------------------------
clear
echo "================================================="
echo "   ASISTENTE DE INSTALACION ENIGMA2"
echo "================================================="
echo ""

read -p "Introduce el USUARIO: " CLIENT_USER < /dev/tty
read -p "Introduce la CONTRASEÑA: " CLIENT_PASS < /dev/tty
echo ""
echo "Tipo de Servicio (por defecto 4097):"
echo "  4097 - GStreamer (Estándar)"
echo "  5001 - GSTPlayer"
echo "  5002 - ExtePlayer3"
read -p "Selecciona (Enter para 4097): " SERVICE_TYPE < /dev/tty

if [ -z "$SERVICE_TYPE" ]; then
    SERVICE_TYPE="4097"
fi

echo ""
echo "-------------------------------------------------"
echo "Usuario: $CLIENT_USER"
echo "Pass:    $CLIENT_PASS"
echo "Tipo:    $SERVICE_TYPE"
echo "-------------------------------------------------"
echo ""
read -p "Pulse Enter para comenzar la instalacion..." dummy < /dev/tty

# ------------------------------------------------------------------------------
# 1. PREPARAR SISTEMA Y AÑADIR REPOSITORIOS
# ------------------------------------------------------------------------------
log_info "Añadiendo repositorios adicionales..."

# Jungle Team Feed
wget -O /etc/opkg/jungle-feed.conf http://tropical.jungle-team.online/script/jungle-feed.conf
if [ $? -eq 0 ]; then
    log_info "Repositorio Jungle Team añadido."
else
    log_error "Error al añadir Jungle Team."
fi

# MyNonPublic OEA Feed
wget -O - -q http://updates.mynonpublic.com/oea/feed | bash
if [ $? -eq 0 ]; then
    log_info "Repositorio OEA Feed añadido."
else
    log_error "Error al añadir OEA Feed."
fi

# ------------------------------------------------------------------------------
# 2. CAMBIAR CONTRASEÑA ROOT
# ------------------------------------------------------------------------------
log_info "Estableciendo contraseña de root..."
echo -e "1980Rafael\n1980Rafael" | passwd root > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_info "Contraseña establecida correctamente."
else
    log_error "Fallo al cambiar la contraseña."
fi

# ------------------------------------------------------------------------------
# 3. INSTALAR PAQUETES DE RED Y UTILIDADES
# ------------------------------------------------------------------------------
log_info "Actualizando lista de paquetes (opkg update)..."
opkg update

log_info "Instalando paquetes base..."
opkg install wget curl

log_info "Instalando herramientas de red (iptables, resolvconf, wireguard)..."
opkg install iptables resolvconf wireguard-tools

# ------------------------------------------------------------------------------
# 3b. INSTALAR SERVICEAPP Y REPRODUCTORES (Si se seleccionó 5001/5002)
# ------------------------------------------------------------------------------
if [ "$SERVICE_TYPE" = "5001" ] || [ "$SERVICE_TYPE" = "5002" ]; then
    log_info "Seleccionado tipo de servicio $SERVICE_TYPE. Instalando ServiceApp y reproductores..."
    
    # Actualizar feeds de nuevo por si acaso
    # opkg update # Ya se hizo arriba
    
    log_info "Instalando ServiceApp..."
    # Intentar instalar el plugin de sistema
    opkg install enigma2-plugin-systemplugins-serviceapp
    if [ $? -ne 0 ]; then
        log_info "Intentando alternativa: enigma2-plugin-extensions-serviceapp..."
        opkg install enigma2-plugin-extensions-serviceapp
    fi

    log_info "Instalando exteplayer3 y gstplayer..."
    opkg install exteplayer3
    opkg install gstplayer
    opkg install ffmpeg
    
    if [ $? -eq 0 ]; then
        log_info "Reproductores externos instalados correctamente."
    else
        log_error "Hubo problemas instalando algunos reproductores. Verifique los feeds."
    fi
fi

# ------------------------------------------------------------------------------
# 4. INSTALAR Y CONFIGURAR ZEROTIER
# ------------------------------------------------------------------------------
log_info "Instalando ZeroTier..."
opkg install zerotier

if [ $? -eq 0 ]; then
    log_info "ZeroTier instalado. Iniciando servicio..."
    # Asegurar que el servicio está iniciado antes de unirse
    /etc/init.d/zerotier-one start > /dev/null 2>&1
    sleep 2
    
    log_info "Uniéndose a la red..."
    zerotier-cli join 9f77fc393e7c3f22
    if [ $? -eq 0 ]; then
        log_info "Unido correctamente a la red ZeroTier."
    else
        log_error "Fallo al unirse a la red ZeroTier."
    fi
else
    log_error "Fallo al instalar ZeroTier."
fi

# ------------------------------------------------------------------------------
# 5. INSTALAR EPG IMPORT
# ------------------------------------------------------------------------------
log_info "Instalando EPG Import..."
# Primero intentamos eliminar si existe para instalación limpia
opkg remove enigma2-plugin-extensions-epgimport --force-depends

opkg install enigma2-plugin-extensions-epgimport
if [ $? -ne 0 ]; then
    log_error "Fallo al instalar EPG Import. Intentando forzar dependencias..."
    opkg install enigma2-plugin-extensions-epgimport --force-depends
fi

# Configurar EPG Import
log_info "Configurando EPG Import..."
wget --no-check-certificate "$REPO_URL/epgimport.conf" -O /etc/enigma2/epgimport.conf
if [ $? -eq 0 ]; then
    log_info "Configuración EPG descargada."
else
    log_error "No se pudo descargar epgimport.conf del repositorio."
fi

# ------------------------------------------------------------------------------
# 6. INSTALAR ACTUALIZADOR Y KILLEXTEPLAYER
# ------------------------------------------------------------------------------
log_info "Instalando Actualizador y KillExteplayer..."

# Función para verificar descarga
check_download() {
    if [ ! -s "$1" ]; then
        log_error "El archivo $1 está vacío o no se descargó. Verifica conexión y URL."
        rm -f "$1"
        return 1
    fi
    return 0
}

# Descargar e instalar Actualizador.ipk
log_info "Procesando Actualizador.ipk..."
cd /tmp
wget --no-check-certificate "$REPO_URL/Actualizador.ipk" -O Actualizador.ipk

if check_download "Actualizador.ipk"; then
    opkg install Actualizador.ipk --force-reinstall --force-overwrite
    if [ $? -eq 0 ]; then
        log_info "Actualizador instalado correctamente."
    else
        log_error "Error al instalar Actualizador.ipk"
    fi
    rm -f Actualizador.ipk
fi

# Descargar e instalar enigma2-plugin-extensions-killexteplayer
log_info "Procesando KillExteplayer..."
KILL_SCRIPT="killexteplayer_installer.sh"
wget --no-check-certificate "$REPO_URL/$KILL_SCRIPT" -O "$KILL_SCRIPT"

if check_download "$KILL_SCRIPT"; then
    log_info "Ejecutando instalador de KillExteplayer..."
    chmod +x "$KILL_SCRIPT"
    sh "$KILL_SCRIPT"
    if [ $? -eq 0 ]; then
        log_info "KillExteplayer instalado correctamente."
    else
        log_error "Fallo al instalar KillExteplayer."
    fi
    rm -f "$KILL_SCRIPT"
fi

# Volver al directorio original (aunque no es estrictamente necesario en este script)
cd - > /dev/null

# ------------------------------------------------------------------------------
# 7. CONFIGURAR WIREGUARD
# ------------------------------------------------------------------------------
log_info "Configurando WireGuard..."

# Preguntar siempre, pero permitir saltar con Enter vacío si se desea (opcional)
# El usuario indicó que NO le preguntaba, así que forzamos la pregunta claramente.
while true; do
    read -p "¿Desea configurar WireGuard ahora? (s/n): " CONFIGURE_WG < /dev/tty
    case $CONFIGURE_WG in
        [Ss]* ) 
            mkdir -p /etc/wireguard
            
            # Solicitar datos al usuario
            echo "-------------------------------------------------"
            echo "   CONFIGURACION DE WIREGUARD"
            echo "-------------------------------------------------"
            echo "Por favor, PEGA el contenido completo de tu archivo wg0.conf"
            echo "Cuando termines de pegar, pulsa ENTER y luego Ctrl+D (EOF)."
            echo "-------------------------------------------------"
            
            # Crear archivo de configuración leyendo desde stdin
            # Usamos /dev/tty para asegurar que lee del usuario y no del script pipeado
            cat > /etc/wireguard/wg0.conf < /dev/tty

            log_info "Archivo wg0.conf guardado en /etc/wireguard/"
            
            # Verificar si el archivo se creó y tiene contenido
            if [ -s /etc/wireguard/wg0.conf ]; then
                log_info "Configurando script de inicio y monitoreo de WireGuard..."
                
                # Crear script de inicio /etc/init.d/wireguard
                cat > /etc/init.d/wireguard << 'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          wireguard
# Required-Start:    $network $remote_fs
# Required-Stop:     $network $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: WireGuard VPN multi-interface para Enigma2
### END INIT INFO

DAEMON="/usr/bin/wg-quick"
INTERFACES="wg0 wg1"
PIDFILE_BASE="/var/run/wireguard_monitor"
LOGFILE="/tmp/wireguard-monitor.log"
MAX_LOG_LINES=200
HANDSHAKE_TIMEOUT=180
CHECK_INTERVAL=60
BOOT_WAIT=15

test -x "$DAEMON" || exit 0

# ── Utilidades ────────────────────────────────────────────────────────────────

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
    if [ -f "$LOGFILE" ]; then
        LINES=$(wc -l < "$LOGFILE")
        if [ "$LINES" -gt "$MAX_LOG_LINES" ]; then
            tail -n "$MAX_LOG_LINES" "$LOGFILE" > "${LOGFILE}.tmp" && mv "${LOGFILE}.tmp" "$LOGFILE"
        fi
    fi
}

wait_for_network() {
    local TRIES=0
    local MAX_TRIES=30
    while [ $TRIES -lt $MAX_TRIES ]; do
        if ip route | grep -q "^default"; then
            log_message "Red disponible tras ${TRIES}s"
            return 0
        fi
        sleep 1
        TRIES=$((TRIES + 1))
    done
    log_message "ADVERTENCIA: Red no confirmada tras ${MAX_TRIES}s, intentando de todas formas"
    return 1
}

is_interface_up() {
    ip link show "$1" > /dev/null 2>&1
}

bring_up() {
    local IFACE=$1
    "$DAEMON" down "$IFACE" > /dev/null 2>&1
    sleep 2
    "$DAEMON" up "$IFACE" > /dev/null 2>&1
}

# ── Monitor por interfaz ──────────────────────────────────────────────────────

check_and_reconnect() {
    local INTERFACE=$1
    local PIDFILE="${PIDFILE_BASE}_${INTERFACE}.pid"

    log_message "Monitor arrancado para $INTERFACE (PID: $$)"

    while true; do
        sleep "$CHECK_INTERVAL"

        if ! is_interface_up "$INTERFACE"; then
            log_message "[$INTERFACE] Interfaz caida, reconectando..."
            bring_up "$INTERFACE"
            if is_interface_up "$INTERFACE"; then
                log_message "[$INTERFACE] Reconexion OK"
            else
                log_message "[$INTERFACE] ERROR al reconectar"
            fi
        else
            if command -v wg > /dev/null 2>&1; then
                local LAST_HS
                LAST_HS=$(wg show "$INTERFACE" latest-handshakes 2>/dev/null | awk 'NR==1{print $2}')
                if [ -n "$LAST_HS" ] && [ "$LAST_HS" -gt 0 ] 2>/dev/null; then
                    local CURRENT DIFF
                    CURRENT=$(date +%s)
                    DIFF=$((CURRENT - LAST_HS))
                    if [ "$DIFF" -gt "$HANDSHAKE_TIMEOUT" ]; then
                        log_message "[$INTERFACE] Sin handshake hace ${DIFF}s, reconectando..."
                        bring_up "$INTERFACE"
                        if is_interface_up "$INTERFACE"; then
                            log_message "[$INTERFACE] Reconexion por handshake OK"
                        else
                            log_message "[$INTERFACE] ERROR reconexion por handshake"
                        fi
                    fi
                fi
            fi
        fi
    done
}

# ── Acciones principales ──────────────────────────────────────────────────────

start_wireguard() {
    log_message "=== Iniciando WireGuard ==="
    echo "Esperando a que la red este disponible..."
    sleep "$BOOT_WAIT"
    wait_for_network

    for INTERFACE in $INTERFACES; do
        local CONF="/etc/wireguard/${INTERFACE}.conf"
        if [ ! -f "$CONF" ]; then
            log_message "[$INTERFACE] No existe $CONF, omitiendo"
            continue
        fi

        local PIDFILE="${PIDFILE_BASE}_${INTERFACE}.pid"

        if [ -f "$PIDFILE" ]; then
            kill "$(cat "$PIDFILE")" > /dev/null 2>&1
            rm -f "$PIDFILE"
        fi

        echo "Iniciando $INTERFACE..."
        "$DAEMON" up "$INTERFACE" 2>> "$LOGFILE"

        if is_interface_up "$INTERFACE"; then
            log_message "[$INTERFACE] Interfaz activa"
        else
            log_message "[$INTERFACE] ERROR al iniciar, reintentando..."
            sleep 3
            "$DAEMON" up "$INTERFACE" 2>> "$LOGFILE"
        fi

        check_and_reconnect "$INTERFACE" &
        echo $! > "$PIDFILE"
        log_message "[$INTERFACE] Monitor iniciado (PID: $!)"
    done
}

stop_wireguard() {
    log_message "=== Deteniendo WireGuard ==="
    for INTERFACE in $INTERFACES; do
        echo "Deteniendo $INTERFACE..."
        local PIDFILE="${PIDFILE_BASE}_${INTERFACE}.pid"

        if [ -f "$PIDFILE" ]; then
            kill "$(cat "$PIDFILE")" > /dev/null 2>&1
            rm -f "$PIDFILE"
            log_message "[$INTERFACE] Monitor detenido"
        fi

        "$DAEMON" down "$INTERFACE" > /dev/null 2>&1
        log_message "[$INTERFACE] Interfaz bajada"
    done
}

status_wireguard() {
    for INTERFACE in $INTERFACES; do
        if [ ! -f "/etc/wireguard/${INTERFACE}.conf" ]; then
            continue
        fi

        if is_interface_up "$INTERFACE"; then
            echo "Interfaz $INTERFACE : ACTIVA"
            if command -v wg > /dev/null 2>&1; then
                local LAST_HS
                LAST_HS=$(wg show "$INTERFACE" latest-handshakes 2>/dev/null | awk 'NR==1{print $2}')
                if [ -n "$LAST_HS" ] && [ "$LAST_HS" -gt 0 ] 2>/dev/null; then
                    local DIFF=$(( $(date +%s) - LAST_HS ))
                    echo "  Ultimo handshake: hace ${DIFF}s"
                fi
            fi
        else
            echo "Interfaz $INTERFACE : CAIDA"
        fi

        local PIDFILE="${PIDFILE_BASE}_${INTERFACE}.pid"
        if [ -f "$PIDFILE" ]; then
            local PID
            PID=$(cat "$PIDFILE")
            if kill -0 "$PID" 2>/dev/null; then
                echo "  Monitor : ACTIVO (PID: $PID)"
            else
                echo "  Monitor : MUERTO (PID huerfano: $PID)"
            fi
        else
            echo "  Monitor : NO INICIADO"
        fi
    done

    echo ""
    echo "--- Ultimos logs ---"
    tail -20 "$LOGFILE" 2>/dev/null || echo "Sin logs"
}

# ── Dispatcher ────────────────────────────────────────────────────────────────

case "$1" in
    start)   start_wireguard ;;
    stop)    stop_wireguard ;;
    restart) stop_wireguard; sleep 2; start_wireguard ;;
    status)  status_wireguard ;;
    *)
        echo "Uso: /etc/init.d/wireguard {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
EOF

                # Dar permisos de ejecución
                chmod +x /etc/init.d/wireguard

                # Configurar inicio automático (symlinks manuales para asegurar compatibilidad)
                log_info "Configurando inicio automático..."
                ln -sf /etc/init.d/wireguard /etc/rc0.d/K70wireguard
                ln -sf /etc/init.d/wireguard /etc/rc1.d/K70wireguard
                ln -sf /etc/init.d/wireguard /etc/rc2.d/S10wireguard
                ln -sf /etc/init.d/wireguard /etc/rc3.d/S10wireguard
                ln -sf /etc/init.d/wireguard /etc/rc4.d/S10wireguard
                ln -sf /etc/init.d/wireguard /etc/rc5.d/S10wireguard
                ln -sf /etc/init.d/wireguard /etc/rc6.d/K70wireguard

                # Intentar también update-rc.d por si acaso
                update-rc.d wireguard defaults > /dev/null 2>&1

                # Iniciar servicio
                log_info "Iniciando servicio WireGuard..."
                /etc/init.d/wireguard start

            else
                log_error "El archivo de configuración está vacío. No se ha configurado WireGuard."
            fi
            break
            ;;
        [Nn]* ) 
            log_info "Saltando configuración de WireGuard."
            break
            ;;
        * ) echo "Por favor, responde 's' para sí o 'n' para no.";;
    esac
done

# ------------------------------------------------------------------------------
# 8. CONFIGURAR SCRIPT DE CANALES (downloadLdC.sh)
# ------------------------------------------------------------------------------
log_info "Instalando script de actualización de canales..."

# Asegurar directorio
mkdir -p /usr/script

# Descargar script
wget --no-check-certificate "$REPO_URL/downloadLdC.sh" -O /usr/script/downloadLdC.sh

if [ -f /usr/script/downloadLdC.sh ]; then
    # Personalizar script con los datos introducidos
    sed -i "s|CLIENT_USER=\"\"|CLIENT_USER=\"$CLIENT_USER\"|g" /usr/script/downloadLdC.sh
    sed -i "s|CLIENT_PASS=\"\"|CLIENT_PASS=\"$CLIENT_PASS\"|g" /usr/script/downloadLdC.sh
    sed -i "s|SERVICE_TYPE=\"\"|SERVICE_TYPE=\"$SERVICE_TYPE\"|g" /usr/script/downloadLdC.sh
    
    chmod +x /usr/script/downloadLdC.sh
    log_info "Script downloadLdC.sh instalado y configurado."
    
    # Ejecutar por primera vez
    log_info "Ejecutando actualización de canales..."
    /usr/script/downloadLdC.sh
else
    log_error "No se pudo descargar downloadLdC.sh"
fi

# ------------------------------------------------------------------------------
# 9. EJECUTAR SCRIPT DE PICONS (downloadLoT.sh)
# ------------------------------------------------------------------------------
log_info "Instalando y ejecutando script de picons (downloadLoT.sh)..."

# Descargar script (por si Actualizador.ipk no lo trajo o está desactualizado)
wget --no-check-certificate "$REPO_URL/downloadLoT.sh" -O /usr/script/downloadLoT.sh

if [ -s /usr/script/downloadLoT.sh ]; then
    chmod +x /usr/script/downloadLoT.sh
    /usr/script/downloadLoT.sh
    if [ $? -eq 0 ]; then
        log_info "Picons descargados e instalados correctamente."
    else
        log_error "Hubo un error al ejecutar downloadLoT.sh"
    fi
else
    log_error "No se pudo descargar downloadLoT.sh del repositorio."
fi

# ------------------------------------------------------------------------------
# 10. FINALIZAR
# ------------------------------------------------------------------------------
log_info "Instalación completada. El sistema se reiniciará en 5 segundos."
sleep 5
reboot
