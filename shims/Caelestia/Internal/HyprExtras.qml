import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var options: ({})
    property HyprDevices devices: HyprDevices {}

    // -- public methods --

    function message(msg) {
        msgProc.command = ["hyprctl", "dispatch", "--", msg];
        msgProc.running = true;
    }

    function batchMessage(messages) {
        var joined = messages.join(";");
        batchProc.command = [
            "hyprctl", "--batch", joined
        ];
        batchProc.running = true;
    }

    function applyOptions(opts) {
        var parts = [];
        var keys = Object.keys(opts);
        for (var i = 0; i < keys.length; i++) {
            parts.push("keyword " + keys[i] + " " + opts[keys[i]]);
        }
        if (parts.length === 0) return;

        applyProc.command = [
            "hyprctl", "--batch", parts.join(";")
        ];
        applyProc.running = true;
    }

    function refreshOptions() {
        optProc.running = true;
    }

    function refreshDevices() {
        devProc.running = true;
    }

    // -- internal processes --

    property Process msgProc: Process {
        command: ["true"]
    }

    property Process batchProc: Process {
        command: ["true"]
    }

    property Process applyProc: Process {
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: root.refreshOptions()
        }
    }

    property Process optProc: Process {
        command: ["hyprctl", "-j", "descriptions"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    var result = {};
                    for (var i = 0; i < parsed.length; i++) {
                        var item = parsed[i];
                        if (item.name) {
                            result[item.name] = item.value;
                        }
                    }
                    root.options = result;
                } catch (e) {
                    console.warn(
                        "HyprExtras: failed to parse options:", e
                    );
                }
            }
        }
    }

    property Process devProc: Process {
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    root.devices.updateLastIpcObject(parsed);
                } catch (e) {
                    console.warn(
                        "HyprExtras: failed to parse devices:", e
                    );
                }
            }
        }
    }

    Component.onCompleted: {
        refreshOptions();
        refreshDevices();
    }
}
