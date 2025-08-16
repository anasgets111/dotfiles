pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Minimal SystemTray service: exposes a list of tray items.
    // Note: ObjectModels cannot be created in singletons. Use a plain
    // JavaScript array here and expose it as `items`. UI components that
    // need an actual QML model can wrap this array with ListModel or
    // create an ObjectModel at the UI side.
    property var objectModel: QtObject // hint for tooling

    // Use a plain array to store items to avoid constructing ObjectModel
    // inside a singleton (not allowed). Code previously used `items.values`;
    // update functions below to use `items` directly.
    property var items: []

    signal itemAdded(var item)
    signal itemRemoved(string id)

    function findById(id) {
        for (var i = 0; i < items.length; ++i) {
            if (items[i].id === id)
                return items[i];
        }
        return null;
    }

    function addItem(item) {
        if (!item || !item.id)
            return null;
        if (findById(item.id))
            return findById(item.id);
        items.push(item);
        itemAdded(item);
        return item;
    }

    function removeItem(id) {
        for (var i = 0; i < items.length; ++i) {
            if (items[i].id === id) {
                var removed = items.splice(i, 1)[0];
                itemRemoved(id);
                return removed;
            }
        }
        return null;
    }
}
