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

read -p "Introduce el USUARIO: " CLIENT_USER
read -p "Introduce la CONTRASEÑA: " CLIENT_PASS
echo ""
echo "Tipo de Servicio (por defecto 4097):"
echo "  4097 - GStreamer (Estándar)"
echo "  5001 - GSTPlayer"
echo "  5002 - ExtePlayer3"
read -p "Selecciona (Enter para 4097): " SERVICE_TYPE

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
read -p "Pulse Enter para comenzar la instalacion..." dummy

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
    opkg install Actualizador.ipk
    if [ $? -eq 0 ]; then
        log_info "Actualizador instalado correctamente."
    else
        log_error "Error al instalar Actualizador.ipk"
    fi
    rm -f Actualizador.ipk
fi

# Descargar e instalar enigma2-plugin-extensions-killexteplayer
log_info "Procesando KillExteplayer..."
KILL_PKG="enigma2-plugin-extensions-killexteplayer_1.0-r0_mips32el.ipk"
wget --no-check-certificate "$REPO_URL/$KILL_PKG" -O "$KILL_PKG"

if check_download "$KILL_PKG"; then
    # Intentar instalación forzada si la normal falla (posible error de arquitectura o control file)
    opkg install "$KILL_PKG"
    if [ $? -ne 0 ]; then
        log_info "Instalación estándar falló. Intentando --force-depends..."
        opkg install "$KILL_PKG" --force-depends
        if [ $? -ne 0 ]; then
             log_error "Fallo crítico al instalar KillExteplayer. El paquete podría estar corrupto o ser incompatible."
        fi
    else
        log_info "KillExteplayer instalado correctamente."
    fi
    rm -f "$KILL_PKG"
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
    read -p "¿Desea configurar WireGuard ahora? (s/n): " CONFIGURE_WG
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
                # Habilitar servicio
                log_info "Habilitando servicio wg-quick@wg0..."
                if command -v systemctl >/dev/null 2>&1; then
                    systemctl enable wg-quick@wg0
                    systemctl start wg-quick@wg0
                else
                    log_info "Systemctl no encontrado, intentando inicio manual..."
                    wg-quick up wg0
                fi
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
# 9. FINALIZAR
# ------------------------------------------------------------------------------
log_info "Instalación completada. El sistema se reiniciará en 5 segundos."
sleep 5
reboot
