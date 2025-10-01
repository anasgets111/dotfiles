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
  property var _iconCache: new Map()
  property var _iconCleanup: new Map()

  signal activated(var item)
  signal error(string message)
  signal menuOpened(var item)
  signal menuTriggered(var item, var entry)
  signal secondaryActivated(var item)

  function _modelCount(m) {
    return !m ? 0 : (m.count !== undefined ? Number(m.count) || 0 : (m.length !== undefined ? Number(m.length) || 0 : 0));
  }
  function _get(model, index) {
    const n = systemTrayService._modelCount(model);
    return (model && index >= 0 && index < n) ? (typeof model.get === "function" ? model.get(index) : (model[index] !== undefined ? model[index] : null)) : null;
  }
  function getItemFromRef(ref) {
    return !ref ? null : (typeof ref === "object" && typeof ref.activate === "function" ? ref : (typeof ref === "number" ? systemTrayService._get(systemTrayService.items, ref) : null));
  }

  function menuModelForItem(ref) {
    const it = systemTrayService.getItemFromRef(ref);
    return it ? (it.menu !== undefined ? it.menu : (it.contextMenu !== undefined ? it.contextMenu : null)) : null;
  }
  function hasMenuForItem(ref) {
    return !!systemTrayService.menuModelForItem(ref);
  }
  function menuItemAtIndex(ref, i) {
    return systemTrayService._get(systemTrayService.menuModelForItem(ref), i);
  }

  function displayTitleFor(ref) {
    const it = systemTrayService.getItemFromRef(ref);
    return it ? (it.title || it.name || it.appId || it.id || "") : "";
  }
  function tooltipTitleFor(ref) {
    const it = systemTrayService.getItemFromRef(ref);
    return it ? (it.tooltipTitle || systemTrayService.displayTitleFor(it)) : "";
  }
  function fallbackGlyphFor(ref) {
    const t = systemTrayService.tooltipTitleFor(ref) || systemTrayService.displayTitleFor(ref) || "?";
    return String(t).charAt(0).toUpperCase();
  }

  function _rememberIcon(it, value) {
    if (!it || !value)
      return;
    systemTrayService._iconCache.set(it, value);
    if (!systemTrayService._iconCleanup.has(it) && it.destroyed && typeof it.destroyed.connect === "function") {
      const cleanup = () => {
        systemTrayService._iconCache.delete(it);
        systemTrayService._iconCleanup.delete(it);
      };
      systemTrayService._iconCleanup.set(it, cleanup);
      try {
        it.destroyed.connect(cleanup);
      } catch (_) {}
    }
  }
  function _cachedIcon(it) {
    return (it && systemTrayService._iconCache.has(it)) ? systemTrayService._iconCache.get(it) : "";
  }

  function getNormalizedIconSource(icon) {
    if (icon === undefined || icon === null)
      return "";
    const s = icon.toString(), mark = "?path=", at = s.indexOf(mark);
    if (at === -1)
      return s;
    const name = s.substring(0, at), dir = s.substring(at + mark.length), slash = Math.max(name.lastIndexOf("/"), name.lastIndexOf("\\"));
    const file = slash >= 0 ? name.substring(slash + 1) : name;
    return (!dir || !file) ? s : ("file://" + dir + "/" + file);
  }
  function normalizedIconFor(ref) {
    const it = systemTrayService.getItemFromRef(ref);
    if (!it)
      return "";
    const direct = (it.icon !== undefined) ? systemTrayService.getNormalizedIconSource(it.icon) : "";
    if (direct) {
      systemTrayService._rememberIcon(it, direct);
      return direct;
    }
    const cached = systemTrayService._cachedIcon(it);
    if (cached)
      return cached;
    const app = it.appId || it.id || it.title || it.name || "";
    const resolved = app ? Utils.resolveIconSource(String(app), "") : "";
    if (resolved) {
      systemTrayService._rememberIcon(it, resolved);
      return resolved;
    }
    return "";
  }

  function _callFirst(target, names, args) {
    const list = Array.isArray(names) ? names : [];
    for (let i = 0; i < list.length; i++) {
      const fn = target[list[i]];
      if (typeof fn === "function") {
        fn.call(target, ...(args || []));
        return true;
      }
    }
    return false;
  }
  function _invoke(ref, method, signalName, label) {
    const it = systemTrayService.getItemFromRef(ref);
    if (!it) {
      systemTrayService.error(label + ": invalid item");
      return false;
    }
    try {
      it[method]();
      systemTrayService[signalName](it);
      return true;
    } catch (e) {
      systemTrayService.error(label + ": " + e);
      return false;
    }
  }

  function activateItem(ref) {
    return systemTrayService._invoke(ref, "activate", "activated", "activate");
  }
  function secondaryActivateItem(ref) {
    return systemTrayService._invoke(ref, "secondaryActivate", "secondaryActivated", "secondaryActivate");
  }
  function handleItemClick(ref, button) {
    return button === Qt.LeftButton ? systemTrayService.activateItem(ref) : systemTrayService.secondaryActivateItem(ref);
  }

  function openMenuForItem(ref, x, y) {
    const it = systemTrayService.getItemFromRef(ref);
    if (!it) {
      systemTrayService.error("openMenu: invalid item");
      return false;
    }
    const args = (typeof x === "number" && typeof y === "number") ? [x, y] : [];
    try {
      if (systemTrayService._callFirst(it, ["showMenu", "openMenu", "popup", "openContextMenu"], args)) {
        systemTrayService.menuOpened(it);
        return true;
      }
    } catch (e) {
      systemTrayService.error("openMenu: " + e);
      return false;
    }
    return systemTrayService.secondaryActivateItem(it);
  }

  function scrollItem(ref, dx, dy) {
    const it = systemTrayService.getItemFromRef(ref);
    if (!it)
      return false;
    try {
      if (typeof it.scroll === "function") {
        it.scroll(dx || 0, dy || 0);
        return true;
      }
    } catch (e) {
      systemTrayService.error("scroll: " + e);
      return false;
    }
    return false;
  }

  function triggerMenuItem(ref, key) {
    const it = systemTrayService.getItemFromRef(ref), model = systemTrayService.menuModelForItem(ref);
    if (!it || !model) {
      systemTrayService.error("triggerMenuItem: no menu or invalid item");
      return false;
    }
    let entry = null;
    if (typeof key === "number")
      entry = systemTrayService.menuItemAtIndex(it, key);
    else if (typeof key === "string") {
      const n = systemTrayService._modelCount(model);
      for (let i = 0; i < n; i++) {
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
        systemTrayService.menuTriggered(it, entry);
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
