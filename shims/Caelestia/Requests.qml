pragma Singleton

import QtQuick

QtObject {
    id: root

    function get(url, onSuccess, onError) {
        if (typeof onSuccess !== "function") {
            console.warn("Requests.get: onSuccess is not callable");
            return;
        }

        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status >= 200 && xhr.status < 300) {
                onSuccess(xhr.responseText);
            } else if (typeof onError === "function") {
                onError(xhr.statusText || `HTTP ${xhr.status}`);
            } else {
                console.warn("Requests.get: request failed with error",
                    xhr.statusText || `HTTP ${xhr.status}`);
            }
        };

        xhr.open("GET", url.toString());
        xhr.send();
    }
}
