pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    function saveItem(target, path, rectOrOnSaved, onSavedOrOnFailed, onFailed) {
        if (!target) {
            console.warn("CUtils.saveItem: a target is required");
            return;
        }

        let rect = null;
        let savedCb = undefined;
        let failedCb = undefined;

        if (typeof rectOrOnSaved === "function") {
            savedCb = rectOrOnSaved;
            failedCb = onSavedOrOnFailed;
        } else if (rectOrOnSaved !== undefined) {
            rect = rectOrOnSaved;
            if (typeof onSavedOrOnFailed === "function") {
                savedCb = onSavedOrOnFailed;
                failedCb = onFailed;
            }
        }

        const localPath = toLocalFile(path);
        if (!localPath)
            return;

        target.grabToImage(result => {
            const tmpPath = `/tmp/qs_grab_${Date.now()}.png`;
            result.saveToFile(tmpPath);

            const proc = procComponent.createObject(root, {
                command: ["sh", "-c",
                    `mkdir -p "$(dirname '${localPath}')" && mv '${tmpPath}' '${localPath}'`],
            });

            proc.exited.connect(code => {
                if (code === 0) {
                    if (typeof savedCb === "function")
                        savedCb(localPath, path);
                } else {
                    console.warn("CUtils.saveItem: failed to save", localPath);
                    if (typeof failedCb === "function")
                        failedCb(path);
                }
                proc.destroy();
            });

            proc.running = true;
        });
    }

    function copyFile(source, target, overwrite) {
        if (overwrite === undefined)
            overwrite = true;

        const srcPath = toLocalFile(source);
        const tgtPath = toLocalFile(target);

        if (!srcPath || !tgtPath)
            return false;

        const flag = overwrite ? "-f" : "-n";
        const proc = procComponent.createObject(root, {
            command: ["cp", flag, srcPath, tgtPath],
        });

        let success = false;
        proc.exited.connect(code => {
            success = (code === 0);
            proc.destroy();
        });

        proc.running = true;
        return true;
    }

    function deleteFile(path) {
        const localPath = toLocalFile(path);
        if (!localPath)
            return false;

        const proc = procComponent.createObject(root, {
            command: ["rm", "-f", localPath],
        });

        proc.exited.connect(code => {
            proc.destroy();
        });

        proc.running = true;
        return true;
    }

    function toLocalFile(url) {
        const s = url.toString();
        if (s.startsWith("file://"))
            return s.substring(7);
        if (s.startsWith("/"))
            return s;
        console.warn("CUtils.toLocalFile: given url is not a local file", s);
        return "";
    }

    property Component procComponent: Component {
        Process {}
    }
}
