pragma Singleton

import QtQuick

QtObject {
    id: root

    // Use var to get JS array semantics (supports for...of,
    // index access, unshift, splice, indexOf)
    property var toasts: []

    signal toastsChanged()

    function toast(title, message, icon, type, timeout) {
        if (type === undefined)
            type = Toast.Info;
        if (timeout === undefined)
            timeout = 0;

        if (!icon || icon === "") {
            switch (type) {
            case Toast.Success:
                icon = "check_circle_unread";
                break;
            case Toast.Warning:
                icon = "warning";
                break;
            case Toast.Error:
                icon = "error";
                break;
            default:
                icon = "info";
                break;
            }
        }

        if (timeout <= 0) {
            switch (type) {
            case Toast.Warning:
                timeout = 7000;
                break;
            case Toast.Error:
                timeout = 10000;
                break;
            default:
                timeout = 5000;
                break;
            }
        }

        const t = toastComponent.createObject(root, {
            title: title,
            message: message,
            icon: icon,
            type: type,
            timeout: timeout,
        });

        t.finishedClose.connect(() => {
            const idx = root.toasts.indexOf(t);
            if (idx !== -1) {
                root.toasts.splice(idx, 1);
                root.toasts = root.toasts; // trigger binding update
                root.toastsChanged();
                t.destroy();
            }
        });

        root.toasts.unshift(t);
        root.toasts = root.toasts; // trigger binding update
        root.toastsChanged();
    }

    property Component toastComponent: Component {
        Toast {}
    }
}
