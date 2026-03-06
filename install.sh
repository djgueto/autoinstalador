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
# 1. CAMBIAR CONTRASEÑA ROOT
# ------------------------------------------------------------------------------
log_info "Cambiando contraseña de root a '1980Rafael'..."
echo -e "1980Rafael\n1980Rafael" | passwd root
if [ $? -eq 0 ]; then
    log_info "Contraseña cambiada correctamente."
else
    log_error "Fallo al cambiar la contraseña."
fi

# ------------------------------------------------------------------------------
# 2. ACTUALIZAR PAQUETES E INSTALAR DEPENDENCIAS
# ------------------------------------------------------------------------------
log_info "Actualizando lista de paquetes (opkg update)..."
opkg update

log_info "Instalando wget y curl..."
opkg install wget curl

# ------------------------------------------------------------------------------
# 3. INSTALAR EPG IMPORT
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
# 4. INSTALAR ACTUALIZADOR Y KILLEXTEPLAYER
# ------------------------------------------------------------------------------
log_info "Instalando Actualizador y KillExteplayer..."

# Descargar e instalar Actualizador.ipk
log_info "Procesando Actualizador.ipk..."
wget --no-check-certificate "$REPO_URL/Actualizador.ipk" -O /tmp/Actualizador.ipk
if [ -f /tmp/Actualizador.ipk ]; then
    opkg install /tmp/Actualizador.ipk
    if [ $? -eq 0 ]; then
        log_info "Actualizador instalado correctamente."
    else
        log_error "Error al instalar Actualizador.ipk"
    fi
    rm -f /tmp/Actualizador.ipk
else
    log_error "No se pudo descargar Actualizador.ipk. Verifica la URL del repo."
fi

# Descargar e instalar enigma2-plugin-extensions-killexteplayer
log_info "Procesando KillExteplayer..."
KILL_PKG="enigma2-plugin-extensions-killexteplayer_1.0-r0_mips32el.ipk"
wget --no-check-certificate "$REPO_URL/$KILL_PKG" -O "/tmp/$KILL_PKG"

if [ -f "/tmp/$KILL_PKG" ]; then
    opkg install "/tmp/$KILL_PKG"
    if [ $? -eq 0 ]; then
        log_info "KillExteplayer instalado correctamente."
    else
        log_error "Error al instalar KillExteplayer."
    fi
    rm -f "/tmp/$KILL_PKG"
else
    log_error "No se pudo descargar $KILL_PKG. Verifica la URL del repo."
fi

# ------------------------------------------------------------------------------
# 5. CONFIGURAR SCRIPT DE CANALES (downloadLdC.sh)
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
# 6. FINALIZAR
# ------------------------------------------------------------------------------
log_info "Instalación completada. El sistema se reiniciará en 5 segundos."
sleep 5
reboot
