pragma Singleton

import ".."
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

Searcher {
    id: root

    function transformSearch(search: string): string {
        return search.slice(Config.launcher.actionPrefix.length);
    }

    list: variants.instances
    useFuzzy: Config.launcher.useFuzzy.actions

    Variants {
        id: variants

        model: Config.launcher.actions.filter(a => (a.enabled ?? true) && (Config.launcher.enableDangerousActions || !(a.dangerous ?? false)))

        Action {}
    }

    component Action: QtObject {
        required property var modelData
        readonly property string name: modelData.name ?? qsTr("Unnamed")
        readonly property string desc: modelData.description ?? qsTr("No description")
        readonly property string icon: modelData.icon ?? "help_outline"
        readonly property list<string> command: modelData.command ?? []
        readonly property bool enabled: modelData.enabled ?? true
        readonly property bool dangerous: modelData.dangerous ?? false

        function onClicked(list: AppList): void {
            if (command.length === 0)
                return;

            if (command[0] === "autocomplete" && command.length > 1) {
                list.search.text = `${Config.launcher.actionPrefix}${command[1]} `;
            } else if (command[0] === "setMode" && command.length > 1) {
                list.visibilities.launcher = false;
                Colours.setMode(command[1]);
            } else if (command[0] === "randomWallpaper") {
                list.visibilities.launcher = false;
                const wallpapers = Wallpapers.list;
                if (wallpapers.length > 0) {
                    const randomIndex = Math.floor(Math.random() * wallpapers.length);
                    Wallpapers.setWallpaper(wallpapers[randomIndex].path);
                }
            } else if (command[0] === "openControlCenter") {
                list.visibilities.launcher = false;
                list.visibilities.controlcenter = true;
            } else {
                list.visibilities.launcher = false;
                Quickshell.execDetached(command);
            }
        }
    }
}
