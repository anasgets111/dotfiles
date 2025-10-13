pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.Services.Utils

Singleton {
  id: root

  // Icon caching for performance
  property var _iconCache: new Map()
  property var _iconCleanup: new Map()

  // Public properties
  readonly property int count: items?.count ?? items?.length ?? 0
  readonly property var items: SystemTray.items
  readonly property int maxCacheSize: 25

  // Signals for events (can be connected for logging/debugging)
  signal activated(var item)
  signal error(string message)
  signal secondaryActivated(var item)

  // Get cached icon for an item
  function _cachedIcon(it) {
    return (it && _iconCache.has(it)) ? _iconCache.get(it) : "";
  }

  // Public API - Icon handling
  function _getNormalizedIconSource(icon) {
    if (!icon)
      return "";

    const str = icon.toString();
    const pathMarker = "?path=";
    const pathIndex = str.indexOf(pathMarker);

    if (pathIndex === -1)
      return str;

    const name = str.substring(0, pathIndex);
    const dir = str.substring(pathIndex + pathMarker.length);
    const lastSlash = Math.max(name.lastIndexOf("/"), name.lastIndexOf("\\"));
    const file = lastSlash >= 0 ? name.substring(lastSlash + 1) : name;

    return (dir && file) ? `file://${dir}/${file}` : str;
  }

  // Invoke a method on an item with error handling
  function _invoke(ref, method, signalName, label) {
    const it = getItemFromRef(ref);
    if (!it) {
      error(`${label}: invalid item`);
      return false;
    }

    try {
      it[method]();
      root[signalName](it);
      return true;
    } catch (e) {
      error(`${label}: ${e}`);
      return false;
    }
  }

  // Cache icon and setup cleanup on item destruction
  function _rememberIcon(it, value) {
    if (!it || !value)
      return;

    // Evict oldest entry if at capacity (LRU)
    if (_iconCache.size >= maxCacheSize) {
      const firstKey = _iconCache.keys().next().value;
      if (firstKey !== undefined) {
        _iconCache.delete(firstKey);
        const cleanup = _iconCleanup.get(firstKey);
        if (cleanup)
          _iconCleanup.delete(firstKey);
      }
    }

    _iconCache.set(it, value);

    // Setup cleanup on item destruction
    if (!_iconCleanup.has(it) && it.destroyed && typeof it.destroyed.connect === "function") {
      const cleanup = () => {
        _iconCache.delete(it);
        _iconCleanup.delete(it);
      };
      _iconCleanup.set(it, cleanup);
      try {
        it.destroyed.connect(cleanup);
      } catch (_) {}
    }
  }

  // Public API - Item activation
  function activateItem(ref) {
    return _invoke(ref, "activate", "activated", "activate");
  }

  // Public API - Item information
  function displayTitleFor(ref) {
    const it = getItemFromRef(ref);
    return it ? (it.title || it.name || it.appId || it.id || "") : "";
  }

  function fallbackGlyphFor(ref) {
    const title = tooltipTitleFor(ref) || "?";
    return String(title).charAt(0).toUpperCase();
  }

  // Public API - Item resolution
  function getItemFromRef(ref) {
    if (!ref)
      return null;

    // Direct item reference
    if (typeof ref === "object" && typeof ref.activate === "function") {
      return ref;
    }

    // Index reference
    if (typeof ref === "number") {
      const count = items?.count ?? items?.length ?? 0;
      if (ref >= 0 && ref < count) {
        return typeof items.get === "function" ? items.get(ref) : items[ref];
      }
    }

    return null;
  }

  function handleItemClick(ref, button) {
    return button === Qt.LeftButton ? activateItem(ref) : secondaryActivateItem(ref);
  }

  // Public API - Menu handling
  function hasMenuForItem(ref) {
    return !!menuModelForItem(ref);
  }

  function menuModelForItem(ref) {
    const it = getItemFromRef(ref);
    return it?.menu ?? it?.contextMenu ?? null;
  }

  function normalizedIconFor(ref) {
    const it = getItemFromRef(ref);
    if (!it)
      return "";

    // Try direct icon
    if (it.icon !== undefined) {
      const direct = _getNormalizedIconSource(it.icon);
      if (direct) {
        _rememberIcon(it, direct);
        return direct;
      }
    }

    // Try cached icon
    const cached = _cachedIcon(it);
    if (cached)
      return cached;

    // Try resolving from app ID
    const appId = it.appId || it.id || it.title || it.name;
    if (appId) {
      const resolved = Utils.resolveIconSource(String(appId), "");
      if (resolved) {
        _rememberIcon(it, resolved);
        return resolved;
      }
    }

    return "";
  }

  // Public API - Item interaction
  function scrollItem(ref, dx, dy) {
    const it = getItemFromRef(ref);
    if (!it)
      return false;

    try {
      if (typeof it.scroll === "function") {
        it.scroll(dx || 0, dy || 0);
        return true;
      }
    } catch (e) {
      error(`scroll: ${e}`);
    }
    return false;
  }

  function secondaryActivateItem(ref) {
    return _invoke(ref, "secondaryActivate", "secondaryActivated", "secondaryActivate");
  }

  function tooltipTitleFor(ref) {
    const it = getItemFromRef(ref);
    return it?.tooltipTitle || it?.title || it?.name || it?.appId || it?.id || "";
  }
}
