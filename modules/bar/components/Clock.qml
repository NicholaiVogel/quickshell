pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    property color colour: Colours.palette.m3tertiary

    implicitWidth: Config.bar.sizes.innerWidth
    implicitHeight: content.implicitHeight + Appearance.padding.normal * 2
    radius: Appearance.rounding.full
    color: Colours.tPalette.m3surfaceContainerLow

    Column {
        id: content

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter

            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
                font.pointSize: Appearance.font.size.large
            }
        }

        StyledText {
            id: text

            anchors.horizontalCenter: parent.horizontalCenter

            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format(Config.services.useTwelveHourClock ? "hh\nmm\nA" : "hh\nmm")
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
        }
    }
}
