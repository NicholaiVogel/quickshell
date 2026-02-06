import QtQuick

// Stub shim for caelestia::services::BeatTracker
// No real beat detection; bpm stays at 0.

QtObject {
    property real bpm: 0.0
    signal beat(real bpm)
}
