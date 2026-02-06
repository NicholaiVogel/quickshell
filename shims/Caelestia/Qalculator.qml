pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Shim for the C++ Qalculator singleton.
// The C++ version calls libqalculate synchronously.
// This shim runs `qalc` via Process and caches results.
// Bindings that call eval() get "" initially, then the
// cached result once the async process finishes (triggered
// via _revision dependency).
QtObject {
    id: root

    property var _cache: ({})
    property int _revision: 0

    // Matches C++ signature: QString eval(const QString& expr, bool printExpr = true)
    // Returns cached result or "" while async computation runs.
    function evaluate(expr, printExpr) {
        if (printExpr === undefined)
            printExpr = true;

        if (!expr || expr.trim() === "")
            return "";

        const key = `${expr}|${printExpr}`;

        // Force binding dependency so callers re-evaluate
        // when async results arrive
        void root._revision;

        if (key in _cache)
            return _cache[key];

        _runQalc(expr, printExpr, key);
        return "";
    }

    // Async variant with explicit callback
    function evalAsync(expr, printExpr, callback) {
        if (!expr || expr.trim() === "") {
            if (typeof callback === "function")
                callback("");
            return;
        }

        const key = `${expr}|${printExpr}`;
        _runQalc(expr, printExpr, key, callback);
    }

    function _runQalc(expr, printExpr, key, callback) {
        const args = printExpr ? [expr] : ["-t", expr];

        const proc = _procComponent.createObject(root, {
            command: ["qalc", ...args],
        });

        proc.stdout.streamFinished.connect(() => {
            let result = proc.stdout.text.trim();
            if (!result)
                result = "";

            root._cache[key] = result;
            root._revision++;

            if (typeof callback === "function")
                callback(result);

            proc.destroy();
        });

        proc.running = true;
    }

    property Component _procComponent: Component {
        Process {
            property alias text: collector.text

            stdout: StdioCollector {
                id: collector
            }
        }
    }
}
