pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled
    inhibit: false

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (!Persistent.isNewHyprlandInstance) {
                root.inhibit = Persistent.states.idle.inhibit;
            } else {
                Persistent.states.idle.inhibit = root.inhibit;
            }
        }
    }

    function toggleInhibit(active = null) {
        if (active !== null) {
            root.inhibit = active;
        } else {
            root.inhibit = !root.inhibit;
        }
        Persistent.states.idle.inhibit = root.inhibit;
    }

    // Hyprland ignores idle inhibitors that sit on a layer surface (hyprwm/Hyprland#5878), and every
    // Quickshell window is one, so the Wayland inhibitor below never reaches hypridle. A systemd idle
    // block does, and hypridle honours it as long as ignore_systemd_inhibit stays off.
    // The helper blocks on stdin so it dies on EOF when Quickshell goes away. Left as a bare sleep it
    // survives Quickshell being killed and keeps the screen awake until the block is hunted down.
    Process {
        running: root.inhibit
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=idle", "--who=Quickshell", "--why=Idle inhibitor", "--mode=block", "sh", "-c", "read -r _"]
    }

    // Unplugging a monitor destroys the screen the inhibitor window sits on. The screen binding
    // below does re-resolve to a live screen on its own, but Quickshell drops the window to
    // visible false and never brings it back, so the inhibitor stays attached to a surface that
    // no longer exists and nothing is inhibited while the toggle still reads as on.
    // Restoring visibility recreates the surface. Delayed so the screen binding settles first.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            rearmTimer.restart();
        }
    }

    Timer {
        id: rearmTimer
        interval: 500
        repeat: false
        onTriggered: inhibitorWindow.visible = true
    }

    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            id: inhibitorWindow
            // Inhibitor requires a "visible" surface
            // Actually not lol
            // Bind to a live screen so the surface is recreated after a monitor is unplugged
            screen: Quickshell.screens[0] ?? null
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            // Just in case...
            anchors {
                right: true
                bottom: true
            }
            // Make it not interactable
            mask: Region {
                item: null
            }
        }
    }
}
