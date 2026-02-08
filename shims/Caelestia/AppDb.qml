import Quickshell.Io
import QtQuick

QtObject {
    id: root

    readonly property string uuid: _generateUuid()
    required property string path
    required property var entries
    property var apps: []

    onPathChanged: _loadFrequencies()
    onEntriesChanged: _rebuildTimer.restart()

    function incrementFrequency(id) {
        // Update in-memory frequency map
        if (!(id in _frequencies))
            _frequencies[id] = 0;
        _frequencies[id]++;

        // Persist to disk
        _saveFrequencies();

        // Update the AppEntry object and re-sort if needed
        const entry = _appMap[id];
        if (entry) {
            const before = _sortKey();
            entry.incrementFrequency();
            const after = _sortKey();

            if (before !== after) {
                _rebuildSorted();
                root.appsChanged();
            }
        } else {
            console.warn("AppDb.incrementFrequency: could not find app with id", id);
        }
    }

    property var _frequencies: ({})
    property var _appMap: ({})

    property Timer _rebuildTimer: Timer {
        interval: 300
        repeat: false
        onTriggered: root._updateApps()
    }

    property FileView _freqFile: FileView {
        id: freqFile
        path: root.path
        onLoaded: root._parseFrequencies(text())
        onLoadFailed: err => {
            root._frequencies = {};
        }
    }

    function _generateUuid() {
        // Simple UUID v4 generator
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(
            /[xy]/g,
            c => {
                const r = Math.random() * 16 | 0;
                const v = c === 'x' ? r : (r & 0x3 | 0x8);
                return v.toString(16);
            }
        );
    }

    function _loadFrequencies() {
        if (path)
            freqFile.reload();
    }

    function _parseFrequencies(text) {
        try {
            _frequencies = text ? JSON.parse(text) : {};
        } catch (e) {
            console.warn("AppDb: failed to parse frequency file:", e.message);
            _frequencies = {};
        }
        _updateAppFrequencies();
    }

    function _saveFrequencies() {
        if (!path)
            return;
        freqFile.setText(JSON.stringify(_frequencies, null, 2));
    }

    function _getFrequency(id) {
        return _frequencies[id] || 0;
    }

    function _updateAppFrequencies() {
        let dirty = false;
        for (const id in _appMap) {
            const entry = _appMap[id];
            const newFreq = _getFrequency(id);
            if (entry.frequency !== newFreq) {
                entry.setFrequency(newFreq);
                dirty = true;
            }
        }

        if (dirty) {
            _rebuildSorted();
            root.appsChanged();
        }
    }

    function _updateApps() {
        let dirty = false;

        // Build set of new entry IDs
        const newIds = new Set();
        for (const entry of entries) {
            const id = entry.id;
            newIds.add(id);

            if (!(id in _appMap)) {
                dirty = true;
                const appEntry = _entryComponent.createObject(
                    root, {
                        entry: entry,
                        frequency: _getFrequency(id),
                    }
                );
                _appMap[id] = appEntry;
            }
        }

        // Remove entries no longer present
        for (const id in _appMap) {
            if (!newIds.has(id)) {
                dirty = true;
                _appMap[id].destroy();
                delete _appMap[id];
            }
        }

        if (dirty) {
            _rebuildSorted();
            root.appsChanged();
        }
    }

    function _rebuildSorted() {
        const sorted = Object.values(_appMap);
        sorted.sort((a, b) => {
            if (a.frequency !== b.frequency)
                return b.frequency - a.frequency;
            return a.name.localeCompare(b.name);
        });
        root.apps = sorted;
    }

    function _sortKey() {
        return apps.map(a => `${a.id}:${a.frequency}`).join(",");
    }

    property Component _entryComponent: Component {
        AppEntry {}
    }
}
