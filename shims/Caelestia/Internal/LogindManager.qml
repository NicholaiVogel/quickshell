import QtQuick
import Quickshell.Io

QtObject {
    id: root

    signal aboutToSleep()
    signal resumed()
    signal lockRequested()
    signal unlockRequested()

    // monitor login1 manager signals (PrepareForSleep)
    property Process _managerMonitor: Process {
        running: true
        command: [
            "gdbus", "monitor", "-y",
            "-d", "org.freedesktop.login1",
            "-o", "/org/freedesktop/login1"
        ]
        stdout: SplitParser {
            onRead: data => root._parseManagerSignal(data)
        }
        onRunningChanged: {
            if (!running) running = true;
        }
    }

    // get session path then monitor it for Lock/Unlock
    property string _sessionPath: ""

    property Process _sessionLookup: Process {
        running: true
        command: [
            "sh", "-c",
            "loginctl show-session auto "
            + "-p Id --value 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var sid = this.text.trim();
                if (sid !== "") {
                    root._sessionPath =
                        "/org/freedesktop/login1/session/"
                        + sid.replace(/-/g, "_");
                    root._sessionMonitor.command = [
                        "gdbus", "monitor", "-y",
                        "-d", "org.freedesktop.login1",
                        "-o", root._sessionPath
                    ];
                    root._sessionMonitor.running = true;
                } else {
                    // fallback: try "auto" path
                    root._sessionPath =
                        "/org/freedesktop/login1/session/auto";
                    root._sessionMonitor.command = [
                        "gdbus", "monitor", "-y",
                        "-d", "org.freedesktop.login1",
                        "-o", root._sessionPath
                    ];
                    root._sessionMonitor.running = true;
                }
            }
        }
    }

    property Process _sessionMonitor: Process {
        running: false
        command: ["true"]
        stdout: SplitParser {
            onRead: data => root._parseSessionSignal(data)
        }
        onRunningChanged: {
            if (!running && root._sessionPath !== "") {
                running = true;
            }
        }
    }

    property bool _sawPrepare: false

    function _parseManagerSignal(line) {
        // gdbus output format:
        //   .PrepareForSleep (true,)
        // or sometimes split across lines:
        //   .PrepareForSleep
        //   (true,)
        if (line.indexOf("PrepareForSleep") !== -1) {
            if (line.indexOf("true") !== -1) {
                root.aboutToSleep();
                _sawPrepare = false;
            } else if (line.indexOf("false") !== -1) {
                root.resumed();
                _sawPrepare = false;
            } else {
                _sawPrepare = true;
            }
            return;
        }
        if (_sawPrepare) {
            if (line.indexOf("true") !== -1) {
                root.aboutToSleep();
            } else if (line.indexOf("false") !== -1) {
                root.resumed();
            }
            _sawPrepare = false;
        }
    }

    function _parseSessionSignal(line) {
        if (line.indexOf(".Lock") !== -1
            && line.indexOf(".Unlock") === -1) {
            root.lockRequested();
        } else if (line.indexOf(".Unlock") !== -1) {
            root.unlockRequested();
        }
    }
}
