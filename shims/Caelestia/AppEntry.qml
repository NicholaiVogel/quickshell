import QtQuick

QtObject {
    id: root

    property QtObject entry: null
    property int frequency: 0

    readonly property string id: entry ? entry.id ?? "" : ""
    readonly property string name: entry ? entry.name ?? "" : ""
    readonly property string comment: entry ? entry.comment ?? "" : ""
    readonly property string execString: entry
        ? entry.execString ?? "" : ""
    readonly property string startupClass: entry
        ? entry.startupClass ?? "" : ""
    readonly property string genericName: entry
        ? entry.genericName ?? "" : ""

    // C++ version joins these as space-separated strings
    readonly property string categories: {
        if (!entry) return "";
        const c = entry.categories;
        if (Array.isArray(c)) return c.join(" ");
        return c ?? "";
    }

    readonly property string keywords: {
        if (!entry) return "";
        const k = entry.keywords;
        if (Array.isArray(k)) return k.join(" ");
        return k ?? "";
    }

    function incrementFrequency() {
        frequency++;
        root.frequencyChanged();
    }

    function setFrequency(f) {
        if (frequency !== f) {
            frequency = f;
            root.frequencyChanged();
        }
    }
}
