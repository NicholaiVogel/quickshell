import QtQuick

QtObject {
    property var lastIpcObject: ({})
    property string address: ""
    property string name: ""
    property string layout: ""
    property string activeKeymap: ""
    property bool capsLock: false
    property bool numLock: false
    property bool main: false

    function updateFromJson(obj) {
        lastIpcObject = obj;
        address = obj.address || "";
        name = obj.name || "";
        layout = obj.layout || "";
        activeKeymap = obj.active_keymap || "";
        capsLock = !!obj.capsLock;
        numLock = !!obj.numLock;
        main = !!obj.main;
    }
}
