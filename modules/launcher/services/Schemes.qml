pragma Singleton

import ".."
import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
    id: root

    property string currentScheme
    property string currentVariant

    function transformSearch(search: string): string {
        return search.slice(`${Config.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return `${item.name} ${item.flavour}`;
    }

    function reload(): void {
        // Stubbed: pywal doesn't need reload
    }

    list: schemes.instances
    useFuzzy: Config.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes

        Scheme {}
    }

    // Stubbed: pywal manages schemes, no scheme switching
    QtObject {
        id: getSchemes

        Component.onCompleted: {
            // Return static pywal "scheme" with dummy colour values
            // so SchemeItem preview doesn't break
            schemes.model = [{
                name: "pywal",
                flavour: "dark",
                colours: {
                    surface: "1c1b22",
                    outline: "938f99",
                    primary: "d0bcff"
                }
            }];
        }
    }

    // Stubbed: pywal manages schemes
    QtObject {
        id: getCurrent

        Component.onCompleted: {
            root.currentScheme = "pywal dark";
            root.currentVariant = "tonalspot";
        }
    }

    component Scheme: QtObject {
        required property var modelData
        readonly property string name: modelData.name
        readonly property string flavour: modelData.flavour
        readonly property var colours: modelData.colours

        function onClicked(list: AppList): void {
            // Stubbed: pywal manages schemes, no-op
            list.visibilities.launcher = false;
        }
    }
}
