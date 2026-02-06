Below is a “from zero to usable bar” QuickShell guide that stitches together:

* Tony’s walkthrough (your transcript) 
* Tony’s written tutorial version ([tonybtw.com][1])
* Official docs (install + API/type docs) ([quickshell.org][2])
* DeepWiki’s repo-level “getting started” notes (paths, pragmas, runtime dirs) ([DeepWiki][3])

---

## What QuickShell is (and why it’s fun)

QuickShell (often written “Quickshell”) is a Qt/QML-based toolkit for building Wayland desktop UI like bars, widgets, overlays, lock screens, etc. Tony frames it as a practical Waybar replacement for Hyprland, with Sway support (API differs a bit).  ([tonybtw.com][1])

The core mental model:

* You write QML (declarative UI). ([quickshell.outfoxxed.me][4])
* Your UI “binds” to live data (Hyprland IPC objects, timers, process output).
* Most widgets are: **run something** → **parse output** → **update properties** → **render Text/Rectangles**. Tony calls this pattern out explicitly. 

---

## Install (Arch, NixOS, source)

### NixOS

Tony just adds `quickshell` to system packages. ([tonybtw.com][1])

### Arch Linux

Tony’s tutorial uses the AUR `quickshell-git` package: ([tonybtw.com][1]) ([AUR][5])

```bash
yay -S quickshell-git
```

### Official install guide (recommended read)

The official install/setup guide also covers release vs master tracking and editor setup. ([quickshell.org][2])

### Source build (when you need it)

DeepWiki documents build requirements and feature flags (Wayland/Hyprland integrations are feature-gated). ([DeepWiki][3])
If you’re on Arch and you update Qt, you may need to rebuild the AUR package (a common “built against old Qt” footgun). ([GitHub][6])

---

## Editor setup (do this early, it pays off)

The official install/setup page explicitly recommends a QML grammar + QML LSP (`qmlls`) setup. ([quickshell.org][2])
This makes QML feel less like wizard runes and more like a normal language (autocomplete, jump-to-definition, type info).

---

## Where config lives (and how `qs` finds it)

QuickShell’s typical entrypoint is `shell.qml` under:

* `~/.config/quickshell/shell.qml` ([DeepWiki][3])

If you run `qs` with no config, Tony hits the expected error: “cannot find default config or shell.qml in any valid config path.” 

DeepWiki also notes that the config path is hashed to generate a unique shell identifier and that Quickshell builds a runtime directory tree under `XDG_RUNTIME_DIR` (instance management, IPC, etc.). ([DeepWiki][3])

---

## Running QuickShell

Basic:

```bash
qs
```

Running a specific file (handy for iterating through examples):

```bash
qs -p ~/.config/testshell/01-hello.qml
```

That `-p` pattern is exactly how Tony’s written tutorial suggests stepping through examples. ([tonybtw.com][1])

---

## Step 1 - Hello world (FloatingWindow)

Create the config directory + file:

```bash
mkdir -p ~/.config/quickshell
$EDITOR ~/.config/quickshell/shell.qml
```

Minimal QML:

```qml
import Quickshell
import QtQuick

FloatingWindow {
    visible: true
    width: 200
    height: 100

    Text {
        anchors.centerIn: parent
        text: "Hello, Quickshell!"
        font.pixelSize: 18
    }
}
```

This mirrors the tutorial’s baseline: `Quickshell` + `QtQuick`, with a floating window that doesn’t reserve screen space. ([tonybtw.com][1]) 

Run it:

```bash
qs
```

---

## Step 2 - A real bar (PanelWindow + Wayland)

To dock to the top edge (and reserve space), switch to `PanelWindow` and import Wayland types:

```qml
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 30

    color: "#1a1b26"

    Text {
        anchors.centerIn: parent
        text: "My First Bar"
        color: "#a9b1d6"
        font.pixelSize: 14
    }
}
```

Key idea: `PanelWindow` docks and reserves space, unlike `FloatingWindow`. ([tonybtw.com][1]) 

---

## Step 3 - Hyprland workspaces (clickable)

This is the “ok, now it replaces Waybar” moment.

You’ll add:

* `Quickshell.Hyprland` for IPC integration ([quickshell.outfoxxed.me][7])
* `QtQuick.Layouts` for `RowLayout` ([tonybtw.com][1])

Example:

```qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 30
    color: "#1a1b26"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Repeater {
            model: 9

            Text {
                // workspace IDs 1..9
                property int wsId: index + 1

                // live workspace object (null if empty/nonexistent)
                property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)

                // focused workspace
                property bool isActive: Hyprland.focusedWorkspace?.id === wsId

                text: wsId
                font.pixelSize: 14
                font.bold: true

                // color logic:
                // - cyan if active
                // - blue if it exists (has windows)
                // - muted if empty
                color: isActive ? "#0db9d7" : (ws ? "#7aa2f7" : "#444b6a")

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + wsId)
                }
            }
        }

        // spacer pushes workspace block left
        Item { Layout.fillWidth: true }
    }
}
```

Notes that matter in real configs:

* `Hyprland.dispatch(...)` executes Hyprland dispatchers. ([quickshell.outfoxxed.me][7])
* Hyprland workspaces include named workspaces with negative IDs (they sort before numbered ones), so if you get fancy later, account for that. ([quickshell.outfoxxed.me][7])
* Tony uses this same “Repeater + dispatch + color by focused/existing” approach.  ([tonybtw.com][1])

---

## Step 4 - Widgets via shell commands (Process + SplitParser + Timer)

This is the standard QuickShell widget pipeline:

* `Process` runs a command ([quickshell.outfoxxed.me][8])
* `SplitParser` reads stdout in chunks/lines ([quickshell.outfoxxed.me][9])
* A `Timer` re-runs it periodically ([tonybtw.com][1])
* Properties hold state (so UI can bind)

### Add shared theme + state properties

At the top of your `PanelWindow`:

```qml
PanelWindow {
    id: root

    // theme
    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colBlue: "#7aa2f7"
    property color colYellow: "#e0af68"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    // system state
    property int cpuUsage: 0
    property int memUsage: 0
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 30
    color: colBg

    // ...
}
```

This “define theme once on root, reuse everywhere” approach is straight from the tutorial. ([tonybtw.com][1])

---

## CPU widget (reads `/proc/stat`)

Tony’s example reads the first line of `/proc/stat` and computes CPU usage from deltas between samples. ([tonybtw.com][1])

```qml
import Quickshell.Io

Process {
    id: cpuProc
    command: ["sh", "-c", "head -1 /proc/stat"]

    stdout: SplitParser {
        onRead: data => {
            if (!data) return
            var p = data.trim().split(/\s+/)

            // idle = idle + iowait
            var idle = parseInt(p[4]) + parseInt(p[5])

            // total = user..softirq (slice(1,8))
            var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0)

            if (lastCpuTotal > 0) {
                cpuUsage = Math.round(100 * (1 - (idle - lastCpuIdle) / (total - lastCpuTotal)))
            }
            lastCpuTotal = total
            lastCpuIdle = idle
        }
    }

    Component.onCompleted: running = true
}
```

---

## Memory widget (uses `free`)

Tony’s memory widget runs `free | grep Mem` and turns used/total into a percent. ([tonybtw.com][1]) 

```qml
Process {
    id: memProc
    command: ["sh", "-c", "free | grep Mem"]

    stdout: SplitParser {
        onRead: data => {
            if (!data) return
            var parts = data.trim().split(/\s+/)
            var total = parseInt(parts[1]) || 1
            var used = parseInt(parts[2]) || 0
            memUsage = Math.round(100 * used / total)
        }
    }

    Component.onCompleted: running = true
}
```

---

## Timers (refresh the widgets)

```qml
Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
        cpuProc.running = true
        memProc.running = true
    }
}
```

This is exactly the “poll every N ms, rerun processes” pattern described in the tutorial. ([tonybtw.com][1]) 

---

## Clock widget (no shell command needed)

Tony uses `Qt.formatDateTime` and updates with a 1-second timer. ([tonybtw.com][1]) 

```qml
Text {
    id: clock
    text: Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
    color: root.colFg
    font.family: root.fontFamily
    font.pixelSize: root.fontSize

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
    }
}
```

---

## Put it together - a complete minimal bar (workspaces + mem + cpu + clock)

This is intentionally “single file, readable, and easy to extend”:

```qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    // theme
    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colBlue: "#7aa2f7"
    property color colYellow: "#e0af68"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    // state
    property int cpuUsage: 0
    property int memUsage: 0
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 30
    color: colBg

    // CPU
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var p = data.trim().split(/\s+/)
                var idle = parseInt(p[4]) + parseInt(p[5])
                var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0)
                if (lastCpuTotal > 0) {
                    cpuUsage = Math.round(100 * (1 - (idle - lastCpuIdle) / (total - lastCpuTotal)))
                }
                lastCpuTotal = total
                lastCpuIdle = idle
            }
        }
        Component.onCompleted: running = true
    }

    // MEM
    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var total = parseInt(parts[1]) || 1
                var used = parseInt(parts[2]) || 0
                memUsage = Math.round(100 * used / total)
            }
        }
        Component.onCompleted: running = true
    }

    // refresh both
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true
            memProc.running = true
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        // Workspaces (1..9)
        Repeater {
            model: 9
            Text {
                property int wsId: index + 1
                property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)
                property bool isActive: Hyprland.focusedWorkspace?.id === wsId

                text: wsId
                color: isActive ? root.colCyan : (ws ? root.colBlue : root.colMuted)
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.bold: true

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + wsId)
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Clock
        Text {
            id: clock
            text: Qt.formatDateTime(new Date(), "HH:mm:ss")
            color: root.colFg
            font.family: root.fontFamily
            font.pixelSize: root.fontSize

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm:ss")
            }
        }

        Rectangle { width: 1; height: 16; color: root.colMuted }

        // Mem + CPU readouts
        Text {
            text: "MEM " + root.memUsage + "%"
            color: root.colFg
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
        }

        Rectangle { width: 1; height: 16; color: root.colMuted }

        Text {
            text: "CPU " + root.cpuUsage + "%"
            color: root.colYellow
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.bold: true
        }
    }
}
```

This is essentially Tony’s end-to-end bar: workspaces, CPU, memory, clock, with the same building blocks he describes.  ([tonybtw.com][1])

---

## Start it with Hyprland (autostart)

In your Hyprland config, use `exec-once` to start it at compositor launch. ([Hyprland Wiki][10])

Example:

```conf
exec-once = qs
```

Tony describes swapping Waybar out and having Hyprland start Quickshell instead. 

---

## Useful “real life” details (that save you pain)

### 1) Hyprland API surface you’ll actually use

* `Hyprland.workspaces`, `Hyprland.focusedWorkspace`, and `Hyprland.dispatch(...)` are the bread and butter. ([quickshell.outfoxxed.me][7])
* Workspaces have additional properties and helper functions (like `activate()` on `HyprlandWorkspace`) when you want to go beyond simple dispatch strings. ([quickshell.outfoxxed.me][11])

### 2) Process parsing basics

`Process` and `SplitParser` are official types; when in doubt, check the type docs for signals/properties (stderr handling, working directory, lifecycle). ([quickshell.outfoxxed.me][8])

### 3) Config pragmas (scaling, env, dirs)

DeepWiki lists supported `//@ pragma ...` directives like:

* `Env VAR=VALUE` (good for `QT_SCALE_FACTOR`)
* `IconTheme name`
* overriding `DataDir`, `StateDir`, `CacheDir`, etc. ([DeepWiki][3])

These are great for making your shell portable across machines without duct-taping environment variables in launch scripts.

---

## Debugging loop (fast iteration)

* Run `qs` from a terminal so you can see errors and logs while you tweak QML.
* If `qs` says it can’t find `shell.qml`, verify `~/.config/quickshell/shell.qml` exists. ([DeepWiki][3])
* On Arch: after a Qt upgrade, rebuild `quickshell-git` if you see warnings about being built against an older Qt version. ([GitHub][6])

---

## Where to go next (the fun stuff)

* The official docs site includes a Hyprland integration section and type docs that make it easier to build “real UI” (window lists, monitors, toplevel tracking, etc.). ([quickshell.outfoxxed.me][7])
* DeepWiki’s sections on configuration structure and the window system are the bridge from “bar” to “desktop shell.” ([DeepWiki][3])
* Tony explicitly mentions wallpaper managers, dashboards, and lock widgets as natural next projects. 

If you want a practical next milestone that doesn’t explode scope: add a **layout indicator** and a **focused window title** (both are very “bar-like”, and they force you to learn the Hyprland object model without diving straight into DBus services).

[1]: https://www.tonybtw.com/tutorial/quickshell/ "Quickshell Tutorial - Build Your Own Bar"
[2]: https://quickshell.org/docs/guide/install-setup?utm_source=chatgpt.com "Installation & Setup"
[3]: https://deepwiki.com/quickshell-mirror/quickshell/2-getting-started "Getting Started | quickshell-mirror/quickshell | DeepWiki"
[4]: https://quickshell.outfoxxed.me/docs/v0.1.0/guide/qml-language/?utm_source=chatgpt.com "QML Language"
[5]: https://aur.archlinux.org/packages/quickshell-git?utm_source=chatgpt.com "quickshell-git - AUR (en) - Arch Linux"
[6]: https://github.com/end-4/dots-hyprland/issues/2171?utm_source=chatgpt.com "ISSUE AFTER UPDATE · Issue #2171 · end-4/dots-hyprland"
[7]: https://quickshell.outfoxxed.me/docs/v0.1.0/types/Quickshell.Hyprland/Hyprland/?utm_source=chatgpt.com "Hyprland"
[8]: https://quickshell.outfoxxed.me/docs/master/types/Quickshell.Io/Process/?utm_source=chatgpt.com "Quickshell.Io - Process"
[9]: https://quickshell.outfoxxed.me/docs/master/types/Quickshell.Io/SplitParser/?utm_source=chatgpt.com "Quickshell.Io - SplitParser"
[10]: https://wiki.hypr.land/Configuring/Keywords/?utm_source=chatgpt.com "Keywords"
[11]: https://quickshell.outfoxxed.me/docs/master/types/Quickshell.Hyprland/HyprlandWorkspace/?utm_source=chatgpt.com "Quickshell.Hyprland - HyprlandWorkspace"
