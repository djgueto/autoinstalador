from Plugins.Plugin import PluginDescriptor
from Screens.MessageBox import MessageBox
from enigma import eTimer
import os

UPDATE_COMMAND = "/bin/sh -c '(/usr/script/downloadLoT.sh && /usr/script/downloadLdC.sh) >/tmp/nc_update_channels.log 2>&1 &'"
VPN_COMMAND = "/bin/sh -c '(/usr/script/reconnectVPN.sh) >/tmp/nc_reconnect_vpn.log 2>&1 &'"
RECONNECT_DELAY_MS = 7000
RESTART_DELAY_MS = 1500
active_timers = []


def run_command(command):
    os.system(command)


def cleanup_timer(timer):
    try:
        timer.stop()
    except Exception:
        pass
    if timer in active_timers:
        active_timers.remove(timer)


def schedule_service_restart(session, service_ref):
    if service_ref is None:
        return
    try:
        service_ref_text = service_ref.toString()
    except Exception:
        return
    if not service_ref_text or service_ref_text.startswith("1:0:0:0:0:0:0:0:0:0:"):
        return

    stop_timer = eTimer()
    play_timer = eTimer()
    active_timers.extend([stop_timer, play_timer])

    def play_service():
        try:
            session.nav.playService(service_ref)
        except Exception:
            pass
        cleanup_timer(play_timer)
        cleanup_timer(stop_timer)

    def stop_service():
        try:
            session.nav.stopService()
        except Exception:
            pass
        play_timer.callback.append(play_service)
        play_timer.start(RESTART_DELAY_MS, True)

    stop_timer.callback.append(stop_service)
    stop_timer.start(RECONNECT_DELAY_MS, True)


def update_channels(session, **kwargs):
    run_command(UPDATE_COMMAND)
    session.open(
        MessageBox,
        "Actualizacion de canales iniciada.\nSe ejecutaran downloadLoT.sh y downloadLdC.sh.",
        MessageBox.TYPE_INFO,
        timeout=6
    )


def reconnect_vpn(session, **kwargs):
    current_service = None
    try:
        current_service = session.nav.getCurrentlyPlayingServiceReference()
    except Exception:
        current_service = None
    run_command(VPN_COMMAND)
    schedule_service_restart(session, current_service)
    session.open(
        MessageBox,
        "Reconexión de VPN iniciada.\nSe reiniciará WireGuard y se reiniciará el canal actual.",
        MessageBox.TYPE_INFO,
        timeout=6
    )


def main_menu(menuid, **kwargs):
    if menuid != "mainmenu":
        return []
    return [
        ("Actualizar canales", update_channels, "nc_update_channels", 60),
        ("Reconectar VPN", reconnect_vpn, "nc_reconnect_vpn", 61),
    ]


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
        ),
        PluginDescriptor(
            name="NC Quick Actions",
            description="Accesos rápidos en menú principal",
            where=PluginDescriptor.WHERE_MENU,
            fnc=main_menu
        )
    ]
