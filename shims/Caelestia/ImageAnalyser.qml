import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property string source: ""
    property Item sourceItem: null
    property int rescaleSize: 128
    property color dominantColour: "#000000"
    property real luminance: 0.0

    signal sourceChanged()
    signal sourceItemChanged()
    signal rescaleSizeChanged()
    signal dominantColourChanged()
    signal luminanceChanged()

    onSourceChanged: {
        if (sourceItem) {
            sourceItem = null;
            root.sourceItemChanged();
        }
        requestUpdate();
    }

    onSourceItemChanged: {
        if (source !== "") {
            source = "";
            root.sourceChanged();
        }
        requestUpdate();
    }

    onRescaleSizeChanged: requestUpdate()

    function requestUpdate() {
        _debounce.restart();
    }

    property Timer _debounce: Timer {
        interval: 50
        repeat: false
        onTriggered: root._doUpdate()
    }

    function _doUpdate() {
        if (!source && !sourceItem)
            return;

        if (source) {
            _analyseFile(source);
        } else if (sourceItem) {
            _analyseSourceItem();
        }
    }

    function _analyseSourceItem() {
        if (!sourceItem || !sourceItem.grabToImage)
            return;

        const tmpPath = `/tmp/qs_imganalyse_${Date.now()}.png`;
        sourceItem.grabToImage(result => {
            result.saveToFile(tmpPath);
            _analyseFile(tmpPath);
        });
    }

    function _analyseFile(path) {
        const filePath = path.toString().replace(/^file:\/\//, "");

        // Use magick to get average color (resize to 1x1)
        // Output format: "0,0: (R,G,B,...) #RRGGBB ..."
        const proc = _procComponent.createObject(root, {
            command: [
                "sh", "-c",
                `magick "${filePath}" -resize 1x1! txt:- 2>/dev/null || convert "${filePath}" -resize 1x1! txt:- 2>/dev/null`
            ],
        });

        proc.stdout.streamFinished.connect(() => {
            _parseOutput(proc.stdout.text);
            proc.destroy();
        });

        proc.running = true;
    }

    function _parseOutput(output) {
        // ImageMagick txt:- format:
        // "# ImageMagick pixel enumeration: ..."
        // "0,0: (R,G,B, ...) #RRGGBB srgb(...)"
        const match = output.match(
            /\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/
        );

        if (!match)
            return;

        const r = parseInt(match[1], 10) / 255.0;
        const g = parseInt(match[2], 10) / 255.0;
        const b = parseInt(match[3], 10) / 255.0;

        const newColour = Qt.rgba(r, g, b, 1.0);
        const newLum = Math.sqrt(
            0.299 * r * r + 0.587 * g * g + 0.114 * b * b
        );

        if (!Qt.colorEqual(dominantColour, newColour)) {
            dominantColour = newColour;
            root.dominantColourChanged();
        }
        if (Math.abs(luminance - newLum) > 0.001) {
            luminance = newLum;
            root.luminanceChanged();
        }
    }

    property Component _procComponent: Component {
        Process {
            property alias text: collector.text

            stdout: StdioCollector {
                id: collector
            }
        }
    }
}
