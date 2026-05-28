import qs.components
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import QtQuick

StyledRect {
    id: root

    implicitWidth: Config.bar.sizes.innerWidth
    implicitHeight: Config.bar.sizes.innerWidth
    radius: Appearance.rounding.full
    color: Colours.tPalette.m3surfaceContainerLow

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const visibilities = Visibilities.getForActive();
            visibilities.launcher = !visibilities.launcher;
        }
    }

    ColouredIcon {
        anchors.centerIn: parent
        source: SysInfo.osLogo
        implicitSize: Appearance.font.size.large * 1.35
        colour: Colours.palette.m3tertiary
    }
}
