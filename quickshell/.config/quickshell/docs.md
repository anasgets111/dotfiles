# Quickshell

## Variants: Reloadable

```qml
import Quickshell
```

Creates and destroys instances of the given component when the given property changes.

`Variants` is similar to `Repeater` except it is for non `Item` objects, and acts as a reload scope.

Each non duplicate value passed to `model` will create a new instance of `delegate` with a `modelData` property set to that value.

See `Quickshell.screens` for an example of using `Variants` to create copies of a window per screen.

> ⚠️ **WARNING**  
> BUG: Variants currently fails to reload children if the variant set is changed as it is instantiated. (usually due to a mutation during variant creation)

---

### Properties [?]

- `delegate`: Component

  _(default)_  
  The component to create instances of.

  The delegate should define a `modelData` property that will be popuplated with a value from the `model`.

---

-- `instances`: list <`QtObject`>

_(readonly)_  
 Current instances of the delegate.

---

- `model`: list <variant>

  The list of sets of properties to create instances with. Each set creates an instance of the component, which are updated when the input sets update.

---

## ShellScreen: `QtObject`

import Quickshell

Monitor object useful for setting the monitor for a `QsWindow` or querying information about the monitor.

> **WARNING**
> If the monitor is disconnected then any stored copies of its ShellMonitor will be marked as dangling and all properties will return default values. Reconnecting the monitor will not reconnect it to the ShellMonitor object.

Due to some technical limitations, it was not possible to reuse the native qml `Screen` type.

### Properties

- `devicePixelRatio: real` (readonly)

  - The ratio between physical pixels and device-independent (scaled) pixels.

- `model: string` (readonly)

  - The model of the screen as seen by the operating system.

- `serialNumber: string` (readonly)

  - The serial number of the screen as seen by the operating system.

- `name: string` (readonly)

  - The name of the screen as seen by the operating system. Usually something like `DP-1`, `HDMI-1`, `eDP-1`.

- `x: int` (readonly)

- `y: int` (readonly)

- `width: int` (readonly)

- `height: int` (readonly)

- `physicalPixelDensity: real` (readonly)

  - The number of physical pixels per millimeter.

- `logicalPixelDensity: real` (readonly)

  - The number of device-independent (scaled) pixels per millimeter.

- `orientation: unknown` (readonly)

- `primaryOrientation: unknown` (readonly)

### Functions

- `toString(): string`

---

## SystemClock: `QtObject`

import Quickshell

`SystemClock` is a view into the system's clock. It updates at hour, minute, or second intervals depending on `precision`.

### Example

```qml
SystemClock {
  id: clock
  precision: SystemClock.Seconds
}

Text {
  text: Qt.formatDateTime(clock.date, "hh:mm:ss - yyyy-MM-dd")
}
```

> **WARNING**
> Clock updates will trigger within 50ms of the system clock changing; however this can be either before or after the clock changes (+/-50ms). If you need a date object, use `date` instead of constructing a new one, or the time of the constructed object could be off by up to a second.

### Properties

- `hours: int` (readonly)

  - The current hour.

- `date: date` (readonly)

  - The current date and time.
  - Tip: You can use `Qt.formatDateTime()` to get the time as a string in your format of choice.

- `enabled: bool`

  - If the clock should update. Defaults to `true`.
  - Setting `enabled` to `false` pauses the clock.

- `minutes: int` (readonly)

  - The current minute, or `0` if `precision` is `SystemClock.Hours`.

- `precision: SystemClock`

  - The precision the clock should measure at. Defaults to `SystemClock.Seconds`.

- `seconds: int` (readonly)
  - The current second, or `0` if `precision` is `SystemClock.Hours` or `SystemClock.Minutes`.

### Variants

- `Hours`
- `Minutes`
- `Seconds`

## BoundComponent: `Item`

```qml
import Quickshell
```

A component loader that applies initial properties to a loaded component.  
Useful for escaping cyclic dependency errors.  
All properties (including `required`) stay reactive, and functions named after signal handlers are automatically connected.

---

### Example: Component Definition

```qml
MouseArea {
    required property color color;
    width: 100
    height: 100

    Rectangle {
        anchors.fill: parent
        color: parent.color
    }
}
```

### Example: BoundComponent Usage

```qml
BoundComponent {
    source: "MyComponent.qml"

    // Same as assigning `color` directly on MyComponent
    property color color: "red";

    // Respond to MouseArea's `clicked` signal
    function onClicked() {
        color = "blue";
    }
}
```

---

### Properties

- **`implicitWidth: real`** _(readonly)_  
  No details provided.

- **`bindValues: bool`**  
  Whether property values remain bound after initial set. Defaults to `true`.

- **`sourceComponent: Component`**  
  Component to load.

- **`implicitHeight: real`** _(readonly)_  
  No details provided.

- **`source: string`**  
  URL of the component to load.

-- **`item`: `QtObject`** _(readonly)_  
 The loaded component. `null` until loading finishes.

## FloatingWindow: `QSWindow`

`import Quickshell`

Standard toplevel operating system window that looks like any other application.

### Properties

- `maximumSize`: size
  - Maximum window size given to the window system.
- `minimumSize`: size
  - Minimum window size given to the window system.
- `title`: string
  - Window title.

## LazyLoader: Reloadable

import Quickshell

The LazyLoader can be used to prepare components that don't need to be created immediately, such as windows that aren't visible, until triggered by another action. It works by creating the component in the gaps between frames, helping to prevent blocking the interface thread. It can also be used to preserve memory by loading components only when you need them and unloading them afterward.

Note that when reloading the UI due to changes, lazy loaders will always load synchronously so windows can be reused.

### Example

The following example creates a PopupWindow asynchronously as the bar loads. This means the bar can be shown onscreen before the popup is ready; however, trying to show the popup before it has finished loading in the background will cause the UI thread to block.

```qml
import QtQuick
import QtQuick.Controls
import Quickshell

ShellRoot {
  parentWindow: Window {
    id: window
    height: 50

    anchors {
      bottom: true
      left: true
      right: true
    }

    LazyLoader {
      id: popupLoader

      // start loading immediately
      loading: true

      // this window will be loaded in the background during spare
      // frames unless active is set to true, where it will be
      // loaded in the foreground
      PopupWindow {
        // some popup drop above the button
        parentWindow: window
        relatives: window.width / 2 - width / 2
        relativesY: height

        // some heavy component here
        width: 200
        height: 200
      }
    }
    Button {
      anchors.centerIn: parent
      text: "show popup"

      // accessing popupLoader.item will force the loader to
      // finish loading on the UI thread if it isn't finished yet
      onClicked: popupLoader.item.visible = !popupLoader.item.visible
    }
  }
}
```

> WARNING

Components that internally load other components must explicitly support asynchronous loading to avoid blocking.

Notably, Variants does not currently support asynchronous loading, meaning using it inside a LazyLoader will block similarly to not having a loader to start with.

> WARNING

LazyLoaders do not start loading before the first window is created, meaning if you create all windows inside of lazy loaders, none of them will ever load.

### Properties

- loading: bool

  - If the loader is actively loading.
  - If the component is not loaded, setting this property to true will start loading it asynchronously. If the component is already loaded, setting this property has no effect.
  - See also: activeAsync.

- source: string
  - The URI to load the component from. Mutually exclusive to component.
- activeAsync: bool
  - If the component is fully loaded.
  - Setting this property to true will asynchronously load the component similarly to loading. Reading it or setting it to false will behave the same as active.
- item: `QtObject`
  - The fully loaded item if the loader is loading or active, or null if neither loading nor active.
  - Note that the item is owned by the LazyLoader, and destroying the LazyLoader will destroy the item.
  - WARNING: If you access the item of a loader that is currently loading, it will block as if you had set active to true immediately beforehand. You can instead set loading and listen to activeChanged() signal to ensure loading happens asynchronously.
- component: Component
  - The component to load. Mutually exclusive to source.
- active: bool
  - If the component is fully loaded.
  - Setting this property to true will force the component to load to completion, blocking the UI, and setting it to false will destroy the component, requiring it to be loaded again.
  - See also: activeAsync.

## ObjectModel: `ObjectModel`

`import Quickshell`

Typed view into a list of objects.

An `ObjectModel` works as a QML `Data Model`, allowing efficient interaction with components that act on models. It has a single role named `modelData` to match the behavior of lists. The same information contained in the list model is available as a normal list via the `values` property.

### Differences from a list

Unlike with a list, the following property binding will never be updated when `model[3]` changes.

`// will not update reactively`
`property var foo: model[3]`

You can work around this limitation using the `values` property of the model to view it as a list.

`// will update reactively`
`property var foo: model.values[3]`

### Properties

- `values`: list<`QtObject`> `[readonly]`
  - The content of the object model, as a QML list. The values of this property will always be of the type of the model.

### Functions

- `indexOf(object)`: `int`
  - `object`: `QtObject`

### Signals

- `objectInsertedPost(object, index)`
  - `object`: `QtObject`
  - `index`: `int`
  - Sent immediately after an object is inserted into the list.
- `objectInsertedPre(object, index)`
  - `object`: `QtObject`
  - `index`: `int`
  - Sent immediately before an object is inserted into the list.
- `objectRemovedPre(object, index)`
  - `object`: `QtObject`
  - `index`: `int`
  - Sent immediately before an object is removed from the list.
- `objectRemovedPost(object, index)`
  - `object`: `QtObject`
  - `index`: `int`
  - Sent immediately after an object is removed from the list.

## ObjectRepeater: `ObjectModel`

`import Quickshell`

`[ERROR] Removed in favor of Instantiator`

The `ObjectRepeater` creates instances of the provided delegate for every entry in the given model, similarly to a `Repeater` but for non visual types.

### Properties

- `model`: variant
  - The model providing data to the `ObjectRepeater`.
  - Currently accepted model types are `list<T>` lists, javascript arrays, and `QAbstractListModel` derived models, though only one column will be repeated from the latter.
  - Note: `ObjectModel` is a `QAbstractListModel` with a single column.
- `delegate`: `Component` `[default]`
  - The delegate component to repeat.
  - The delegate is given the same properties as in a `Repeater`, except `index` which is not currently implemented.
  - If the model is a `list<T>` or javascript array, a `modelData` property will be exposed containing the entry from the model. If the model is a `QAbstractListModel`, the roles from the model will be exposed.
  - Note: `ObjectModel` has a single role named `modelData` for compatibility with normal lists.

## PanelWindow: `QSWindow`

`import Quickshell`

Decorationless window attached to screen edges by anchors.

### Example

The following snippet creates a white bar attached to the bottom of the screen.

`PanelWindow {`
`  anchors {`
`    left: true`
`    bottom: true`
`    right: true`
`  }`
`  Text {`
`    anchors.centerIn: parent`
`    text: "Hello!"`
`  }`
`}`

### Properties

- `focusable`: bool
  - If the panel should accept keyboard focus. Defaults to false.
  - Note: On Wayland this property corresponds to `WlrLayershell.keyboardFocus`.
- `margins`: `[top,right,left,bottom]`
  - `top`: `int`
  - `right`: `int`
  - `left`: `int`
  - `bottom`: `int`
  - Offsets from the sides of the screen.
  - `NOTE`: Only applies to edges with anchors.
- `anchors`: `[left,right,bottom,top]`
  - `left`: bool
  - `right`: bool
  - `bottom`: bool
  - `top`: bool
  - Anchors attach a shell window to the sides of the screen. By default all anchors are disabled to avoid blocking the entire screen due to a misconfiguration.
  - `NOTE`: When two opposite anchors are attached at the same time, the corresponding dimension (width or height) will be forced to equal the screen width/height. Margins can be used to create anchored windows that are also disconnected from the monitor sides.
- `exclusionMode`: `ExclusionMode`
  - Defaults to `ExclusionMode.Auto`.

## PersistentProperties: Reloadable

import Quickshell

PersistentProperties holds properties declared in it across a reload, which is often useful for things like keeping expandable popups open and styling them.

Below is an example of using PersistentProperties to keep track of the state of an expandable panel. When the configuration is reloaded, the `expanderOpen` property will be saved and the expandable panel will stay in the open/closed state.

```qml
PersistentProperties {
  id: persist
  reloadableId: "persistedStates"

  property bool expanderOpen: false
}

Button {
  id: expanderButton
  anchors.centerIn: parent
  text: "toggle expander"
  onClicked: persist.expanderOpen = !persist.expanderOpen
}

Rectangle {
  anchors.top: expanderButton.bottom
  anchors.left: expanderButton.left
  anchors.right: expanderButton.right
  height: 100

  color: "lightblue"
  visible: persist.expanderOpen
}
```

### Signals [?]

### reloaded()

Called every time the properties are reloaded. Will not be called if no old instance was loaded.

### loaded()

Called every time the reload stage completes. Will be called every time, including when nothing was loaded from an old instance.

## PopupWindow: QsWindow

import Quickshell

PopupWindow is a popup that can display in a position relative to a floating or panel window.

### Example

The following snippet creates a panel with a popup centered over it.

```qml
PanelWindow {
  id: toplevel

  anchors {
    bottom: true
    left: true
    right: true
  }

  PopupWindow {
    anchor.window: toplevel
    anchor.rect.x: parentWindow.width / 2 - width / 2
    anchor.rect.y: parentWindow.height
    width: 500
    height: 500
    visible: true
  }
}
```

### Properties

- screen: ShellScreen

  The screen that the window currently occupies. This may be modified to move the window to the given screen.

- visible: bool

  If the window is shown or hidden. Defaults to false.

  The popup will not be shown until a valid `anchor` is set, regardless of this property.

- parentWindow: `QtObject`

  Deprecated in favor of `anchor.window`.

  The parent window of this popup. Changing this property reparents the popup.

- anchor: PopupAnchor

  The popup's anchor/positioner relative to another item or window. The popup will not be shown until it has a valid anchor relative to a window and `visible` is true.

  You can set properties of the anchor like so:

  ```qml
  PopupWindow {
    anchor.window: parentWindow
    // or
    anchor {
      window: parentWindow
    }
  }
  ```

- relativeX: int

  Deprecated in favor of `anchor.rect.x`.

  The X position of the popup relative to the parent window.

- relativeY: int

  Deprecated in favor of `anchor.rect.y`.

  The Y position of the popup relative to the parent window.

## PopupAnchor: `QtObject`

import Quickshell

Anchor point or positioner for popup windows.

### Properties

-- margins: [left,right,top,bottom]

- left: int
- right: int
- top: int
- bottom: int

A margin applied to the anchor rect. This is most useful when `item` is used and `rect` is left at its default value (matching the `Item`'s dimensions).

-- rect: [w,y,h,x,width,height]

- w: int
- y: int
- h: int
- x: int
- width: int
- height: int

The anchor rectangle the popup will attach to, relative to `item` or `window`. Which anchors will be used is determined by `edges`, `gravity`, and `adjustment`.

If using `item`, the default anchor rectangle matches the dimensions of the `item`. If you leave `edges`, `gravity`, and `adjustment` at their default values, setting more than `x` and `y` does not matter. The anchor rect cannot be smaller than 1x1 pixels.

-- gravity: `Edges`

The direction the popup should expand towards, relative to the anchor point. Opposing edges such as `Edges.Left | Edges.Right` are not allowed.

Defaults to `Edges.Bottom | Edges.Right`.

-- window: `QtObject`

The window to anchor/attach the popup to. Setting this property unsets `item`.

-- item: `Item`

The item to anchor/attach the popup to. Setting this property unsets `window`.

The popup's position relative to its parent window is only calculated when it is initially shown (directly before `anchoring()` is emitted), meaning its anchor rectangle will be set relative to the item's position in the window at that time. `updateAnchor()` can be called to update the anchor rectangle if the item's position has changed.

Note: If a more flexible way to position a popup relative to an item is needed, set `window` to the item's parent window, and handle the `anchoring` signal to position the popup relative to the window's contentItem.

-- adjustment: `PopupAdjustment`

The strategy used to adjust the popup's position if it would otherwise not fit on screen, based on the anchor `rect`, preferred `edges`, and `gravity`. See the `PopupAdjustment` documentation for details.

-- edges: `Edges`

The point on the anchor rectangle the popup should anchor to. Opposing edges such as `Edges.Left | Edges.Right` are not allowed.

Defaults to `Edges.Top | Edges.Left`.

### Functions

- updateAnchor(): void

  Update the popup's anchor rect relative to its parent window.

  If anchored to an item, popups' anchors will not automatically follow the item if its position changes. This function can be called to recalculate the anchors.

### Signals [?]

- anchoring()

  Emitted when this anchor is about to be used. Mostly useful for modifying the anchor `rect` using coordinate mapping functions, which are not reactive.

## QsMenuAnchor: `QtObject`

import Quickshell

Display anchor for platform menus.

### Properties

- `anchor`: `PopupAnchor`

  The menu's anchor / positioner relative to another window. The menu will not be shown until it has a valid anchor.

  > NOTE

  > The following is subject to change and NOT a guarantee of future behavior.

  A snapshot of the anchor at the time `opened()` is emitted will be used to position the menu. Additional changes to the anchor after this point will not affect the placement of the menu.

  You can set properties of the anchor like so:

  ```qml
  QsMenuAnchor {
    anchor.window: parentWindow
    // or
    anchor {
      window: parentWindow
    }
  }
  ```

- `menu`: `QsMenuHandle`

  The menu that should be displayed on this anchor.

  See also: `SystemTrayItem.menu`.

- `visible`: `bool`

  If the menu is currently open and visible.

  See also: `open()`, `close()`.

### Functions

- `close()`: `void`

  Close the open menu.

- `open()`: `void`

  Open the given menu on this anchor. Requires that `anchor` is valid.

### Signals [?]

- `closed()`

  Sent when the menu is closed.

- `opened()`

  Sent when the menu is displayed onscreen which may be after `visible` becomes true.

## QsMenuButtonType: `QtObject`

import Quickshell

See `QsMenuEntry.buttonType`.

### Functions

- `toString(value)`: `string`

  - `value`: `QsMenuButtonType`

### Variants

- `CheckBox`

  This menu item should draw a checkbox.

- `None`

  This menu item does not have a checkbox or a radiobutton associated with it.

- `RadioButton`

  This menu item should draw a radiobutton.

## QsMenuEntry: `QsMenuHandle`

import Quickshell

### Properties

- `enabled`: `bool`

- `isSeparator`: `bool`

  If this menu item should be rendered as a separator between other items.

  No other properties have a meaningful value when `isSeparator` is true.

- `checkState`: `unknown`

  The check state of the checkbox or radiobutton if applicable, as a `Qt.CheckState`.

- `icon`: `string`

  URL of the menu item's icon or `""` if it doesn't have one.

  This can be passed to `Image.source` as shown below.

  ```qml
  Image {
    source: menuItem.icon
    // To get the best image quality, set the image source size to the same size
    // as the rendered image.
    sourceSize.width: width
    sourceSize.height: height
  }
  ```

- `text`: `string`

  Text of the menu item.

- `hasChildren`: `bool`

  If this menu item has children that can be accessed through a `QsMenuOpener`.

- `buttonType`: `QsMenuButtonType`

  If this menu item has an associated checkbox or radiobutton.

### Functions

- `display(parentWindow, relativeX, relativeY)`: `void`

  - `parentWindow`: `QtObject`
  - `relativeX`: `int`
  - `relativeY`: `int`

  Display a platform menu at the given location relative to the parent window.

### Signals [?]

- `triggered()`

  Send a trigger/click signal to the menu entry.

## QsMenuOpener: `QtObject`

import Quickshell

Provides access to children of a `QsMenuEntry`.

### Properties

- `menu`: `QsMenuHandle`

  The menu to retrieve children from.

- `children`: `ObjectModel<`QsMenuEntry`>` `[readonly]`

  The children of the given menu.

## QsWindow: Reloadable

import Quickshell

Base class of Quickshell windows

### Attached properties

`QsWindow` can be used as an attached object of anything that subclasses `Item`. It provides the following properties

- `window` - the `QsWindow` object.
- `contentItem` - the `contentItem` property of the window.

`itemPosition()`, `itemRect()`, and `mapFromItem()` can also be called directly on the attached object.

### Properties [?]

- `width`: `int`

  The window's actual width.

  Setting this property is deprecated. Set `implicitWidth` instead.

- `height`: `int`

  The window's actual height.

  Setting this property is deprecated. Set `implicitHeight` instead.

- `visible`: `bool`

  If the window should be shown or hidden. Defaults to true.

- `implicitHeight`: `int`

  The window's desired height.

- `implicitWidth`: `int`

  The window's desired width.

- `contentItem`: `Item` `[readonly]`

  No details provided

- `backingWindowVisible`: `bool` `[readonly]`

  If the window is currently shown. You should generally prefer `visible`.

  This property is useful for ensuring windows spawn in a specific order, and you should not use it in place of `visible`.

- `mask`: `Region`

  The clickthrough mask. Defaults to null.

  If non null then the clickable areas of the window will be determined by the provided region.

  ```qml
  ShellWindow {
    // The mask region is set to `rect`, meaning only `rect` is clickable.
    // All other clicks pass through the window to ones behind it.
    mask: Region { item: rect }

    Rectangle {
      id: rect

      anchors.centerIn: parent
      width: 100
      height: 100
    }
  }
  ```

  If the provided region's intersection mode is `Combine` (the default), then the region will be used as is. Otherwise it will be applied on top of the window region.

  For example, setting the intersection mode to `Xor` will invert the mask and make everything in the mask region not clickable and pass through clicks inside it through the window.

  ```qml
  ShellWindow {
    // The mask region is set to `rect`, but the intersection mode is set to `Xor`.
    // This inverts the mask causing all clicks inside `rect` to be passed to the window
    // behind this one.
    mask: Region { item: rect; intersection: Intersection.Xor }

    Rectangle {
      id: rect

      anchors.centerIn: parent
      width: 100
      height: 100
    }
  }
  ```

- `screen`: `ShellScreen`

  The screen that the window currently occupies.

  This may be modified to move the window to the given screen.

- `data`: list<`QtObject`> `[default]` `[readonly]`

  No details provided

- `devicePixelRatio`: `real` `[readonly]`

  The ratio between logical pixels and monitor pixels.

  Qt's coordinate system works in logical pixels, which equal N monitor pixels depending on scale factor. This property returns the amount of monitor pixels in a logical pixel for the current window.

- `windowTransform`: `QtObject` `[readonly]`

  Opaque property that will receive an update when factors that affect the window's position and transform changed.

  This property is intended to be used to force a binding update, along with map[To|From]Item (which is not reactive).

- `surfaceFormat`: `[opaque]`

  - `opaque`: `bool`

  Set the surface format to request from the system.

  - `opaque` - If the requested surface should be opaque. Opaque windows allow the operating system to avoid drawing things behind them, or blending the window with those behind it, saving power and GPU load. If unset, this property defaults to true if `color` is opaque, or false if not. You should not need to modify this property unless you create a surface that starts opaque and later becomes transparent.

  > NOTE

  > The surface format cannot be changed after the window is created.

- `color`: `color`

  The background color of the window. Defaults to white.

  > WARNING

  > If the window color is opaque before it is made visible, it will not be able to become transparent later unless `surfaceFormat.opaque` is false.

### Functions [?]

- `itemPosition(item)`: `point`

  - `item`: `Item`

  Returns the given Item's position relative to the window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, 0, 0)`

  See also: `Item.mapFromItem()`

- `itemRect(item)`: `rect`

  - `item`: `Item`

  Returns the given Item's geometry relative to the window. Does not update reactively

  Equivalent to calling `window.contentItem.mapFromItem(item, 0, 0, 0, 0)`

  See also: `Item.mapFromItem()`

- `mapFromItem(item, point)`: `point`

  - `item`: `Item`
  - `point`: `point`

  Maps the given point in the coordinate space of `item` to one in the coordinate space of this window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, point)`

- `mapFromItem(item, x, y)`: `point`

  - `item`: `Item`
  - `x`: `real`
  - `y`: `real`

  Maps the given point in the coordinate space of `item` to one in the coordinate space of this window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, x, y)`

- `mapFromItem(item, rect)`: `rect`

  - `item`: `Item`
  - `rect`: `rect`

  Maps the given rect in the coordinate space of `item` to one in the coordinate space of this window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, rect)`

- `mapFromItem(item, x, y, width, height)`: `rect`

  - `item`: `Item`
  - `x`: `real`
  - `y`: `real`
  - `width`: `real`
  - `height`: `real`

  Maps the given rect in the coordinate space of `item` to one in the coordinate space of this window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, x, y, width, height)`

### Signals [?]

- `closed()`

  This signal is emitted when the window is closed by the user, the display server, or an error. It is not emitted when `visible` is set to false.

- `windowConnected()`

  No details provided

- `resourcesLost()`

  This signal is emitted when resources a window depends on to display are lost, or could not be acquired during window creation. The most common trigger for this signal is a lack of VRAM when creating or resizing a window.

  Following this signal, `closed()` will be sent.

## Quickshell: `QtObject`

import Quickshell

### Properties [?]

- `shellDir`: `string` `[readonly]`

  The full path to the root directory of your shell.

  The root directory is the folder containing the entrypoint to your shell, often referred to as `shell.qml`.

- `processId`: `int` `[readonly]`

  Quickshell's process id.

- `stateDir`: `string` `[readonly]`

  The per-shell state directory.

  Usually `~/.local/state/quickshell/by-shell/<shell-id>`

  Can be overridden using `//@ pragma StateDir $BASE/path` in the root qml file, where `$BASE` corresponds to `$XDG_STATE_HOME` (usually `~/.local/state`).

- `configDir`: `string` `[readonly]`

  WARNING

  Deprecated: Renamed to `shellDir` for clarity.

- `cacheDir`: `string` `[readonly]`

  The per-shell cache directory.

  Usually `~/.cache/quickshell/by-shell/<shell-id>`

- `dataDir`: `string` `[readonly]`

  The per-shell data directory.

  Usually `~/.local/share/quickshell/by-shell/<shell-id>`

  Can be overridden using `//@ pragma DataDir $BASE/path` in the root qml file, where `$BASE` corresponds to `$XDG_DATA_HOME` (usually `~/.local/share`).

- `shellRoot`: `string` `[readonly]`

  WARNING

  Deprecated: Renamed to `shellDir` for consistency.

- `workingDirectory`: `string` `[readonly]`

  Quickshell's working directory. Defaults to whereever quickshell was launched from.

- `watchFiles`: `bool` `[readonly]`

  If true then the configuration will be reloaded whenever any files change. Defaults to true.

- `clipboardText`: `string` `[readonly]`

  The system clipboard.

  WARNING

  Under wayland the clipboard will be empty unless a quickshell window is focused.

- `screens`: `list<`ShellScreen`>` `[readonly]`

  All currently connected screens.

  This property updates as connected screens change.

  Reusing a window on every screen

  ```qml
  ShellRoot {
    Variants {
      // See Variants for details
      variants: Quickshell.screens
      PanelWindow {
        property var modelData
        screen: modelData
      }
    }
  }
  ```

### Functions [?]

- `cachePath(path)`: `string`

  - `path`: `string`

  Equivalent to `${Quickshell.cacheDir}/${path}`

- `configPath(path)`: `string`

  - `path`: `string`

  WARNING

  Deprecated: Renamed to `shellPath()` for clarity.

- `dataPath(path)`: `string`

  - `path`: `string`

  Equivalent to `${Quickshell.dataDir}/${path}`

- `env(variable)`: `variant`

  - `variable`: `string`

  Returns the string value of an environment variable or null if it is not set.

- `execDetached(context)`: `void`

  - `context`:

  Launch a process detached from Quickshell.

  The context parameter can either be a list of command arguments or a JS object with the following fields:

  - `command`: A list containing the command and all its arguments. See `Process.command`.
  - `environment`: Changes to make to the process environment. See `Process.environment`.
  - `clearEnvironment`: Removes all variables from the environment if true.
  - `workingDirectory`: The working directory the command should run in.

  WARNING

  This does not run command in a shell. All arguments to the command must be in separate values in the list, e.g. `["echo", "hello"]` and not `["echo hello"]`.

  Additionally, shell scripts must be run by your shell, e.g. `["sh", "script.sh"]` instead of `["script.sh"]` unless the script has a shebang.

  NOTE

  You can use `["sh", "-c", <your command>]` to execute your command with the system shell.

  This function is equivalent to `Process.startDetached()`.

- `iconPath(icon)`: `string`

  - `icon`: `string`

  Returns a string usable for a `Image.source` for a given system icon.

  NOTE

  By default, icons are loaded from the theme selected by the qt platform theme, which means they should match with all other qt applications on your system.

  If you want to use a different icon theme, you can put `//@ pragma IconTheme <name>` at the top of your root config file or set the `QS_ICON_THEME` variable to the name of your icon theme.

- `iconPath(icon, check)`: `string`

  - `icon`: `string`
  - `check`: `bool`

  Setting the `check` parameter of `iconPath` to true will return an empty string if the icon does not exist, instead of an image showing a missing texture.

- `iconPath(icon, fallback)`: `string`

  - `icon`: `string`
  - `fallback`: `string`

  Setting the `fallback` parameter of `iconPath` will attempt to load the fallback icon if the requested one could not be loaded.

- `inhibitReloadPopup()`: `void`

  When called from `reloadCompleted()` or `reloadFailed()`, prevents the default reload popup from displaying.

  The popup can also be blocked by setting `QS_NO_RELOAD_POPUP=1`.

- `reload(hard)`: `void`

  - `hard`: `bool`

  Reload the shell.

  `hard` - perform a hard reload. If this is false, Quickshell will attempt to reuse windows that already exist. If true windows will be recreated.

  See `Reloadable` for more information on what can be reloaded and how.

- `statePath(path)`: `string`

  - `path`: `string`

  Equivalent to `${Quickshell.stateDir}/${path}`

### Signals [?]

- `reloadFailed(errorString)`

  - `errorString`: `string`

  The reload sequence has failed.

- `lastWindowClosed()`

  Sent when the last window is closed.

  To make the application exit when the last window is closed run `Qt.quit()`.

- `reloadCompleted()`

  The reload sequence has completed successfully.

## Retainable: `QtObject`

import Quickshell

`Retainable` works as an attached property that allows objects to be kept around (retained) after they would normally be destroyed, which is especially useful for things like exit transitions.

An object that is retainable will have `Retainable` as an attached property. All retainable objects will say that they are retainable on their respective typeinfo pages.

> NOTE

> Working directly with `Retainable` is often overly complicated and error prone. For this reason `RetainableLock` should usually be used instead.

### Properties [?]

- `retained`: `bool` `[readonly]`

  If the object is currently in a retained state.

### Functions [?]

- `forceUnlock()`: `void`

  Forcibly remove all locks, destroying the object.

  `unlock()` should usually be preferred.

- `lock()`: `void`

  Hold a lock on the object so it cannot be destroyed.

  A counter is used to ensure you can lock the object from multiple places and it will not be unlocked until the same number of unlocks as locks have occurred.

  WARNING

  It is easy to forget to unlock a locked object. Doing so will create what is effectively a memory leak. Using `RetainableLock` is recommended as it will help avoid this scenario and make misuse more obvious.

- `unlock()`: `void`

  Remove a lock on the object. See `lock()` for more information.

### Signals [?]

- `aboutToDestroy()`

  This signal is sent immediately before the object is destroyed. At this point destruction cannot be interrupted.

- `dropped()`

  This signal is sent when the object would normally be destroyed.

  If all signal handlers return and no locks are in place, the object will be destroyed. If at least one lock is present the object will be retained until all are removed.

## RetainableLock: `QtObject`

import Quickshell

A `RetainableLock` provides extra safety and ease of use for locking `Retainable` objects. A retainable object can be locked by multiple locks at once, and each lock re-exposes relevant properties of the retained objects.

Example

The code below will keep a retainable object alive for as long as the RetainableLock exists.

```qml
RetainableLock {
  object: aRetainableObject
  locked: true
}
```

### Properties [?]

- `locked`: `bool`

  If the object should be locked.

- `object`: `QtObject`

  The object to lock. Must be `Retainable`.

- `retained`: `bool` `[readonly]`

  If the object is currently in a retained state.

### Signals [?]

- `aboutToDestroy()`

  Rebroadcast of the object's `Retainable.aboutToDestroy()`.

- `dropped()`

  Rebroadcast of the object's `Retainable.dropped()`.

## Scope: `Reloadable`

import Quickshell

Convenience type equivalent to setting `Reloadable.reloadableId` for all children.

Note that this does not work for visible `Item`s (all widgets).

```qml
ShellRoot {
  Variants {
    variants: ...

    Scope {
      // everything in here behaves the same as if it was defined
      // directly in `Variants` reload-wise.
    }
  }
}
```

### Properties [?]

- `children`: `list<QtObject>`

  No details provided

## ShellRoot: `Scope`

import Quickshell

Optional root config element, allowing some settings to be specified inline.

### Properties [?]

- `settings`: `QuickshellSettings` `[readonly]`

  No details provided

## Singleton: `Scope`

import Quickshell

All singletons should inherit from this type.

## Variants: `Reloadable`

import Quickshell

Creates and destroys instances of the given component when the given property changes.

`Variants` is similar to `Repeater` except it is for non `Item` objects, and acts as a reload scope.

Each non duplicate value passed to `model` will create a new instance of `delegate` with a `modelData` property set to that value.

See `Quickshell.screens` for an example of using `Variants` to create copies of a window per screen.

> WARNING

> BUG: Variants currently fails to reload children if the variant set is changed as it is instantiated. (usually due to a mutation during variant creation)

### Properties [?]

- `delegate`: `Component`

  The component to create instances of.

  The delegate should define a `modelData` property that will be populated with a value from the `model`.

- `instances`: `list<`QtObject`>` `[readonly]`

  Current instances of the delegate.

- `model`: `list<variant>`

  The list of sets of properties to create instances with. Each set creates an instance of the component, which are updated when the input sets update.

# Quickshell.Services.SystemTray

## SystemTray (summary)

import Quickshell.Services.SystemTray

Quick reference: referencing the `SystemTray` singleton starts tracking tray icons; use its `items` ObjectModel to iterate icons. Each `SystemTrayItem` exposes:

- `category`: groups like Communications, ApplicationStatus, SystemServices, Hardware — use this to filter by purpose.
- `status`: Active, NeedsAttention, Passive — use this to decide visibility or prominence (e.g., show NeedsAttention immediately).

Use `items` to show/hide or order icons based on `category` and `status`.

## SystemTrayItem: `QtObject`

import Quickshell.Services.SystemTray

A system tray item. Key properties, functions and signals are listed below.

### Properties

- `id`: `string` `[readonly]`  
  Unique name for the application.

- `title`: `string` `[readonly]`  
  Text describing the application.

- `tooltipDescription`: `string` `[readonly]`

- `onlyMenu`: `bool` `[readonly]`  
  True if activation does nothing and the item only provides a menu.

- `hasMenu`: `bool` `[readonly]`  
  True if the item has an associated menu accessible via `display()` or `menu`.

- `tooltipTitle`: `string` `[readonly]`

- `icon`: `string` `[readonly]`  
  Icon source usable as an Image source.

- `menu`: `unknown` `[readonly]`  
  Handle to the associated menu (if any). Can be shown with `QsMenuAnchor` or `QsMenuOpener`.

- `status`: `Status` `[readonly]`

- `category`: `Category` `[readonly]`

### Functions

- `activate(): void`  
  Primary activation (left-click).

- `display(parentWindow, relativeX, relativeY): void`  
  Show the platform menu at the given location.

- `scroll(delta, horizontal): void`  
  Scroll action (e.g., change volume).

- `secondaryActivate(): void`  
  Secondary activation (middle-click).

### Signals

- `ready()`
