import qs.components.containers
import Quickshell
import Quickshell.Wayland
import QtQuick

StyledWindow {
    id: root

    required property int cornerSize
    required property real cx
    required property real cy

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    implicitWidth: cornerSize
    implicitHeight: cornerSize

    // Pass all input through — purely visual
    mask: Region {}

    Canvas {
        anchors.fill: parent
        onPaint: {
            const s = root.cornerSize;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, s, s);

            // Fill the square black
            ctx.fillStyle = "black";
            ctx.fillRect(0, 0, s, s);

            // Cut out the quarter-circle
            ctx.globalCompositeOperation = "destination-out";
            ctx.beginPath();
            ctx.arc(root.cx * s, root.cy * s, s, 0, Math.PI * 2);
            ctx.fill();
        }
    }
}
