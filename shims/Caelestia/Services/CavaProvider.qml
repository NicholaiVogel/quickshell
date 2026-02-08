import QtQuick

// Stub shim for caelestia::services::CavaProvider
// Provides the same property surface but no real audio data.
// values is always an array of 0s matching the bars count.

QtObject {
    property int refCount: 0
    property int bars: 0
    property var values: []

    onBarsChanged: _rebuildValues()

    function _rebuildValues() {
        var arr = [];
        for (var i = 0; i < bars; i++)
            arr.push(0.0);
        values = arr;
    }

    Component.onCompleted: _rebuildValues()
}
