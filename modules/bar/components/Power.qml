import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

StyledRect {
    id: root

    required property PersistentProperties visibilities

    implicitWidth: Config.bar.sizes.innerWidth
    implicitHeight: Config.bar.sizes.innerWidth
    radius: Appearance.rounding.full
    color: Colours.tPalette.m3surfaceContainerLow
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3error, 0.35)

    StateLayer {
        anchors.fill: parent
        radius: Appearance.rounding.full

        function onClicked(): void {
            root.visibilities.session = !root.visibilities.session;
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -1

        text: "power_settings_new"
        color: Colours.palette.m3error
        font.bold: true
        font.pointSize: Appearance.font.size.larger
    }
}
