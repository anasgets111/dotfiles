pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.Services.Utils

Singleton {
  id: systemTrayService

  readonly property var items: SystemTray.items
  readonly property int count: (!items ? 0 : (items.count !== undefined ? Number(items.count) || 0 : (items.length !== undefined ? Number(items.length) || 0 : 0)))

  signal activated(var item)
  signal error(string message)
  signal menuOpened(var item)
  signal menuTriggered(var item, var entry)
  signal secondaryActivated(var item)

  function modelCount(model) {
    return !model ? 0 : (model.count !== undefined ? Number(model.count) || 0 : (model.length !== undefined ? Number(model.length) || 0 : 0));
  }
  function getItemFromRef(itemRef) {
    return !itemRef ? null : (typeof itemRef === "object" && typeof itemRef.activate === "function" ? itemRef : (typeof itemRef === "number" ? systemTrayService.itemAtIndex(itemRef) : null));
  }
  function itemAtIndex(index) {
    const model = systemTrayService.items, total = systemTrayService.modelCount(model);
    return (model && index >= 0 && index < total) ? (typeof model.get === "function" ? model.get(index) : (model[index] !== undefined ? model[index] : null)) : null;
  }

  function menuModelForItem(itemRef) {
    const item = systemTrayService.getItemFromRef(itemRef);
    return item ? (item.menu !== undefined ? item.menu : (item.contextMenu !== undefined ? item.contextMenu : null)) : null;
  }
  function hasMenuForItem(itemRef) {
    return !!systemTrayService.menuModelForItem(itemRef);
  }
  function menuItemAtIndex(itemRef, index) {
    const model = systemTrayService.menuModelForItem(itemRef), total = systemTrayService.modelCount(model);
    return (model && index >= 0 && index < total) ? (typeof model.get === "function" ? model.get(index) : (model[index] !== undefined ? model[index] : null)) : null;
  }

  function displayTitleFor(itemRef) {
    const item = systemTrayService.getItemFromRef(itemRef);
    return item ? (item.title || item.name || item.appId || item.id || "") : "";
  }
  function tooltipTitleFor(itemRef) {
    const item = systemTrayService.getItemFromRef(itemRef);
    return item ? (item.tooltipTitle || systemTrayService.displayTitleFor(item)) : "";
  }
  function fallbackGlyphFor(itemRef) {
    const title = systemTrayService.tooltipTitleFor(itemRef) || systemTrayService.displayTitleFor(itemRef) || "?";
    return String(title).charAt(0).toUpperCase();
  }

  function getNormalizedIconSource(icon) {
    if (icon === undefined || icon === null)
      return "";
    const src = icon.toString(), mark = "?path=", at = src.indexOf(mark);
    if (at === -1)
      return src;
    const namePart = src.substring(0, at), dir = src.substring(at + mark.length);
    const lastSlash = Math.max(namePart.lastIndexOf("/"), namePart.lastIndexOf("\\"));
    const file = lastSlash >= 0 ? namePart.substring(lastSlash + 1) : namePart;
    return (!dir || !file) ? src : ("file://" + dir + "/" + file);
  }
  function normalizedIconFor(itemRef) {
    const item = systemTrayService.getItemFromRef(itemRef);
    if (!item)
      return "";
    const direct = (item.icon !== undefined) ? systemTrayService.getNormalizedIconSource(item.icon) : "";
    if (direct)
      return direct;
    const app = item.appId || item.id || item.title || item.name || "";
    const resolved = app ? Utils.resolveIconSource(String(app), "") : "";
    return resolved || "";
  }

  function _callFirst(target, names, args) {
    for (const name of names) {
      const f = target[name];
      if (typeof f === "function") {
        f.apply(target, args);
        return true;
      }
    }
    return false;
  }

  function activateItem(itemRef) {
    const item = systemTrayService.getItemFromRef(itemRef);
    if (!item) {
      systemTrayService.error("activate: invalid item");
      return false;
    }
    try {
      item.activate();
      systemTrayService.activated(item);
      return true;
    } catch (e) {
      systemTrayService.error("activate: " + e);
      return false;
    }
  }
  function secondaryActivateItem(itemRef) {
    const item = systemTrayService.getItemFromRef(itemRef);
    if (!item) {
      systemTrayService.error("secondaryActivate: invalid item");
      return false;
    }
    try {
      item.secondaryActivate();
      systemTrayService.secondaryActivated(item);
      return true;
    } catch (e) {
      systemTrayService.error("secondaryActivate: " + e);
      return false;
    }
  }
  function handleItemClick(itemRef, button) {
    return button === Qt.LeftButton ? systemTrayService.activateItem(itemRef) : systemTrayService.secondaryActivateItem(itemRef);
  }

  function openMenuForItem(itemRef, x, y) {
    const item = systemTrayService.getItemFromRef(itemRef);
    if (!item) {
      systemTrayService.error("openMenu: invalid item");
      return false;
    }
    const args = (typeof x === "number" && typeof y === "number") ? [x, y] : [];
    try {
      if (systemTrayService._callFirst(item, ["showMenu", "openMenu", "popup", "openContextMenu"], args)) {
        systemTrayService.menuOpened(item);
        return true;
      }
    } catch (e) {
      systemTrayService.error("openMenu: " + e);
      return false;
    }
    return systemTrayService.secondaryActivateItem(item);
  }

  function scrollItem(itemRef, dx, dy) {
    const item = systemTrayService.getItemFromRef(itemRef);
    if (!item)
      return false;
    try {
      if (typeof item.scroll === "function") {
        item.scroll(dx || 0, dy || 0);
        return true;
      }
    } catch (e) {
      systemTrayService.error("scroll: " + e);
      return false;
    }
    return false;
  }

  function triggerMenuItem(itemRef, key) {
    const item = systemTrayService.getItemFromRef(itemRef), model = systemTrayService.menuModelForItem(itemRef);
    if (!item || !model) {
      systemTrayService.error("triggerMenuItem: no menu or invalid item");
      return false;
    }
    let entry = null;
    if (typeof key === "number")
      entry = systemTrayService.menuItemAtIndex(item, key);
    else if (typeof key === "string") {
      const total = systemTrayService.modelCount(model);
      for (let i = 0; i < total; i++) {
        const c = (typeof model.get === "function") ? model.get(i) : (model[i] !== undefined ? model[i] : null);
        const name = c && (c.id || c.key || c.name || c.text || c.title);
        if (name === key) {
          entry = c;
          break;
        }
      }
    } else
      entry = key;
    if (!entry) {
      systemTrayService.error("triggerMenuItem: entry not found");
      return false;
    }
    try {
      if (systemTrayService._callFirst(entry, ["trigger", "activate", "click"], [])) {
        systemTrayService.menuTriggered(item, entry);
        return true;
      }
    } catch (e) {
      systemTrayService.error("triggerMenuItem: " + e);
      return false;
    }
    systemTrayService.error("triggerMenuItem: no trigger method on entry");
    return false;
  }
}
