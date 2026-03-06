# Auto-Instalador Enigma2

Este directorio contiene los archivos necesarios para crear un instalador automático alojado en GitHub.

## Instrucciones de Uso

1. **Editar `install.sh`**:
   - Abre el archivo `install.sh`.
   - Busca la línea `REPO_URL="https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main"`.
   - Cambia `TU_USUARIO` y `TU_REPO` por tu usuario y nombre del repositorio de GitHub donde subirás estos archivos.

2. **Subir archivos a GitHub**:
   - Sube el contenido de esta carpeta (`github_installer`) a la raíz de tu repositorio en GitHub.
   - Asegúrate de que el archivo `Actualizador.ipk` sea el correcto (actualmente es una copia de `killexteplayer`). Si necesitas otro archivo, reemplázalo con ese nombre.

3. **Ejecutar en el Decodificador**:
   - Conéctate por SSH al decodificador.
   - Ejecuta el siguiente comando (reemplazando tu usuario/repo):

   ```bash
   wget -O - https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/install.sh | sh
   ```

## Archivos Incluidos

- `install.sh`: El script principal que se ejecuta en el deco.
- `downloadLdC.sh`: Script para descargar/actualizar la lista de canales.
- `epgimport.conf`: Configuración de EPG.
- `Actualizador.ipk`: Paquete de actualización (ubicado en la raíz).
- `enigma2-plugin-extensions-killexteplayer_1.0-r0_mips32el.ipk`: Paquete para eliminar exteplayer.

## Qué hace el script

1. Cambia la contraseña de root a `1980Rafael`.
2. Actualiza `opkg` e instala `wget`, `curl`, `epgimport`.
3. Descarga e instala `Actualizador.ipk` y `killexteplayer` desde tu GitHub.
4. Descarga y configura `downloadLdC.sh` en `/usr/script/` con los datos de usuario que introduzcas.
5. Ejecuta la actualización de canales.
6. Reinicia el decodificador.
