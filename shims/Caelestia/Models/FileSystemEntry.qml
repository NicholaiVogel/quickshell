import QtQuick

// Pure QML shim for caelestia::models::FileSystemEntry
// Mirrors the C++ property surface exactly.

QtObject {
    property string path: ""
    property string relativePath: ""
    property string name: ""
    property string baseName: ""
    property string parentDir: ""
    property string suffix: ""
    property int size: 0
    property bool isDir: false
    property bool isImage: false
    property string mimeType: "application/octet-stream"
}
