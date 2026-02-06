import QtQuick

QtObject {
    property Item item: null
    property url cacheDir: ""
    property string path: ""
    property url cachePath: ""

    function updateSource(newPath) {
        if (newPath !== undefined) {
            path = newPath;
        }

        if (path === "") {
            cachePath = "";
            return;
        }

        // pass through with file:// prefix if not already a url
        if (path.indexOf("://") === -1) {
            cachePath = "file://" + path;
        } else {
            cachePath = path;
        }
    }

    onPathChanged: updateSource()
    onCachePathChanged: if (item) item.source = cachePath
}
