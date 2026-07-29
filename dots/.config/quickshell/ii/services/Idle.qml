pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
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

    // Unplugging a monitor destroys the inhibitor surface and it does not come back on its own,
    // leaving the toggle showing as on while nothing is inhibited. Rearm on any screen change.
    // The disable and the enable must land in separate ticks or the property system collapses
    // them and the surface is never torn down.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.inhibit) {
                idleInhibitor.enabled = false;
                rearmTimer.restart();
            }
        }
    }

    Timer {
        id: rearmTimer
        interval: 500
        repeat: false
        onTriggered: idleInhibitor.enabled = true
    }

    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
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
