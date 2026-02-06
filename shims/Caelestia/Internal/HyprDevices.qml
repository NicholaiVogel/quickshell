import QtQuick

QtObject {
    property var keyboards: []

    function updateLastIpcObject(jsonObject) {
        var kbList = jsonObject.keyboards || [];
        var result = [];
        for (var i = 0; i < kbList.length; i++) {
            var kb = kbComponent.createObject(this);
            kb.updateFromJson(kbList[i]);
            result.push(kb);
        }
        keyboards = result;
    }

    property Component kbComponent: Component {
        HyprKeyboard {}
    }
}
