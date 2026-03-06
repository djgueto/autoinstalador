#!/bin/bash

# ========================================
# CONFIGURACION DEL CLIENTE
# ========================================
CLIENT_USER=""
CLIENT_PASS=""
SERVICE_TYPE=""
NEW_TVHEADEND_IP="10.8.0.113"
NEW_TVHEADEND_PORT="9981"

# Valores a reemplazar del GitHub (URL-encoded)
# OLD_USER y OLD_IP ya no son necesarios porque se hace un reemplazo genérico

# ========================================
# LIMPIEZA Y DESCARGA
# ========================================
rm -f /etc/enigma2/master.zip
rm -rf /etc/enigma2/ListaDeCanales-master/

cd /etc/enigma2/

echo "Descargando lista de canales..."
wget --no-check-certificate https://github.com/djgueto/ListaDeCanales/archive/master.zip
unzip -q master.zip

# ========================================
# MODIFICAR ARCHIVOS (URL-ENCODED)
# ========================================
echo "Personalizando URLs para: $CLIENT_USER"

# El formato en Enigma2 es: http%3a//usuario%3apassword@ip%3apuerto/...
# Donde %3a es el : codificado

for file in ListaDeCanales-master/*.tv ListaDeCanales-master/*.tv_org; do
    if [ -f "$file" ]; then
        echo "  Procesando: $(basename $file)"
        
        # Reemplazar usuario y password (genérico: todo entre http%3a// y @)
        # Esto funciona independientemente de las credenciales originales en el repo
        sed -i "s|http%3a//[^@]*@|http%3a//${CLIENT_USER}%3a${CLIENT_PASS}@|g" "$file"
        
        # Reemplazar IP y puerto (genérico: todo IP:PUERTO después de @)
        # Esto funciona independientemente de la IP original en el repo
        sed -i "s|@[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*%3a[0-9]*|@${NEW_TVHEADEND_IP}%3a${NEW_TVHEADEND_PORT}|g" "$file"
        
        # Reemplazar tipo de servicio (4097=gstreamer, 5001=gstplayer, 5002=exteplayer3)
        if [ ! -z "$SERVICE_TYPE" ]; then
            sed -i "s|#SERVICE 4097:|#SERVICE ${SERVICE_TYPE}:|g" "$file"
            sed -i "s|#SERVICE 5001:|#SERVICE ${SERVICE_TYPE}:|g" "$file"
            sed -i "s|#SERVICE 5002:|#SERVICE ${SERVICE_TYPE}:|g" "$file"
        fi
    fi
done

# ========================================
# VERIFICAR CAMBIOS
# ========================================
echo ""
echo "Verificando URLs modificadas:"
grep "http%3a" ListaDeCanales-master/*.tv 2>/dev/null | head -3

# ========================================
# COPIAR ARCHIVOS MODIFICADOS
# ========================================
echo ""
echo "Copiando archivos modificados..."
cp ListaDeCanales-master/*.tv /etc/enigma2/ 2>/dev/null
cp ListaDeCanales-master/*.tv_org /etc/enigma2/ 2>/dev/null
cp ListaDeCanales-master/lamedb /etc/enigma2/ 2>/dev/null

# ========================================
# LIMPIEZA
# ========================================
rm -f master.zip
rm -rf ListaDeCanales-master/

# ========================================
# RECARGAR ENIGMA2
# ========================================
echo ""
echo "Recargando Enigma2..."
wget -q -O - http://127.0.0.1/web/servicelistreload?mode=0
sleep 2
wget -q -O - http://127.0.0.1/web/powerstate?newstate=3

echo ""
echo "========================================"
echo "COMPLETADO"
echo "========================================"
echo "Usuario: $CLIENT_USER"
echo "Password: $CLIENT_PASS"
echo "IP TVHeadend: $NEW_TVHEADEND_IP:$NEW_TVHEADEND_PORT"
echo "========================================"