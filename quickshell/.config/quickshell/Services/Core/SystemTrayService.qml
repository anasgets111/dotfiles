pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Backend-only singleton service for the System Tray.
// Responsibilities:
// - Host a single SystemTray instance
// - Expose the live items model via `items`
// - Provide safe activation helpers (left/right click semantics)
// - Normalize icon sources via `getNormalizedIconSource` and `normalizedIconFor`
// - Menu helpers (hasMenuForItem, openMenuForItem, triggerMenuItem) with feature detection
// - Optional convenience getters (count, itemAtIndex)
// No UI or styling here—pure logic for reuse by UI components.
Singleton {
    id: systemTrayService

    // Public model exposure (bind directly to the SystemTray singleton)
    readonly property var items: SystemTray.items
    readonly property int count: getModelCount(items)

    // Signals for instrumentation
    signal activated(var item)
    signal secondaryActivated(var item)
    signal error(string message)
    signal menuOpened(var item)
    signal menuTriggered(var item, var entry)

    // Convenience accessor
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
        // Fallback for array-like
        return items[index] !== undefined ? items[index] : null;
    }

    // Resolve an item reference which may be:
    // - a SystemTrayItem (object with activate/secondaryActivate)
    // - a numeric index into items
    function getItemFromRef(itemRef) {
        if (!itemRef)
            return null;
        // Already a SystemTrayItem
        if (typeof itemRef === "object" && typeof itemRef.activate === "function")
            return itemRef;
        // Numeric index into items
        if (typeof itemRef === "number")
            return itemAtIndex(itemRef);
        return null;
    }

    // Normalize icon source strings. Some tray items provide an icon with
    // a query-like suffix `?path=/abs/path`. Convert those to a file URL
    // pointing at the basename within that path.
    function getNormalizedIconSource(icon) {
        if (icon === undefined || icon === null)
            return "";
        let source = icon.toString();
        const pathMarker = "?path=";
        const markerPos = source.indexOf(pathMarker);
        if (markerPos === -1)
            return source;

        const namePart = source.substring(0, markerPos);
        const iconPath = source.substring(markerPos + pathMarker.length);
        const lastSlashIndex = Math.max(namePart.lastIndexOf("/"), namePart.lastIndexOf("\\"));
        const baseName = lastSlashIndex >= 0 ? namePart.substring(lastSlashIndex + 1) : namePart;
        if (!iconPath || !baseName)
            return source; // fallback to original if malformed
        return `file://${iconPath}/${baseName}`;
    }

    // Convenience to get a normalized icon for an item ref
    function normalizedIconFor(itemRef) {
        const trayItem = getItemFromRef(itemRef);
        return trayItem && trayItem.icon !== undefined ? getNormalizedIconSource(trayItem.icon) : "";
    }

    // Activation helpers
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
        } catch (error) {
            console.warn("SystemTrayService.activateItem: error", error);
            systemTrayService.error("activate: " + error);
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
        } catch (error) {
            console.warn("SystemTrayService.secondaryActivateItem: error", error);
            systemTrayService.error("secondaryActivate: " + error);
            return false;
        }
    }

    // Button-dispatching click handler to keep UI minimal.
    function handleItemClick(itemRef, mouseButton) {
        if (mouseButton === Qt.LeftButton)
            return activateItem(itemRef);
        return secondaryActivateItem(itemRef);
    }

    // ===== Menu helpers =====
    // Discover a menu model on an item if present
    function menuModelForItem(itemRef) {
        const trayItem = getItemFromRef(itemRef);
        if (!trayItem)
            return null;
        // Commonly exposed as `menu` in SNI-backed items
        if (trayItem.menu !== undefined)
            return trayItem.menu;
        // Some implementations might expose `contextMenu`
        if (trayItem.contextMenu !== undefined)
            return trayItem.contextMenu;
        return null;
    }

    function hasMenuForItem(itemRef) {
        return !!menuModelForItem(itemRef);
    }

    // Try to open the context menu near optional coordinates.
    // Attempts known method names, then falls back to secondaryActivate.
    function openMenuForItem(itemRef, posX, posY) {
        const trayItem = getItemFromRef(itemRef);
        if (!trayItem) {
            systemTrayService.error("openMenu: invalid item");
            return false;
        }
        const args = (typeof posX === "number" && typeof posY === "number") ? [posX, posY] : [];
        try {
            if (typeof trayItem.showMenu === "function") {
                trayItem.showMenu.apply(trayItem, args);
                systemTrayService.menuOpened(trayItem);
                return true;
            }
            if (typeof trayItem.openMenu === "function") {
                trayItem.openMenu.apply(trayItem, args);
                systemTrayService.menuOpened(trayItem);
                return true;
            }
            if (typeof trayItem.popup === "function") {
                trayItem.popup.apply(trayItem, args);
                systemTrayService.menuOpened(trayItem);
                return true;
            }
            if (typeof trayItem.openContextMenu === "function") {
                trayItem.openContextMenu.apply(trayItem, args);
                systemTrayService.menuOpened(trayItem);
                return true;
            }
        } catch (error) {
            console.warn("SystemTrayService.openMenuForItem: error", error);
            systemTrayService.error("openMenu: " + error);
            return false;
        }
        // Fallback behavior, typical right-click
        return secondaryActivateItem(trayItem);
    }

    // Access an entry from a menu model by index
    function menuItemAtIndex(itemRef, index) {
        const menuModel = menuModelForItem(itemRef);
        if (!menuModel || typeof index !== "number")
            return null;
        const entryCount = getModelCount(menuModel);
        if (!(entryCount >= 0) || index < 0 || index >= entryCount)
            return null;
        if (typeof menuModel.get === "function")
            return menuModel.get(index);
        return menuModel[index] !== undefined ? menuModel[index] : null;
    }

    // Trigger a menu item by numeric index or by string key (id/text/title)
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
            for (let i = 0; i < entryCount; i++) {
                const menuEntryCandidate = typeof menuModel.get === "function" ? menuModel.get(i) : (menuModel[i] !== undefined ? menuModel[i] : null);
                if (!menuEntryCandidate)
                    continue;
                const candidateName = menuEntryCandidate.id || menuEntryCandidate.key || menuEntryCandidate.name || menuEntryCandidate.text || menuEntryCandidate.title;
                if (candidateName === key) {
                    entry = menuEntryCandidate;
                    break;
                }
            }
        } else {
            entry = key; // assume an entry object was passed
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
        } catch (error) {
            console.warn("SystemTrayService.triggerMenuItem: error", error);
            systemTrayService.error("triggerMenuItem: " + error);
            return false;
        }
        systemTrayService.error("triggerMenuItem: no trigger method on entry");
        return false;
    }
}
