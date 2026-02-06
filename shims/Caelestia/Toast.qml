import QtQuick

QtObject {
    id: root

    enum Type {
        Info,
        Success,
        Warning,
        Error
    }

    property bool closed: false
    property string title
    property string message
    property string icon
    property int timeout
    property int type: Toast.Info

    signal finishedClose()

    property var _locks: new Set()

    property Timer _timer: Timer {
        interval: root.timeout
        running: root.timeout > 0
        repeat: false
        onTriggered: root.close()
    }

    function close() {
        if (!closed)
            closed = true;

        if (_locks.size === 0)
            root.finishedClose();
    }

    function lock(sender) {
        _locks.add(sender);
    }

    function unlock(sender) {
        if (_locks.delete(sender) && closed)
            close();
    }
}
