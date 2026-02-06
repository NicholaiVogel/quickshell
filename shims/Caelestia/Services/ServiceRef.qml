import QtQuick

// Simplified shim for caelestia::services::ServiceRef
// The C++ version does ref-counting for service lifecycle.
// In the QML shim world, services are always alive, so this
// is just a transparent reference holder.

QtObject {
    property QtObject service: null
}
