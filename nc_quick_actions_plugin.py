from Plugins.Plugin import PluginDescriptor
from Screens.MessageBox import MessageBox
import os

UPDATE_COMMAND = "/bin/sh -c '(/usr/script/downloadLoT.sh && /usr/script/downloadLdC.sh) >/tmp/nc_update_channels.log 2>&1 &'"
VPN_COMMAND = "/bin/sh -c '(/usr/script/reconnectVPN.sh) >/tmp/nc_reconnect_vpn.log 2>&1 &'"


def run_command(command):
    os.system(command)


def update_channels(session, **kwargs):
    run_command(UPDATE_COMMAND)
    session.open(
        MessageBox,
        "Actualizacion de canales iniciada.\nSe ejecutaran downloadLoT.sh y downloadLdC.sh.",
        MessageBox.TYPE_INFO,
        timeout=6
    )


def reconnect_vpn(session, **kwargs):
    run_command(VPN_COMMAND)
    session.open(
        MessageBox,
        "Reconexión de VPN iniciada.\nSe reiniciará WireGuard y se forzará la vuelta al canal actual.",
        MessageBox.TYPE_INFO,
        timeout=6
    )


def Plugins(**kwargs):
    locations = [PluginDescriptor.WHERE_EXTENSIONSMENU, PluginDescriptor.WHERE_PLUGINMENU]
    return [
        PluginDescriptor(
            name="Actualizar canales",
            description="Ejecuta la actualizacion de picons y canales",
            where=locations,
            fnc=update_channels
        ),
        PluginDescriptor(
            name="Reconectar VPN",
            description="Reinicia la VPN WireGuard",
            where=locations,
            fnc=reconnect_vpn
        )
    ]
