pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.Services.Utils

Singleton {
  id: systemTrayService

  readonly property int count: systemTrayService.getModelCount(systemTrayService.items)
  readonly property var items: SystemTray.items

  signal activated(var item)
  signal error(string message)
  signal menuOpened(var item)
  signal menuTriggered(var item, var entry)
  signal secondaryActivated(var item)

  function activateItem(itemRef) {
    const trayItem = systemTrayService.getItemFromRef(itemRef);
    if (!trayItem) {
      systemTrayService.error("activate: invalid item");
      return false;
    }
    try {
      trayItem.activate();
      systemTrayService.activated(trayItem);
      return true;
    } catch (exceptionObject) {
      systemTrayService.error("activate: " + exceptionObject);
      return false;
    }
  }
  function displayTitleFor(itemRef) {
    const trayItem = systemTrayService.getItemFromRef(itemRef);
    if (!trayItem)
      return "";
    return trayItem.title || trayItem.name || trayItem.appId || trayItem.id || "";
  }
  function fallbackGlyphFor(itemRef) {
    const title = systemTrayService.tooltipTitleFor(itemRef) || systemTrayService.displayTitleFor(itemRef) || "?";
    return String(title).charAt(0).toUpperCase();
  }
  function getItemFromRef(itemRef) {
    if (!itemRef)
      return null;
    if (typeof itemRef === "object" && typeof itemRef.activate === "function")
      return itemRef;
    if (typeof itemRef === "number")
      return systemTrayService.itemAtIndex(itemRef);
    return null;
  }
  function getModelCount(model) {
    if (!model)
      return 0;
    if (model.count !== undefined)
      return Number(model.count) || 0;
    if (model.length !== undefined)
      return Number(model.length) || 0;
    return 0;
  }
  function getNormalizedIconSource(icon) {
    if (icon === undefined || icon === null)
      return "";
    const iconSource = icon.toString();
    const pathMarker = "?path=";
    const markerIndex = iconSource.indexOf(pathMarker);
    if (markerIndex === -1)
      return iconSource;

    const namePart = iconSource.substring(0, markerIndex);
    const iconDirectoryPath = iconSource.substring(markerIndex + pathMarker.length);
    const lastSlashIndex = Math.max(namePart.lastIndexOf("/"), namePart.lastIndexOf("\\"));
    const iconFileName = lastSlashIndex >= 0 ? namePart.substring(lastSlashIndex + 1) : namePart;
    if (!iconDirectoryPath || !iconFileName)
      return iconSource;
    return "file://" + iconDirectoryPath + "/" + iconFileName;
  }
  function handleItemClick(itemRef, mouseButton) {
    if (mouseButton === Qt.LeftButton)
      return systemTrayService.activateItem(itemRef);
    return systemTrayService.secondaryActivateItem(itemRef);
  }
  function hasMenuForItem(itemRef) {
    return !!systemTrayService.menuModelForItem(itemRef);
  }
  function itemAtIndex(index) {
    const modelRef = systemTrayService.items;
    if (!modelRef || index < 0 || index >= systemTrayService.count)
      return null;
    if (typeof modelRef.get === "function")
      return modelRef.get(index);
    return modelRef[index] !== undefined ? modelRef[index] : null;
  }
  function menuItemAtIndex(itemRef, index) {
    const menuModel = systemTrayService.menuModelForItem(itemRef);
    if (!menuModel || typeof index !== "number")
      return null;

    const entryCount = systemTrayService.getModelCount(menuModel);
    if (index < 0 || index >= entryCount)
      return null;

    if (typeof menuModel.get === "function")
      return menuModel.get(index);
    return menuModel[index] !== undefined ? menuModel[index] : null;
  }
  function menuModelForItem(itemRef) {
    const trayItem = systemTrayService.getItemFromRef(itemRef);
    if (!trayItem)
      return null;
    if (trayItem.menu !== undefined)
      return trayItem.menu;
    if (trayItem.contextMenu !== undefined)
      return trayItem.contextMenu;
    return null;
  }
  function normalizedIconFor(itemRef) {
    const trayItem = systemTrayService.getItemFromRef(itemRef);
    if (!trayItem)
      return "";

    const directIcon = trayItem.icon !== undefined ? systemTrayService.getNormalizedIconSource(trayItem.icon) : "";
    if (directIcon)
      return directIcon;

    const appIdentifier = trayItem.appId || trayItem.id || trayItem.title || trayItem.name || "";
    if (appIdentifier) {
      const resolvedIcon = Utils.resolveIconSource(String(appIdentifier), "");
      if (resolvedIcon)
        return resolvedIcon;
    }
    return "";
  }
  function openMenuForItem(itemRef, posX, posY) {
    const trayItem = systemTrayService.getItemFromRef(itemRef);
    if (!trayItem) {
      systemTrayService.error("openMenu: invalid item");
      return false;
    }

    const positionArgs = (typeof posX === "number" && typeof posY === "number") ? [posX, posY] : [];
    try {
      const methodNames = ["showMenu", "openMenu", "popup", "openContextMenu"];
      for (var methodIndex = 0; methodIndex < methodNames.length; methodIndex++) {
        const methodName = methodNames[methodIndex];
        if (typeof trayItem[methodName] === "function") {
          trayItem[methodName].apply(trayItem, positionArgs);
          systemTrayService.menuOpened(trayItem);
          return true;
        }
      }
    } catch (exceptionObject) {
      systemTrayService.error("openMenu: " + exceptionObject);
      return false;
    }
    return systemTrayService.secondaryActivateItem(trayItem);
  }
  function scrollItem(itemRef, deltaX, deltaY) {
    const trayItem = systemTrayService.getItemFromRef(itemRef);
    if (!trayItem)
      return false;
    try {
      if (typeof trayItem.scroll === "function") {
        trayItem.scroll(deltaX || 0, deltaY || 0);
        return true;
      }
    } catch (exceptionObject) {
      systemTrayService.error("scroll: " + exceptionObject);
      return false;
    }
    return false;
  }
  function secondaryActivateItem(itemRef) {
    const trayItem = systemTrayService.getItemFromRef(itemRef);
    if (!trayItem) {
      systemTrayService.error("secondaryActivate: invalid item");
      return false;
    }
    try {
      trayItem.secondaryActivate();
      systemTrayService.secondaryActivated(trayItem);
      return true;
    } catch (exceptionObject) {
      systemTrayService.error("secondaryActivate: " + exceptionObject);
      return false;
    }
  }
  function tooltipTitleFor(itemRef) {
    const trayItem = systemTrayService.getItemFromRef(itemRef);
    if (!trayItem)
      return "";
    return trayItem.tooltipTitle || systemTrayService.displayTitleFor(trayItem);
  }
  function triggerMenuItem(itemRef, key) {
    const trayItem = systemTrayService.getItemFromRef(itemRef);
    const menuModel = systemTrayService.menuModelForItem(itemRef);
    if (!trayItem || !menuModel) {
      systemTrayService.error("triggerMenuItem: no menu or invalid item");
      return false;
    }

    var chosenEntry = null;
    if (typeof key === "number") {
      chosenEntry = systemTrayService.menuItemAtIndex(trayItem, key);
    } else if (typeof key === "string") {
      const entryCount = systemTrayService.getModelCount(menuModel);
      for (var indexIter = 0; indexIter < entryCount; indexIter++) {
        const candidate = (typeof menuModel.get === "function") ? menuModel.get(indexIter) : (menuModel[indexIter] !== undefined ? menuModel[indexIter] : null);
        if (!candidate)
          continue;
        const candidateName = candidate.id || candidate.key || candidate.name || candidate.text || candidate.title;
        if (candidateName === key) {
          chosenEntry = candidate;
          break;
        }
      }
    } else {
      chosenEntry = key;
    }

    if (!chosenEntry) {
      systemTrayService.error("triggerMenuItem: entry not found");
      return false;
    }

    try {
      if (typeof chosenEntry.trigger === "function") {
        chosenEntry.trigger();
        systemTrayService.menuTriggered(trayItem, chosenEntry);
        return true;
      }
      if (typeof chosenEntry.activate === "function") {
        chosenEntry.activate();
        systemTrayService.menuTriggered(trayItem, chosenEntry);
        return true;
      }
      if (typeof chosenEntry.click === "function") {
        chosenEntry.click();
        systemTrayService.menuTriggered(trayItem, chosenEntry);
        return true;
      }
    } catch (exceptionObject) {
      systemTrayService.error("triggerMenuItem: " + exceptionObject);
      return false;
    }
    systemTrayService.error("triggerMenuItem: no trigger method on entry");
    return false;
  }
}
