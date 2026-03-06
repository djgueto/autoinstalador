#!/bin/sh
#
# Kill Exteplayer on Standby - Instalador Automático
# Version: 1.0
# Author: Rafael
# Description: Plugin que mata exteplayer3 en standby y reinicia el canal al despertar
#

clear
echo "========================================="
echo " Kill Exteplayer Plugin - Instalador"
echo " Version: 1.0"
echo "========================================="
echo ""

# Crear estructura de directorios
echo "[1/5] Creando estructura de directorios..."
mkdir -p /usr/lib/enigma2/python/Plugins/Extensions/KillExteplayer

# Crear __init__.py
echo "[2/5] Creando archivos del plugin..."
cat > /usr/lib/enigma2/python/Plugins/Extensions/KillExteplayer/__init__.py << 'EOF'
# Plugin marker
EOF

# Crear plugin.py
cat > /usr/lib/enigma2/python/Plugins/Extensions/KillExteplayer/plugin.py << 'EOF'
from Plugins.Plugin import PluginDescriptor
from Screens.Standby import Standby, inStandby
from Components.config import config
from enigma import eTimer
import os

session_instance = None
saved_service_ref = None
wakeup_timer = None

def killExteplayer():
    """Mata todos los procesos exteplayer3"""
    os.system("killall -9 exteplayer3 2>/dev/null")
    os.system("echo '$(date) - [PLUGIN] Standby - exteplayer3 killed' >> /tmp/exteplayer_standby.log")

def checkAndRestart():
    """Verifica si salió de standby y reinicia el canal"""
    global session_instance, saved_service_ref, wakeup_timer
    
    # Verificar si NO está en standby
    if not inStandby:
        if session_instance and saved_service_ref:
            try:
                os.system("echo '$(date) - [PLUGIN] Wakeup confirmado - Reiniciando canal' >> /tmp/exteplayer_standby.log")
                # Forzar parada del servicio actual
                session_instance.nav.stopService()
                # Esperar un poco más antes de reiniciar
                from enigma import eTimer
                restart_timer = eTimer()
                restart_timer.callback.append(lambda: session_instance.nav.playService(saved_service_ref))
                restart_timer.start(2000, True)  # 2 segundos de espera
            except Exception as e:
                os.system("echo '$(date) - [PLUGIN] Error reiniciando: %s' >> /tmp/exteplayer_standby.log" % str(e))
        
        # Detener el timer de monitoreo
        if wakeup_timer:
            wakeup_timer.stop()

original_standby_init = None

def new_standby_init(self, session):
    """Hook al ENTRAR en standby"""
    global session_instance, saved_service_ref, wakeup_timer
    session_instance = session
    
    # Guardar referencia del servicio actual ANTES de matar exteplayer
    try:
        ref = session.nav.getCurrentlyPlayingServiceReference()
        if ref and not ref.toString().startswith("1:0:0:0:0:0:0:0:0:0:"):
            saved_service_ref = ref
            os.system("echo '$(date) - [PLUGIN] Servicio guardado: %s' >> /tmp/exteplayer_standby.log" % ref.toString())
        else:
            saved_service_ref = None
    except Exception as e:
        saved_service_ref = None
        os.system("echo '$(date) - [PLUGIN] No hay servicio para guardar: %s' >> /tmp/exteplayer_standby.log" % str(e))
    
    # Matar exteplayer3
    killExteplayer()
    
    # Iniciar timer para detectar wakeup (verifica cada 2 segundos)
    wakeup_timer = eTimer()
    wakeup_timer.callback.append(checkAndRestart)
    wakeup_timer.start(2000, False)  # Repetir cada 2 segundos
    
    # Llamar al init original
    original_standby_init(self, session)

def autostart(reason, session=None, **kwargs):
    """Se ejecuta al iniciar Enigma2"""
    if reason == 0:  # Startup
        global original_standby_init, session_instance
        session_instance = session
        
        # Hook para entrar en standby
        original_standby_init = Standby.__init__
        Standby.__init__ = new_standby_init

def Plugins(**kwargs):
    return [
        PluginDescriptor(
            name="Kill Exteplayer on Standby",
            description="Mata exteplayer3 en standby y reinicia canal automáticamente",
            where=PluginDescriptor.WHERE_SESSIONSTART,
            fnc=autostart
        )
    ]
EOF

# Compilar archivos Python
echo "[3/5] Compilando archivos Python..."
cd /usr/lib/enigma2/python/Plugins/Extensions/KillExteplayer
python -m py_compile __init__.py 2>/dev/null
python -m py_compile plugin.py 2>/dev/null

# Verificar instalación
echo "[4/5] Verificando instalación..."
if [ -f "/usr/lib/enigma2/python/Plugins/Extensions/KillExteplayer/plugin.py" ]; then
    echo "[5/5] ✓ Plugin instalado correctamente"
    echo ""
    echo "========================================="
    echo "✓ Instalación completada exitosamente"
    echo "========================================="
    echo ""
    echo "Archivos instalados:"
    ls -lh /usr/lib/enigma2/python/Plugins/Extensions/KillExteplayer/
    echo ""
    echo "Características del plugin:"
    echo "  • Mata exteplayer3 al entrar en standby"
    echo "  • Reinicia el canal automáticamente al despertar"
    echo "  • Log: /tmp/exteplayer_standby.log"
    echo ""
    echo "========================================="
    echo "IMPORTANTE: Reinicia Enigma2 ahora"
    echo "========================================="
    echo ""
    echo "Ejecuta: init 4 && sleep 3 && init 3"
    echo ""
    exit 0
else
    echo "[5/5] ✗ ERROR: Falló la instalación"
    exit 1
fi