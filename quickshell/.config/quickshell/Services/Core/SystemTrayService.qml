import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.Services.Utils
pragma Singleton

Singleton {
    id: systemTrayService

    readonly property var items: SystemTray.items
    readonly property int count: getModelCount(items)

    signal activated(var item)
    signal secondaryActivated(var item)
    signal error(string message)
    signal menuOpened(var item)
    signal menuTriggered(var item, var entry)

    function getModelCount(model) {
        if (!model)
            return 0;

        if (model.count !== undefined)
            return Number(model.count) || 0;

        if (model.length !== undefined)
            return Number(model.length) || 0;

        return 0;
    }

    function itemAtIndex(index) {
        if (!items || index < 0 || index >= count)
            return null;

        if (typeof items.get === "function")
            return items.get(index);

        return items[index] !== undefined ? items[index] : null;
    }

    function getItemFromRef(itemRef) {
        if (!itemRef)
            return null;

        if (typeof itemRef === "object" && typeof itemRef.activate === "function")
            return itemRef;

        if (typeof itemRef === "number")
            return itemAtIndex(itemRef);

        return null;
    }

    function getNormalizedIconSource(icon) {
        if (icon === undefined || icon === null)
            return "";

        const source = icon.toString();
        const pathMarker = "?path=";
        const markerPosition = source.indexOf(pathMarker);
        if (markerPosition === -1)
            return source;

        const namePart = source.substring(0, markerPosition);
        const iconDirectoryPath = source.substring(markerPosition + pathMarker.length);
        const lastSlashIndex = Math.max(namePart.lastIndexOf("/"), namePart.lastIndexOf("\\"));
        const iconFileName = lastSlashIndex >= 0 ? namePart.substring(lastSlashIndex + 1) : namePart;
        if (!iconDirectoryPath || !iconFileName)
            return source;
 // fallback to original if malformed
        return `file://${iconDirectoryPath}/${iconFileName}`;
    }

    function normalizedIconFor(itemRef) {
        const trayItem = getItemFromRef(itemRef);
        if (!trayItem)
            return "";

        // Prefer tray-provided icon
        const direct = trayItem.icon !== undefined ? getNormalizedIconSource(trayItem.icon) : "";
        if (direct)
            return direct;

        // Fallback: attempt to resolve via desktop entry from common identifiers
        const appIdentifier = trayItem.appId || trayItem.id || trayItem.title || trayItem.name || "";
        if (appIdentifier) {
            const resolved = Utils.resolveIconSource(String(appIdentifier), "");
            if (resolved)
                return resolved;

        }
        return "";
    }

    function activateItem(itemRef) {
        const trayItem = getItemFromRef(itemRef);
        if (!trayItem) {
            console.warn("SystemTrayService.activateItem: invalid item", itemRef);
            systemTrayService.error("activate: invalid item");
            return false;
        }
        try {
            trayItem.activate();
            systemTrayService.activated(trayItem);
            return true;
        } catch (exception) {
            console.warn("SystemTrayService.activateItem: error", exception);
            systemTrayService.error("activate: " + exception);
            return false;
        }
    }

    function secondaryActivateItem(itemRef) {
        const trayItem = getItemFromRef(itemRef);
        if (!trayItem) {
            console.warn("SystemTrayService.secondaryActivateItem: invalid item", itemRef);
            systemTrayService.error("secondaryActivate: invalid item");
            return false;
        }
        try {
            trayItem.secondaryActivate();
            systemTrayService.secondaryActivated(trayItem);
            return true;
        } catch (exception) {
            console.warn("SystemTrayService.secondaryActivateItem: error", exception);
            systemTrayService.error("secondaryActivate: " + exception);
            return false;
        }
    }

    function handleItemClick(itemRef, mouseButton) {
        if (mouseButton === Qt.LeftButton)
            return activateItem(itemRef);

        return secondaryActivateItem(itemRef);
    }

    function menuModelForItem(itemRef) {
        const trayItem = getItemFromRef(itemRef);
        if (!trayItem)
            return null;

        if (trayItem.menu !== undefined)
            return trayItem.menu;

        if (trayItem.contextMenu !== undefined)
            return trayItem.contextMenu;

        return null;
    }

    function hasMenuForItem(itemRef) {
        return !!menuModelForItem(itemRef);
    }

    function openMenuForItem(itemRef, posX, posY) {
        const trayItem = getItemFromRef(itemRef);
        if (!trayItem) {
            systemTrayService.error("openMenu: invalid item");
            return false;
        }
        const menuPositionArguments = (typeof posX === "number" && typeof posY === "number") ? [posX, posY] : [];
        try {
            const menuMethodNames = ["showMenu", "openMenu", "popup", "openContextMenu"];
            for (let methodIndex = 0; methodIndex < menuMethodNames.length; methodIndex++) {
                const methodName = menuMethodNames[methodIndex];
                if (typeof trayItem[methodName] === "function") {
                    trayItem[methodName].apply(trayItem, menuPositionArguments);
                    systemTrayService.menuOpened(trayItem);
                    return true;
                }
            }
        } catch (exception) {
            console.warn("SystemTrayService.openMenuForItem: error", exception);
            systemTrayService.error("openMenu: " + exception);
            return false;
        }
        return secondaryActivateItem(trayItem);
    }

    function menuItemAtIndex(itemRef, index) {
        const menuModel = menuModelForItem(itemRef);
        if (!menuModel || typeof index !== "number")
            return null;

        const entryCount = getModelCount(menuModel);
        if (index < 0 || index >= entryCount)
            return null;

        if (typeof menuModel.get === "function")
            return menuModel.get(index);

        return menuModel[index] !== undefined ? menuModel[index] : null;
    }

    function triggerMenuItem(itemRef, key) {
        const menuModel = menuModelForItem(itemRef);
        const trayItem = getItemFromRef(itemRef);
        if (!menuModel || !trayItem) {
            systemTrayService.error("triggerMenuItem: no menu or invalid item");
            return false;
        }
        let entry = null;
        if (typeof key === "number") {
            entry = menuItemAtIndex(trayItem, key);
        } else if (typeof key === "string") {
            const entryCount = getModelCount(menuModel);
            for (let index = 0; index < entryCount; index++) {
                const candidateEntry = typeof menuModel.get === "function" ? menuModel.get(index) : (menuModel[index] !== undefined ? menuModel[index] : null);
                if (!candidateEntry)
                    continue;

                const candidateName = candidateEntry.id || candidateEntry.key || candidateEntry.name || candidateEntry.text || candidateEntry.title;
                if (candidateName === key) {
                    entry = candidateEntry;
                    break;
                }
            }
        } else {
            entry = key;
        }
        if (!entry) {
            systemTrayService.error("triggerMenuItem: entry not found");
            return false;
        }
        try {
            if (typeof entry.trigger === "function") {
                entry.trigger();
                systemTrayService.menuTriggered(trayItem, entry);
                return true;
            }
            if (typeof entry.activate === "function") {
                entry.activate();
                systemTrayService.menuTriggered(trayItem, entry);
                return true;
            }
            if (typeof entry.click === "function") {
                entry.click();
                systemTrayService.menuTriggered(trayItem, entry);
                return true;
            }
        } catch (exception) {
            console.warn("SystemTrayService.triggerMenuItem: error", exception);
            systemTrayService.error("triggerMenuItem: " + exception);
            return false;
        }
        systemTrayService.error("triggerMenuItem: no trigger method on entry");
        return false;
    }

}
