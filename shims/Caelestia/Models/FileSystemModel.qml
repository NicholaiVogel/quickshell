import QtQuick
import Quickshell.Io

// Pure QML shim for caelestia::models::FileSystemModel
// Uses `find` via Process to list filesystem entries,
// then exposes them as a JS array compatible with model usage.
//
// The C++ original is a QAbstractListModel with a single role
// "modelData" (Qt::UserRole) that yields FileSystemEntry objects.
// QML views treat a JS array as a model where each element becomes
// `modelData`, so delegates that do
//   required property FileSystemEntry modelData
// will work if FileSystemEntry is a registered QML type and the
// objects are actual FileSystemEntry instances.

Item {
    id: root

    // keep this invisible; it only hosts Process children
    visible: false
    width: 0; height: 0

    // -- public properties matching C++ API --
    property string path: ""
    property bool recursive: false
    property bool watchChanges: true
    property bool showHidden: false
    property bool sortReverse: false
    property int filter: FileSystemModel.NoFilter
    property var nameFilters: []

    // the entry list, doubles as the model for views
    property var entries: []
    property int count: entries.length

    // -- filter enum values --
    enum Filter {
        NoFilter = 0,
        Images = 1,
        Files = 2,
        Dirs = 3
    }

    // -- convenience accessor for model-like usage --
    function get(index) {
        return entries[index] ?? null;
    }

    // -- internal --
    property var _entryComponent: Component {
        FileSystemEntry {}
    }

    readonly property var _imageExts: [
        "jpg", "jpeg", "png", "gif", "bmp", "webp",
        "svg", "tiff", "tif", "ico", "avif", "jxl"
    ]

    readonly property var _mimeMap: ({
        "jpg":  "image/jpeg",
        "jpeg": "image/jpeg",
        "png":  "image/png",
        "gif":  "image/gif",
        "bmp":  "image/bmp",
        "webp": "image/webp",
        "svg":  "image/svg+xml",
        "tiff": "image/tiff",
        "tif":  "image/tiff",
        "ico":  "image/x-icon",
        "avif": "image/avif",
        "jxl":  "image/jxl",
        "mp4":  "video/mp4",
        "mkv":  "video/x-matroska",
        "mp3":  "audio/mpeg",
        "flac": "audio/flac",
        "wav":  "audio/wav",
        "ogg":  "audio/ogg",
        "txt":  "text/plain",
        "json": "application/json",
        "xml":  "application/xml",
        "pdf":  "application/pdf"
    })

    function _buildCommand() {
        if (!root.path) return [];

        var args = ["find", root.path];

        if (!root.recursive)
            args.push("-maxdepth", "1");

        // mindepth 1 excludes the search directory itself
        args.push("-mindepth", "1");

        // hidden file handling: exclude dotfiles unless showHidden
        if (!root.showHidden)
            args.push("!", "-name", ".*");

        // type filter
        if (root.filter === FileSystemModel.Files)
            args.push("-type", "f");
        else if (root.filter === FileSystemModel.Dirs)
            args.push("-type", "d");
        else if (root.filter === FileSystemModel.Images)
            args.push("-type", "f");

        // name filters
        var names = _collectNameFilters();
        if (names.length > 0) {
            args.push("(");
            for (var i = 0; i < names.length; i++) {
                if (i > 0) args.push("-o");
                args.push("-iname", names[i]);
            }
            args.push(")");
        }

        return args;
    }

    function _collectNameFilters() {
        var result = [];

        // image filter adds common image globs
        if (root.filter === FileSystemModel.Images) {
            for (var i = 0; i < _imageExts.length; i++)
                result.push("*." + _imageExts[i]);
        }

        // user-supplied nameFilters
        if (root.nameFilters) {
            for (var j = 0; j < root.nameFilters.length; j++) {
                var nf = root.nameFilters[j];
                if (nf) result.push(nf);
            }
        }
        return result;
    }

    function _suffixOf(name) {
        var dot = name.lastIndexOf(".");
        return dot > 0 ? name.substring(dot + 1) : "";
    }

    function _baseNameOf(name) {
        var dot = name.indexOf(".");
        return dot > 0 ? name.substring(0, dot) : name;
    }

    function _parentOf(p) {
        var slash = p.lastIndexOf("/");
        return slash > 0 ? p.substring(0, slash) : "/";
    }

    function _nameOf(p) {
        var slash = p.lastIndexOf("/");
        return slash >= 0 ? p.substring(slash + 1) : p;
    }

    function _isImageExt(ext) {
        return _imageExts.indexOf(ext.toLowerCase()) >= 0;
    }

    function _mimeFor(ext) {
        return _mimeMap[ext.toLowerCase()] || "application/octet-stream";
    }

    function _relPath(fullPath) {
        var base = root.path;
        if (!base.endsWith("/")) base += "/";
        if (fullPath.startsWith(base))
            return fullPath.substring(base.length);
        return fullPath;
    }

    function _parseOutput(text) {
        var lines = text.split("\n");
        var result = [];

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line) continue;

            var full = line;
            var n = _nameOf(full);
            var ext = _suffixOf(n);
            var isD = full.endsWith("/");

            // find outputs dirs without trailing slash normally,
            // but stat -based detection is encoded in the
            // statProc below. for now, we mark everything as
            // file and fix dirs in the stat pass.
            var entry = _entryComponent.createObject(root, {
                path: full,
                relativePath: _relPath(full),
                name: n,
                baseName: _baseNameOf(n),
                parentDir: _parentOf(full),
                suffix: ext,
                size: 0,
                isDir: isD,
                isImage: _isImageExt(ext),
                mimeType: _mimeFor(ext)
            });
            result.push(entry);
        }

        // sort: dirs first (or last if reversed), then by
        // relativePath locale-aware
        result.sort(function(a, b) {
            if (a.isDir !== b.isDir)
                return root.sortReverse
                    ? (a.isDir ? 1 : -1)
                    : (a.isDir ? -1 : 1);

            var cmp = a.relativePath.localeCompare(b.relativePath);
            return root.sortReverse ? -cmp : cmp;
        });

        return result;
    }

    function _refresh() {
        var cmd = _buildCommand();
        if (cmd.length === 0) {
            _clearEntries();
            return;
        }
        findProc.command = cmd;
        findProc.running = true;
    }

    function _clearEntries() {
        // destroy old entry objects
        for (var i = 0; i < root.entries.length; i++) {
            if (root.entries[i] && root.entries[i].destroy)
                root.entries[i].destroy();
        }
        root.entries = [];
    }

    // -- trigger refresh when any config property changes --
    onPathChanged: _refresh()
    onRecursiveChanged: _refresh()
    onShowHiddenChanged: _refresh()
    onSortReverseChanged: _refresh()
    onFilterChanged: _refresh()
    onNameFiltersChanged: _refresh()

    // -- the find process --
    Process {
        id: findProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                var oldEntries = root.entries;
                root.entries = root._parseOutput(text);

                // destroy previous entries
                for (var i = 0; i < oldEntries.length; i++) {
                    if (oldEntries[i] && oldEntries[i].destroy)
                        oldEntries[i].destroy();
                }
            }
        }
    }

    // -- stat pass to detect directories properly --
    // find -type f won't catch this case, but for NoFilter
    // mode we need to know which results are dirs.
    // we run a second find for just dirs to build a set.
    Process {
        id: dirDetectProc

        property var pendingEntries: []

        command: {
            if (!root.path || root.filter === FileSystemModel.Files
                || root.filter === FileSystemModel.Images)
                return [];

            var args = ["find", root.path];
            if (!root.recursive)
                args.push("-maxdepth", "1");
            args.push("-mindepth", "1", "-type", "d");

            if (!root.showHidden)
                args.push("!", "-name", ".*");

            return args;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var dirSet = {};
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim();
                    if (l) dirSet[l] = true;
                }

                // patch isDir on current entries
                var ents = root.entries;
                var changed = false;
                for (var j = 0; j < ents.length; j++) {
                    if (dirSet[ents[j].path] && !ents[j].isDir) {
                        ents[j].isDir = true;
                        changed = true;
                    }
                }
                if (changed) {
                    // re-sort and notify
                    ents.sort(function(a, b) {
                        if (a.isDir !== b.isDir)
                            return root.sortReverse
                                ? (a.isDir ? 1 : -1)
                                : (a.isDir ? -1 : 1);
                        var cmp = a.relativePath
                            .localeCompare(b.relativePath);
                        return root.sortReverse ? -cmp : cmp;
                    });
                    root.entries = ents;
                }
            }
        }
    }

    // run dir detection after main find completes
    onEntriesChanged: {
        if (root.filter === FileSystemModel.NoFilter
            || root.filter === FileSystemModel.Dirs) {
            dirDetectProc.command = dirDetectProc.command;
            dirDetectProc.running = true;
        }
    }

    // -- periodic refresh for watchChanges --
    Timer {
        interval: 5000
        running: root.watchChanges && root.path !== ""
        repeat: true
        onTriggered: root._refresh()
    }

    Component.onCompleted: _refresh()
}
