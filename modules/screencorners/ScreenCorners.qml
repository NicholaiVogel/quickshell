pragma ComponentBehavior: Bound

import qs.components.containers
import Quickshell
import Quickshell.Wayland
import QtQuick

// One scope per screen, four windows per scope (one per corner).
// Variants handles per-screen instantiation; the four corners are
// explicit because Repeater can't create top-level windows.
Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        // Size of the corner arc in pixels
        readonly property int cornerSize: 25

        ScreenCorner {
            screen: scope.modelData
            cornerSize: scope.cornerSize
            name: "screen-corner-tl"
            anchors.top: true
            anchors.bottom: false
            anchors.left: true
            anchors.right: false
            cx: 1.0
            cy: 1.0
        }

        ScreenCorner {
            screen: scope.modelData
            cornerSize: scope.cornerSize
            name: "screen-corner-tr"
            anchors.top: true
            anchors.bottom: false
            anchors.left: false
            anchors.right: true
            cx: 0.0
            cy: 1.0
        }

        ScreenCorner {
            screen: scope.modelData
            cornerSize: scope.cornerSize
            name: "screen-corner-bl"
            anchors.top: false
            anchors.bottom: true
            anchors.left: true
            anchors.right: false
            cx: 1.0
            cy: 0.0
        }

        ScreenCorner {
            screen: scope.modelData
            cornerSize: scope.cornerSize
            name: "screen-corner-br"
            anchors.top: false
            anchors.bottom: true
            anchors.left: false
            anchors.right: true
            cx: 0.0
            cy: 0.0
        }
    }
}
