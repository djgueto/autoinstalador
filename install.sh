#!/bin/sh

# ==============================================================================
# SCRIPT DE AUTO-INSTALACION ENIGMA2 - OPTIMIZADO
# ==============================================================================
# Uso: wget -O - https://raw.githubusercontent.com/djgueto/autoinstalador/main/install.sh | sh
# ==============================================================================

# ------------------------------------------------------------------------------
# CONFIGURACION GLOBAL
# ------------------------------------------------------------------------------
REPO_URL="https://raw.githubusercontent.com/djgueto/autoinstalador/main"
VERSION="v3.0 (Refactorizado)"

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Archivos y Directorios
SETTINGS_FILE="/etc/enigma2/settings"
OSCAM_CONFIG_DIR="/etc/tuxbox/config/oscam-update"
WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/wg0.conf"
WG_INIT="/etc/init.d/wireguard"

# ------------------------------------------------------------------------------
# FUNCIONES DE UTILIDAD
# ------------------------------------------------------------------------------

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[AVISO] $1${NC}"
}

check_download() {
    if [ ! -s "$1" ]; then
        log_error "El archivo $1 está vacío o no se descargó. Verifica conexión y URL."
        rm -f "$1"
        return 1
    fi
    return 0
}

add_setting() {
    local key="$1"
    local line="$2"
    if [ -f "$SETTINGS_FILE" ]; then
        if ! grep -q "^$key" "$SETTINGS_FILE"; then
            echo "$line" >> "$SETTINGS_FILE"
        fi
    fi
}

install_package() {
    local pkg="$1"
    log_info "Instalando $pkg..."
    opkg install "$pkg"
    if [ $? -eq 0 ]; then
        return 0
    else
        log_warn "Fallo al instalar $pkg. Intentando forzar dependencias..."
        opkg install "$pkg" --force-depends
        return $?
    fi
}

remove_package() {
    local pkg="$1"
    log_info "Eliminando $pkg..."
    opkg remove "$pkg" --force-depends > /dev/null 2>&1
}

# ------------------------------------------------------------------------------
# FUNCIONES DE CONFIGURACION DE SISTEMA
# ------------------------------------------------------------------------------

step_0_init_system() {
    clear
    echo "================================================="
    echo "   ASISTENTE DE INSTALACION ENIGMA2 $VERSION"
    echo "================================================="
    echo ""

    # Solicitar datos
    read -p "Introduce el USUARIO: " CLIENT_USER < /dev/tty
    read -p "Introduce la CONTRASEÑA: " CLIENT_PASS < /dev/tty
    echo ""
    read -p "¿Desea instalar OSCam (oscam-conclave)? (s/n): " INSTALL_OSCAM < /dev/tty
    echo ""
    echo "Tipo de Servicio (por defecto 4097):"
    echo "  4097 - GStreamer (Estándar)"
    echo "  5001 - GSTPlayer"
    echo "  5002 - ExtePlayer3"
    read -p "Selecciona (Enter para 4097): " SERVICE_TYPE < /dev/tty

    [ -z "$SERVICE_TYPE" ] && SERVICE_TYPE="4097"

    echo ""
    echo "-------------------------------------------------"
    echo "Usuario: $CLIENT_USER"
    echo "Pass:    $CLIENT_PASS"
    echo "Tipo:    $SERVICE_TYPE"
    echo "OSCam:   $INSTALL_OSCAM"
    echo "-------------------------------------------------"
    echo ""
    read -p "Pulse Enter para comenzar la instalacion..." dummy < /dev/tty

    # Configuración básica
    log_info "Configurando DNS (Google)..."
    echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf

    log_info "Sincronizando hora..."
    SYNC_OK=0

    # 1. Intentar ntpdate
    if command -v ntpdate > /dev/null 2>&1; then
        if ntpdate -u pool.ntp.org > /dev/null 2>&1; then
            SYNC_OK=1
            log_info "Hora sincronizada con ntpdate."
        fi
    fi

    # 2. Intentar rdate si ntpdate falló
    if [ $SYNC_OK -eq 0 ] && command -v rdate > /dev/null 2>&1; then
        if rdate -s pool.ntp.org > /dev/null 2>&1; then
            SYNC_OK=1
            log_info "Hora sincronizada con rdate (pool.ntp.org)."
        elif rdate -s time.nist.gov > /dev/null 2>&1; then
            SYNC_OK=1
            log_info "Hora sincronizada con rdate (time.nist.gov)."
        fi
    fi

    # 3. Fallback HTTP (Google) si todo lo anterior falló
    if [ $SYNC_OK -eq 0 ]; then
        log_warn "Métodos NTP fallaron. Intentando ajuste vía HTTP..."
        CURRENT_DATE=$(wget --no-check-certificate -S --spider https://google.com 2>&1 | grep "Date:" | sed 's/  Date: //')
        if [ -n "$CURRENT_DATE" ]; then
            date -s "$CURRENT_DATE"
            log_info "Hora actualizada vía HTTP: $CURRENT_DATE"
        else
            log_error "No se pudo sincronizar la hora. Posibles errores SSL futuros."
        fi
    fi

    log_info "Deteniendo Enigma2 (init 4)..."
    init 4
    sleep 5
}

step_1_repos_and_update() {
    log_info "Añadiendo repositorios adicionales..."
    wget -O /etc/opkg/jungle-feed.conf http://tropical.jungle-team.online/script/jungle-feed.conf
    wget -O - -q http://updates.mynonpublic.com/oea/feed | bash

    log_info "Estableciendo contraseña root..."
    echo -e "1980Rafael\n1980Rafael" | passwd root > /dev/null 2>&1

    log_info "Actualizando paquetes..."
    opkg update
    
    # Limpieza preventiva
    remove_package "enigma2-plugin-systemplugins-artkoala"
}

step_2_install_base_packages() {
    log_info "Instalando paquetes base y herramientas de red..."
    opkg install wget curl iptables resolvconf wireguard-tools

    if [ "$SERVICE_TYPE" = "5001" ] || [ "$SERVICE_TYPE" = "5002" ]; then
        log_info "Instalando ServiceApp y reproductores..."
        if ! install_package "enigma2-plugin-systemplugins-serviceapp"; then
            install_package "enigma2-plugin-extensions-serviceapp"
        fi
        opkg install exteplayer3 gstplayer ffmpeg
    fi
}

step_3_install_zerotier() {
    log_info "Instalando ZeroTier..."
    if install_package "zerotier"; then
        log_info "Iniciando ZeroTier..."
        /etc/init.d/zerotier-one start > /dev/null 2>&1
        sleep 5 # Espera de seguridad
        log_info "Uniéndose a la red..."
        zerotier-cli join 9f77fc393e7c3f22
    else
        log_error "Fallo crítico instalando ZeroTier."
    fi
}

step_4_install_epg() {
    log_info "Instalando EPG Import..."
    remove_package "enigma2-plugin-extensions-epgimport"
    install_package "enigma2-plugin-extensions-epgimport"

    log_info "Descargando configuración EPG..."
    wget --no-check-certificate "$REPO_URL/epgimport.conf" -O /etc/enigma2/epgimport.conf
}

step_5_configure_enigma2() {
    log_info "Optimizando configuración de Enigma2..."
    if [ -f "$SETTINGS_FILE" ]; then
        # EPG Import
        add_setting "config.plugins.epgimport.deepstandby" "config.plugins.epgimport.deepstandby=wakeup"
        add_setting "config.plugins.epgimport.enabled" "config.plugins.epgimport.enabled=True"
        add_setting "config.plugins.epgimport.runboot" "config.plugins.epgimport.runboot=1"
        add_setting "config.plugins.epgimport.import_onlybouquet" "config.plugins.epgimport.import_onlybouquet=False"
        add_setting "config.plugins.epgimport.import_onlyiptv" "config.plugins.epgimport.import_onlyiptv=False"
        add_setting "config.plugins.epgimport.shutdown" "config.plugins.epgimport.shutdown=True"
        add_setting "config.plugins.epgimport.wakeup" "config.plugins.epgimport.wakeup=4:30"
        
        # OpenWebif
        add_setting "config.OpenWebif.auth" "config.OpenWebif.auth=True"
        add_setting "config.OpenWebif.port" "config.OpenWebif.port=8080"
        
        # General
        add_setting "config.usage.numberMode" "config.usage.numberMode=1"
        add_setting "config.usage.fbc_automatic_standby" "config.usage.fbc_automatic_standby=True"
        add_setting "config.usage.service_icon_enable" "config.usage.service_icon_enable=True"
        
        log_info "Settings actualizados."
    else
        log_error "No se encontró $SETTINGS_FILE."
    fi
}

step_6_install_plugins() {
    log_info "Instalando Plugins adicionales..."
    cd /tmp

    # Actualizador
    wget --no-check-certificate "$REPO_URL/Actualizador.ipk?v=$(date +%s)" -O Actualizador.ipk
    if check_download "Actualizador.ipk"; then
        opkg install Actualizador.ipk --force-reinstall --force-overwrite
        rm -f Actualizador.ipk
    fi

    # KillExteplayer
    local KILL_SCRIPT="killexteplayer_installer.sh"
    wget --no-check-certificate "$REPO_URL/$KILL_SCRIPT" -O "$KILL_SCRIPT"
    if check_download "$KILL_SCRIPT"; then
        sh "$KILL_SCRIPT"
        rm -f "$KILL_SCRIPT"
    fi
    cd - > /dev/null
}

step_7_configure_wireguard() {
    while true; do
        read -p "¿Desea configurar WireGuard ahora? (s/n): " CONFIGURE_WG < /dev/tty
        case $CONFIGURE_WG in
            [Ss]* )
                mkdir -p "$WG_DIR"
                echo "-------------------------------------------------"
                echo "   CONFIGURACION DE WIREGUARD"
                echo "-------------------------------------------------"
                echo "Por favor, PEGA el contenido de wg0.conf y pulsa ENTER + Ctrl+D (EOF)."
                cat > "$WG_CONF" < /dev/tty

                if [ -s "$WG_CONF" ]; then
                    log_info "Generando script de inicio WireGuard..."
                    create_wireguard_init_script
                    
                    chmod +x "$WG_INIT"
                    # Enlaces simbólicos
                    ln -sf "$WG_INIT" /etc/rc0.d/K70wireguard
                    ln -sf "$WG_INIT" /etc/rc1.d/K70wireguard
                    ln -sf "$WG_INIT" /etc/rc2.d/S10wireguard
                    ln -sf "$WG_INIT" /etc/rc3.d/S10wireguard
                    ln -sf "$WG_INIT" /etc/rc4.d/S10wireguard
                    ln -sf "$WG_INIT" /etc/rc5.d/S10wireguard
                    ln -sf "$WG_INIT" /etc/rc6.d/K70wireguard
                    
                    update-rc.d wireguard defaults > /dev/null 2>&1
                    "$WG_INIT" start
                else
                    log_error "Archivo wg0.conf vacío."
                fi
                break
                ;;
            [Nn]* ) break ;;
            * ) echo "Responde 's' o 'n'." ;;
        esac
    done
}

step_8_install_scripts() {
    log_info "Instalando scripts de canales y picons..."
    mkdir -p /usr/script

    # downloadLdC.sh
    wget --no-check-certificate "$REPO_URL/downloadLdC.sh" -O /usr/script/downloadLdC.sh
    if [ -f /usr/script/downloadLdC.sh ]; then
        sed -i "s|CLIENT_USER=\"\"|CLIENT_USER=\"$CLIENT_USER\"|g" /usr/script/downloadLdC.sh
        sed -i "s|CLIENT_PASS=\"\"|CLIENT_PASS=\"$CLIENT_PASS\"|g" /usr/script/downloadLdC.sh
        sed -i "s|SERVICE_TYPE=\"\"|SERVICE_TYPE=\"$SERVICE_TYPE\"|g" /usr/script/downloadLdC.sh
        chmod +x /usr/script/downloadLdC.sh
        /usr/script/downloadLdC.sh
    fi

    # downloadLoT.sh
    # Se asume instalado por Actualizador.ipk, pero verificamos ejecución
    if [ -f /usr/script/downloadLoT.sh ]; then
        chmod +x /usr/script/downloadLoT.sh
        while true; do
            log_info "Ejecutando descarga de picons..."
            /usr/script/downloadLoT.sh > /tmp/downloadLoT.log 2>&1
            if [ $? -eq 0 ]; then
                log_info "Picons instalados correctamente."
                break
            else
                log_error "Error en picons. Ver /tmp/downloadLoT.log"
                tail -n 20 /tmp/downloadLoT.log
                read -p "¿Reintentar? (s/n): " RETRY < /dev/tty
                [[ "$RETRY" != [Ss]* ]] && break
            fi
        done
    fi
}

step_9_install_oscam() {
    case $INSTALL_OSCAM in
        [Ss]* )
            log_info "Instalando OSCam..."
            opkg install enigma2-plugin-softcams-oscam-conclave --force-overwrite
            
            mkdir -p "$OSCAM_CONFIG_DIR"
            generate_oscam_files
            
            # --- FIX: Asegurar compatibilidad copiando a ruta estándar ---
            log_info "Asegurando configuración de OSCam..."
            cp -f "$OSCAM_CONFIG_DIR/oscam.conf" /etc/tuxbox/config/oscam.conf > /dev/null 2>&1
            cp -f "$OSCAM_CONFIG_DIR/oscam.server" /etc/tuxbox/config/oscam.server > /dev/null 2>&1
            
            # Permisos
            chmod 755 "$OSCAM_CONFIG_DIR"
            chmod 644 "$OSCAM_CONFIG_DIR/"*
            chmod 644 /etc/tuxbox/config/oscam.* > /dev/null 2>&1

            # Activar en settings
            if [ -f "$SETTINGS_FILE" ]; then
                log_info "Activando OSCam en arranque..."
                grep -v "config.misc.softcams=" "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
                echo "config.misc.softcams=oscam_conclave" >> "${SETTINGS_FILE}.tmp"
                mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
            fi

            # Iniciar servicio
            log_info "Iniciando OSCam..."
            
            # Asegurar permisos de ejecución (usando 755 como se hace manualmente)
            [ -f "/usr/bin/oscam_conclave" ] && chmod 755 /usr/bin/oscam_conclave
            [ -f "/usr/bin/oscam" ] && chmod 755 /usr/bin/oscam

            CAM_SCRIPT=$(find /etc/init.d -name "softcam.oscam*" | head -n 1)
            STARTED=0
            
            if [ -n "$CAM_SCRIPT" ] && [ -x "$CAM_SCRIPT" ]; then
                log_info "Usando script de inicio: $(basename "$CAM_SCRIPT")"
                "$CAM_SCRIPT" start > /dev/null 2>&1
                sleep 2
                if ps | grep -v grep | grep -q "oscam"; then
                    STARTED=1
                fi
            fi
            
            if [ $STARTED -eq 0 ]; then
                log_warn "Script de inicio falló o no existe. Intentando inicio manual desde /usr/bin..."
                # Intentar forzar exactamente como funciona manualmente:
                # cd /usr/bin/
                # ./oscam_conclave -b
                if [ -x "/usr/bin/oscam_conclave" ]; then
                    (cd /usr/bin && ./oscam_conclave -b) > /dev/null 2>&1
                elif [ -x "/usr/bin/oscam" ]; then
                    (cd /usr/bin && ./oscam -b) > /dev/null 2>&1
                fi
            fi
            
            sleep 3
            if ps | grep -v grep | grep -q "oscam"; then
                log_info "OSCam iniciado correctamente."
            else
                log_error "No se pudo iniciar OSCam. Verifique /tmp/oscam.log si existe."
                # Intento de diagnóstico
                if [ -x "/usr/bin/oscam_conclave" ]; then
                    log_warn "Prueba de ejecución directa:"
                    (cd /usr/bin && ./oscam_conclave --help | head -n 1)
                fi
            fi
            ;;
    esac
}

step_10_finalize() {
    log_info "Instalación completada. Reiniciando en 5 segundos..."
    sleep 5
    reboot
}

# ------------------------------------------------------------------------------
# GENERADORES DE ARCHIVOS (Heredocs)
# ------------------------------------------------------------------------------

create_wireguard_init_script() {
    cat > "$WG_INIT" << 'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          wireguard
# Required-Start:    $network $remote_fs
# Required-Stop:     $network $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: WireGuard VPN multi-interface
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
    return 1
}

is_interface_up() {
    ip link show "$1" > /dev/null 2>&1
}

bring_up() {
    "$DAEMON" down "$1" > /dev/null 2>&1
    sleep 2
    "$DAEMON" up "$1" > /dev/null 2>&1
}

check_and_reconnect() {
    local INTERFACE=$1
    log_message "Monitor arrancado para $INTERFACE (PID: $$)"
    while true; do
        sleep "$CHECK_INTERVAL"
        if ! is_interface_up "$INTERFACE"; then
            log_message "[$INTERFACE] Interfaz caida, reconectando..."
            bring_up "$INTERFACE"
        else
            if command -v wg > /dev/null 2>&1; then
                local LAST_HS
                LAST_HS=$(wg show "$INTERFACE" latest-handshakes 2>/dev/null | awk 'NR==1{print $2}')
                if [ -n "$LAST_HS" ] && [ "$LAST_HS" -gt 0 ] 2>/dev/null; then
                    local DIFF=$(( $(date +%s) - LAST_HS ))
                    if [ "$DIFF" -gt "$HANDSHAKE_TIMEOUT" ]; then
                        log_message "[$INTERFACE] Sin handshake hace ${DIFF}s, reconectando..."
                        bring_up "$INTERFACE"
                    fi
                fi
            fi
        fi
    done
}

start_wireguard() {
    log_message "=== Iniciando WireGuard ==="
    sleep "$BOOT_WAIT"
    wait_for_network
    for INTERFACE in $INTERFACES; do
        local CONF="/etc/wireguard/${INTERFACE}.conf"
        [ ! -f "$CONF" ] && continue
        
        local PIDFILE="${PIDFILE_BASE}_${INTERFACE}.pid"
        [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" > /dev/null 2>&1 && rm -f "$PIDFILE"
        
        "$DAEMON" up "$INTERFACE" 2>> "$LOGFILE"
        check_and_reconnect "$INTERFACE" &
        echo $! > "$PIDFILE"
    done
}

stop_wireguard() {
    log_message "=== Deteniendo WireGuard ==="
    for INTERFACE in $INTERFACES; do
        local PIDFILE="${PIDFILE_BASE}_${INTERFACE}.pid"
        [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" > /dev/null 2>&1 && rm -f "$PIDFILE"
        "$DAEMON" down "$INTERFACE" > /dev/null 2>&1
    done
}

case "$1" in
    start)   start_wireguard ;;
    stop)    stop_wireguard ;;
    restart) stop_wireguard; sleep 2; start_wireguard ;;
    *)       exit 1 ;;
esac
exit 0
EOF
}

generate_oscam_files() {
    cat > "$OSCAM_CONFIG_DIR/oscam.conf" <<EOF
# oscam.conf generated automatically
[global]
logfile                       = /tmp/oscam.log
clienttimeout                 = 4000
fallbacktimeout               = 1500
clientmaxidle                 = 100
nice                          = -1
maxlogsize                    = 100
readerrestartseconds          = 6
disablecrccws                 = 1
disablecrccws_only_for        = 1810:000000,004101,004001

[dvbapi]
enabled                       = 1
au                            = 1
pmt_mode                      = 0
delayer                       = 50
user                          = dvbapi

[webif]
httpport                      = 1980
httpuser                      = root
httppwd                       = 1980Rafael
httprefresh                   = 10
httppollrefresh               = 10
httpallowed                   = 127.0.0.1,0.0.0.0-255.255.255.255
EOF

    cat > "$OSCAM_CONFIG_DIR/oscam.server" <<EOF
[reader]
label                         = RAFATV(wireward_202)SD
protocol                      = newcamd
device                        = 10.8.0.202,34001
key                           = 0204060810121416182022242628
user                          = $CLIENT_USER
password                      = Sistema0891
inactivitytimeout             = -1
disableserverfilter           = 1
connectoninit                 = 1
disablecrccws_only_for        = 0100:004106,004108,005001
caid                          = 0100
group                         = 2,3
disablecrccws                 = 1

[reader]
label                         = RAFATV(wireward_202)HD
protocol                      = newcamd
device                        = 10.8.0.202,34002
key                           = 0204060810121416182022242628
user                          = $CLIENT_USER
password                      = Sistema0891
inactivitytimeout             = -1
disableserverfilter           = 1
connectoninit                 = 1
disablecrccws_only_for        = 1810:000000,004101,004001
group                         = 1
disablecrccws                 = 1

[reader]
label                         = RAFATV(wireward_203)SD
protocol                      = newcamd
device                        = 10.8.0.203,35001
key                           = 0204060810121416182022242628
user                          = $CLIENT_USER
password                      = Sistema0891
inactivitytimeout             = -1
disableserverfilter           = 1
connectoninit                 = 1
disablecrccws_only_for        = 0100:004106,004108,005001
group                         = 2,3
disablecrccws                 = 1

[reader]
label                         = RAFATV(wireward_203)HD
protocol                      = newcamd
device                        = 10.8.0.203,35002
key                           = 0204060810121416182022242628
user                          = $CLIENT_USER
password                      = Sistema0891
inactivitytimeout             = -1
disableserverfilter           = 1
connectoninit                 = 1
disablecrccws_only_for        = 1810:000000,004101,004001
group                         = 1
disablecrccws                 = 1

[reader]
label                         = RAFATV(zerotier_202)SD
protocol                      = newcamd
device                        = 172.24.1.202,34001
key                           = 0204060810121416182022242628
user                          = $CLIENT_USER
password                      = Sistema0891
inactivitytimeout             = -1
disableserverfilter           = 1
connectoninit                 = 1
disablecrccws_only_for        = 0100:004106,004108,005001
caid                          = 0100
group                         = 2,3
disablecrccws                 = 1

[reader]
label                         = RAFATV(zerotier_202)HD
protocol                      = newcamd
device                        = 172.24.1.202,34002
key                           = 0204060810121416182022242628
user                          = $CLIENT_USER
password                      = Sistema0891
inactivitytimeout             = -1
disableserverfilter           = 1
connectoninit                 = 1
disablecrccws_only_for        = 1810:000000,004101,004001
group                         = 1
disablecrccws                 = 1

[reader]
label                         = RAFATV(zerotier_203)SD
protocol                      = newcamd
device                        = 172.24.1.203,35001
key                           = 0204060810121416182022242628
user                          = $CLIENT_USER
password                      = Sistema0891
inactivitytimeout             = -1
disableserverfilter           = 1
connectoninit                 = 1
disablecrccws_only_for        = 0100:004106,004108,005001
group                         = 2,3
disablecrccws                 = 1

[reader]
label                         = RAFATV(zerotier_203)HD
protocol                      = newcamd
device                        = 172.24.1.203,35002
key                           = 0204060810121416182022242628
user                          = $CLIENT_USER
password                      = Sistema0891
inactivitytimeout             = -1
disableserverfilter           = 1
connectoninit                 = 1
disablecrccws_only_for        = 1810:000000,004101,004001
group                         = 1
disablecrccws                 = 1
EOF
}

# ------------------------------------------------------------------------------
# EJECUCION PRINCIPAL
# ------------------------------------------------------------------------------

main() {
    step_0_init_system
    step_1_repos_and_update
    step_2_install_base_packages
    step_3_install_zerotier
    step_4_install_epg
    step_5_configure_enigma2
    step_6_install_plugins
    step_7_configure_wireguard
    step_8_install_scripts
    step_9_install_oscam
    step_10_finalize
}

# Iniciar
main
