pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed
    property bool needsStart
    property list<string> startArgs
    property bool needsStop
    property bool needsPause

    function start(extraArgs = []): void {
        needsStart = true;
        startArgs = extraArgs;
        checkProc.running = true;
    }

    function stop(): void {
        needsStop = true;
        checkProc.running = true;
    }

    function togglePause(): void {
        needsPause = true;
        checkProc.running = true;
    }

    function buildRecordCommand(args): list<string> {
        const hasRegion = args.includes("-r")
            || args.includes("-sr");
        const hasSound = args.includes("-s")
            || args.includes("-sr");

        const recsdir = Paths.recsdir;
        const ts = Qt.formatDateTime(
            new Date(), "yyyy-MM-dd_hh-mm-ss"
        );
        const filename = `${recsdir}/recording_${ts}.mp4`;

        let cmd = ["gpu-screen-recorder"];

        if (hasRegion)
            cmd.push("-w", "region");
        else
            cmd.push("-w", "screen");

        if (hasSound)
            cmd.push("-a", "default_output");

        cmd.push("-f", "60", "-o", filename);
        return cmd;
    }

    PersistentProperties {
        id: props

        property bool running: false
        property bool paused: false
        property real elapsed: 0

        reloadableId: "recorder"
    }

    Process {
        id: mkdirProc

        command: ["mkdir", "-p", Paths.recsdir]
    }

    Process {
        id: checkProc

        running: true
        command: ["pidof", "gpu-screen-recorder"]
        onExited: code => {
            props.running = code === 0;

            if (code === 0) {
                if (root.needsStop) {
                    Quickshell.execDetached(
                        ["killall", "-SIGINT",
                            "gpu-screen-recorder"]
                    );
                    props.running = false;
                    props.paused = false;
                } else if (root.needsPause) {
                    Quickshell.execDetached(
                        ["killall", "-SIGUSR1",
                            "gpu-screen-recorder"]
                    );
                    props.paused = !props.paused;
                }
            } else if (root.needsStart) {
                mkdirProc.running = true;
                const cmd = root.buildRecordCommand(
                    root.startArgs
                );
                Quickshell.execDetached(cmd);
                props.running = true;
                props.paused = false;
                props.elapsed = 0;
            }

            root.needsStart = false;
            root.needsStop = false;
            root.needsPause = false;
        }
    }

    Connections {
        target: Time

        function onSecondsChanged(): void {
            props.elapsed++;
        }
    }
}
