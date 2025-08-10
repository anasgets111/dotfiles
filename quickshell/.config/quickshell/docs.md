========================
CODE SNIPPETS
========================
TITLE: Install Quickshell on Guix using Channels
DESCRIPTION: This snippet adds the Quickshell source repository as a Guix channel to your channel list. Once added, you can install `quickshell-git` via `guix install` or by including it in your system or home definition.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/install-setup

LANGUAGE: Scheme
CODE:

```
(channel
  (name quickshell)
  (url "https://git.outfoxxed.me/outfoxxed/quickshell")
  (branch "master"))
```

---

TITLE: QML Manual Import Examples
DESCRIPTION: Provides practical examples of various QML import statements, demonstrating how to import modules with and without versions, use namespaces, and import JavaScript files. It highlights the importance of specifying versions for Quickshell modules to prevent breakage across updates.

SOURCE: https://quickshell.outfoxxed.me/docs/configuration/qml-overview

LANGUAGE: QML
CODE:

```
import QtQuick
import QtQuick.Controls 6.0
import Quickshell as QS
import QtQuick.Layouts 6.0 as L
import "jsfile.js" as JsFile
```

---

TITLE: Demonstrate Various QML Import Statement Examples
DESCRIPTION: This collection of examples showcases different QML import statements, including module imports with and without versions, namespaced imports, and JavaScript file imports. These practical examples guide users on correctly referencing external modules and scripts in QML applications.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/qml-language

LANGUAGE: QML
CODE:

```
import QtQuick
import QtQuick.Controls 6.0
import Quickshell as QS
import QtQuick.Layouts 6.0 as L
import "jsfile.js" as JsFile
```

---

TITLE: QML Process Running Loop Example
DESCRIPTION: Demonstrates how to restart a process in a loop using the `onRunningChanged` signal handler, ensuring continuous execution of the process.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Io/Process

LANGUAGE: QML
CODE:

```
Process {
  running: true
  onRunningChanged: if (!running) running = true
}
```

---

TITLE: QML Process clearEnvironment Property Example
DESCRIPTION: Illustrates how to configure the `clearEnvironment` property to manage process environment variables, demonstrating how to add new variables and pass system values.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Io/Process

LANGUAGE: QML
CODE:

```
clearEnvironment: true
environment: ({
  ADDED: "value",
  PASSED_FROM_SYSTEM: null,
})
```

---

TITLE: Install Quickshell on Fedora via COPR
DESCRIPTION: These commands enable the `errornointernet/quickshell` COPR repository and then install Quickshell on Fedora. You can choose between the latest release or the master branch version.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/install-setup

LANGUAGE: Shell
CODE:

```
sudo dnf copr enable errornointernet/quickshell

sudo dnf install quickshell
# or
sudo dnf install quickshell-git
```

---

TITLE: Install Quickshell on Arch Linux via AUR
DESCRIPTION: This command installs Quickshell from the Arch User Repository (AUR) using `yay`. Be aware that Quickshell may break after Qt updates when installed via AUR; reinstalling the package is recommended if a breakage is detected.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/install-setup

LANGUAGE: Shell
CODE:

```
yay -S quickshell
# or
yay -S quickshell-git
```

---

TITLE: QML Process environment Property Example
DESCRIPTION: Shows how to define and modify environment variables for a process using the `environment` property, including adding and removing variables.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Io/Process

LANGUAGE: QML
CODE:

```
environment: ({
  ADDED: "value",
  REMOVED: null,
  "i'm different": "value",
})
```

---

TITLE: Install Quickshell on NixOS using Flakes
DESCRIPTION: This snippet demonstrates how to integrate Quickshell into your NixOS configuration using its embedded flake. It's crucial to ensure `nixpkgs` inputs follow the main `nixpkgs` to prevent dependency mismatches and potential crashes.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/install-setup

LANGUAGE: Nix
CODE:

```
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    quickshell = {
      # add ?ref=<tag> to track a tag
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";

      # THIS IS IMPORTANT
      # Mismatched system dependencies will lead to crashes and other issues.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

---

TITLE: Create Manual Reactive Bindings with Qt.binding
DESCRIPTION: Illustrates how to create reactive bindings manually at runtime using the `Qt.binding` function. The example demonstrates dynamically binding a Text element's content to a Button's pressed state upon the button's first click.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/qml-language

LANGUAGE: QML
CODE:

```
Item {
  Text {
    id: boundText
    text: "not bound to anything"
  }

  Button {
    text: "bind the above text"
    onClicked: {
      if (boundText.text == "not bound to anything") {
        text = "press me";
        boundText.text = Qt.binding(() => `button is pressed: ${this.pressed}`);
      }
    }
  }
}
```

---

TITLE: Utilize Quickshell SystemClock for Time in QML Singleton
DESCRIPTION: This updated `Time.qml` singleton demonstrates a more efficient way to get system time using Quickshell's `SystemClock` library. It shows how to format the `clock.date` using `Qt.formatDateTime` and how to set `precision` for battery optimization. This approach replaces the external `date` command with a native Quickshell integration.

SOURCE: https://quickshell.outfoxxed.me/docs/configuration/intro

LANGUAGE: QML
CODE:

```
// Time.qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root
  // an expression can be broken across multiple lines using {}
  readonly property string time: {
    // The passed format string matches the default output of
    // the `date` command.
    Qt.formatDateTime(clock.date, "ddd MMM d hh:mm:ss AP t yyyy")
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }
}
```

---

TITLE: Quickshell PopupWindow API Reference
DESCRIPTION: Comprehensive API documentation for the Quickshell PopupWindow, detailing its properties, their types, descriptions, and usage examples. Includes information on deprecated properties and their modern alternatives.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell/PopupWindow

LANGUAGE: APIDOC
CODE:

```
PopupWindow Properties:

- Property: anchor
  Type: PopupAnchor (/docs/types/Quickshell/PopupAnchor)
  Readonly: true
  Description: The popup’s anchor / positioner relative to another item or window. The popup will not be shown until it has a valid anchor relative to a window and visible is true.
  Example:
    PopupWindow {
      anchor.window: parentwindow
      // or
      anchor {
        window: parentwindow
      }
    }

- Property: parentWindow
  Type: QtObject (https://doc.qt.io/qt-6/qml-qtqml-qtobject.html)
  Deprecated: true (in favor of anchor.window)
  Description: The parent window of this popup. Changing this property reparents the popup.

- Property: relativeX
  Type: int (https://doc.qt.io/qt-6/qml-int.html)
  Deprecated: true (in favor of anchor.rect.x)
  Description: The X position of the popup relative to the parent window.

- Property: relativeY
  Type: int (https://doc.qt.io/qt-6/qml-int.html)
  Deprecated: true (in favor of anchor.rect.y)
  Description: The Y position of the popup relative to the parent window.

- Property: screen
  Type: ShellScreen (/docs/types/Quickshell/ShellScreen)
  Readonly: true
  Description: The screen that the window currently occupies. This may be modified to move the window to the given screen.

- Property: visible
  Type: bool (https://doc.qt.io/qt-6/qml-bool.html)
  Default: false
  Description: If the window is shown or hidden. The popup will not be shown until anchor is valid, regardless of this property.
```

---

TITLE: Integrate QML Singletons into Application Layouts
DESCRIPTION: This `Bar.qml` example shows how to integrate components that rely on singletons into a larger application structure. It demonstrates that once a singleton is defined, its properties can be used directly within other components, eliminating the need for prop drilling.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/introduction

LANGUAGE: QML
CODE:

```
// Bar.qml
import Quickshell

Scope {
  // no more time object

  Variants {
    model: Quickshell.screens

    PanelWindow {
      property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: 30

      ClockWidget {
        anchors.centerIn: parent

        // no more time binding
      }
    }
  }
}
```

---

TITLE: QML Implicit Imports Example
DESCRIPTION: Illustrates how the QML engine automatically imports types from neighboring files if their names start with an uppercase letter. This simplifies type usage within a directory without explicit import statements.

SOURCE: https://quickshell.outfoxxed.me/docs/configuration/qml-overview

LANGUAGE: Text
CODE:

```
root
|-MyButton.qml
|-shell.qml
```

---

TITLE: Explore Quickshell Modules and Types
DESCRIPTION: This section provides a comprehensive reference to various modules and types available in the Quickshell framework. It includes core components, DBusMenu integrations, Hyprland and I3 window manager interfaces, and I/O utilities. Developers can navigate this list to understand the available APIs and their hierarchical organization.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Services.UPower/UPowerDevice

LANGUAGE: APIDOC
CODE:

```
{
  "Quickshell": [
    "BoundComponent",
    "ColorQuantizer",
    "DesktopAction",
    "DesktopEntries",
    "DesktopEntry",
    "EasingCurve",
    "Edges",
    "ElapsedTimer",
    "ExclusionMode",
    "FloatingWindow",
    "Intersection",
    "LazyLoader",
    "ObjectModel",
    "ObjectRepeater",
    "PanelWindow",
    "PersistentProperties",
    "PopupAdjustment",
    "PopupAnchor",
    "PopupWindow",
    "QsMenuAnchor",
    "QsMenuButtonType",
    "QsMenuEntry",
    "QsMenuHandle",
    "QsMenuOpener",
    "QsWindow",
    "Quickshell",
    "QuickshellSettings",
    "Region",
    "RegionShape",
    "Reloadable",
    "Retainable",
    "RetainableLock",
    "Scope",
    "ScriptModel",
    "ShellRoot",
    "ShellScreen",
    "Singleton",
    "SystemClock",
    "TransformWatcher",
    "Variants"
  ],
  "Quickshell.DBusMenu": [
    "DBusMenuHandle",
    "DBusMenuItem"
  ],
  "Quickshell.Hyprland": [
    "GlobalShortcut",
    "Hyprland",
    "HyprlandEvent",
    "HyprlandFocusGrab",
    "HyprlandMonitor",
    "HyprlandWindow",
    "HyprlandWorkspace"
  ],
  "Quickshell.I3": [
    "I3",
    "I3Event",
    "I3Monitor",
    "I3Workspace"
  ],
  "Quickshell.Io": [
    "DataStream",
    "DataStreamParser",
    "FileView",
    "FileViewAdapter",
    "FileViewError",
    "IpcHandler",
    "JsonAdapter",
    "JsonObject",
    "Process",
    "Socket",
    "SocketServer",
    "SplitParser",
    "StdioCollector"
  ]
}
```

---

TITLE: QML: Create a Basic Quickshell Panel Window
DESCRIPTION: This QML snippet demonstrates creating a simple top-aligned panel window using Quickshell's PanelWindow component. It configures basic anchoring, sets an implicit height, and embeds a Text element to display 'hello world'. This panel automatically reserves screen space.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/introduction

LANGUAGE: QML
CODE:

```
import Quickshell // for PanelWindow
import QtQuick // for Text

PanelWindow {
  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: 30

  Text {
    // center the bar in its parent component (the window)
    anchors.centerIn: parent

    text: "hello world"
  }
}
```

---

TITLE: Quickshell.Hyprland API Reference
DESCRIPTION: Provides API documentation for Quickshell's integration with the Hyprland Wayland compositor. This module offers types for managing global shortcuts, monitoring Hyprland events, and interacting with monitors, windows, and workspaces.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/install-setup

LANGUAGE: APIDOC
CODE:

```
Module: Quickshell.Hyprland

Classes:
  - GlobalShortcut
  - Hyprland
  - HyprlandEvent
  - HyprlandFocusGrab
  - HyprlandMonitor
  - HyprlandWindow
  - HyprlandWorkspace
```

---

TITLE: Quickshell API Type Definitions and Namespace Overview
DESCRIPTION: This section provides a structured overview of the types and interfaces available within the Quickshell framework, organized by their respective namespaces. It details the core components for system services, Wayland interactions, and UI elements, serving as a foundational guide for developers.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Io/JsonAdapter

LANGUAGE: APIDOC
CODE:

```
{
  "Quickshell": {
    "Services": {
      "Notifications": {
        "types": [
          "Notification",
          "NotificationAction",
          "NotificationCloseReason",
          "NotificationServer",
          "NotificationUrgency"
        ]
      },
      "Pam": {
        "types": [
          "PamContext",
          "PamError",
          "PamResult"
        ]
      },
      "Pipewire": {
        "types": [
          "Pipewire",
          "PwAudioChannel",
          "PwLink",
          "PwLinkGroup",
          "PwLinkState",
          "PwNode",
          "PwNodeAudio",
          "PwNodeLinkTracker",
          "PwNodeType",
          "PwObjectTracker"
        ]
      },
      "SystemTray": {
        "types": [
          "Category",
          "Status",
          "SystemTray",
          "SystemTrayItem"
        ]
      },
      "UPower": {
        "types": [
          "PerformanceDegradationReason",
          "PowerProfile",
          "PowerProfiles",
          "UPower",
          "UPowerDevice",
          "UPowerDeviceState",
          "UPowerDeviceType"
        ]
      }
    },
    "Wayland": {
      "types": [
        "ScreencopyView",
        "Toplevel",
        "ToplevelManager",
        "WlSessionLock",
        "WlSessionLockSurface",
        "WlrKeyboardFocus",
        "WlrLayer",
        "WlrLayershell"
      ]
    },
    "Widgets": {
      "types": [
        "ClippingRectangle",
        "ClippingWrapperRectangle",
        "IconImage",
        "MarginWrapperManager",
        "WrapperItem",
        "WrapperManager",
        "WrapperMouseArea",
        "WrapperRectangle"
      ]
    }
  }
}
```

---

TITLE: QML: Example Component for BoundComponent
DESCRIPTION: This QML snippet defines a simple MouseArea component with a Rectangle that changes color based on a required property. It serves as an example of a component that could be loaded by a BoundComponent.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell/BoundComponent

LANGUAGE: QML
CODE:

```
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

---

TITLE: Quickshell Singleton API Documentation
DESCRIPTION: Detailed API reference for the Quickshell singleton, outlining its properties and methods. This includes access to shell-specific directories, system clipboard, process information, and utility functions for path resolution, environment variables, and icon management.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell/Quickshell

LANGUAGE: APIDOC
CODE:

```
{
  "class": "Quickshell",
  "type": "singleton",
  "inherits": "QtObject",
  "import": "Quickshell",
  "description": "The Quickshell singleton provides access to shell-specific directories, system information, and utility functions within a QML application.",
  "properties": [
    {
      "name": "cacheDir",
      "type": "string",
      "access": "readonly",
      "description": "The per-shell cache directory. Usually ~/.cache/quickshell/by-shell/<shell-id>"
    },
    {
      "name": "clipboardText",
      "type": "string",
      "description": "The system clipboard. WARNING: Under wayland the clipboard will be empty unless a quickshell window is focused."
    },
    {
      "name": "dataDir",
      "type": "string",
      "access": "readonly",
      "description": "The per-shell data directory. Usually ~/.local/share/quickshell/by-shell/<shell-id>. Can be overridden using //@ pragma DataDir $BASE/path in the root qml file, where $BASE corresponds to $XDG_DATA_HOME (usually ~/.local/share)."
    },
    {
      "name": "processId",
      "type": "int",
      "access": "readonly",
      "description": "Quickshell’s process id."
    },
    {
      "name": "screens",
      "type": "list<ShellScreen>",
      "access": "readonly",
      "description": "All currently connected screens. This property updates as connected screens change."
    },
    {
      "name": "shellRoot",
      "type": "string",
      "access": "readonly",
      "description": "The full path to the root directory of your shell. The root directory is the folder containing the entrypoint to your shell, often referred to as shell.qml."
    },
    {
      "name": "stateDir",
      "type": "string",
      "access": "readonly",
      "description": "The per-shell state directory. Usually ~/.local/state/quickshell/by-shell/<shell-id>. Can be overridden using //@ pragma StateDir $BASE/path in the root qml file, where $BASE corresponds to $XDG_STATE_HOME (usually ~/.local/state)."
    },
    {
      "name": "watchFiles",
      "type": "bool",
      "description": "If true then the configuration will be reloaded whenever any files change. Defaults to true."
    },
    {
      "name": "workingDirectory",
      "type": "string",
      "description": "Quickshell’s working directory. Defaults to whereever quickshell was launched from."
    }
  ],
  "methods": [
    {
      "name": "cachePath",
      "parameters": [
        {"name": "path", "type": "string"}
      ],
      "return_type": "string",
      "description": "Equivalent to ${Quickshell.cacheDir}/${path}"
    },
    {
      "name": "dataPath",
      "parameters": [
        {"name": "path", "type": "string"}
      ],
      "return_type": "string",
      "description": "Equivalent to ${Quickshell.dataDir}/${path}"
    },
    {
      "name": "env",
      "parameters": [
        {"name": "variable", "type": "string"}
      ],
      "return_type": "variant",
      "description": "Returns the string value of an environment variable or null if it is not set."
    },
    {
      "name": "iconPath",
      "overloads": [
        {
          "parameters": [
            {"name": "icon", "type": "string"}
          ],
          "return_type": "string",
          "description": "Returns a string usable for a Image.source for a given system icon. NOTE: By default, icons are loaded from the theme selected by the qt platform theme, which means they should match with all other qt applications on your system. If you want to use a different icon theme, you can put //@ pragma IconTheme <name> at the top of your root config file or set the QS_ICON_THEME variable to the name of your icon theme."
        },
        {
          "parameters": [
            {"name": "icon", "type": "string"},
            {"name": "check", "type": "bool"}
          ],
          "return_type": "string",
          "description": "Setting the check parameter of iconPath to true will return an empty string if the icon does not exist, instead of an image showing a missing texture."
        },
        {
          "parameters": [
            {"name": "icon", "type": "string"},
            {"name": "fallback", "type": "string"}
          ],
          "return_type": "string",
          "description": "Setting the fallback parameter of iconPath will attempt to load the fallback icon if the requested one could not be loaded."
        }
      ]
    },
    {
      "name": "inhibitReloadPopup",
      "parameters": [],
      "return_type": "void",
      "description": "When called from reloadCompleted() or reloadFailed(), prevents the default reload popup from displaying. The popup can also be blocked by setting QS_NO_RELOAD_POPUP=1."
    },
    {
      "name": "reload",
      "parameters": [
        {"name": "hard", "type": "bool"}
      ],
      "return_type": "void",
      "description": "Reload the shell. hard - perform a hard reload. If this is false, Quickshell will attempt to reuse windows that already exist. If true windows will be recreated."
    }
  ]
}
```

---

TITLE: Quickshell Core Types API Reference
DESCRIPTION: Provides API documentation for core Quickshell types, including classes for UI components, timers, system interactions, and general utility objects. These types form the foundation for building Quickshell applications and custom shells.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/install-setup

LANGUAGE: APIDOC
CODE:

```
Module: Quickshell

Classes:
  - BoundComponent
  - ColorQuantizer
  - DesktopAction
  - DesktopEntries
  - DesktopEntry
  - EasingCurve
  - Edges
  - ElapsedTimer
  - ExclusionMode
  - FloatingWindow
  - Intersection
  - LazyLoader
  - ObjectModel
  - ObjectRepeater
  - PanelWindow
  - PersistentProperties
  - PopupAdjustment
  - PopupAnchor
  - PopupWindow
  - QsMenuAnchor
  - QsMenuButtonType
  - QsMenuEntry
  - QsMenuHandle
  - QsMenuOpener
  - QsWindow
  - Quickshell
  - QuickshellSettings
  - Region
  - RegionShape
  - Reloadable
  - Retainable
  - RetainableLock
  - Scope
  - ScriptModel
  - ShellRoot
  - ShellScreen
  - Singleton
  - SystemClock
  - TransformWatcher
  - Variants
```

---

TITLE: Example: Implement a Wayland Session Lock with QML
DESCRIPTION: This QML snippet demonstrates how to create a Wayland session lock using WlSessionLock. It utilizes WlSessionLockSurface to display a button that, when clicked, sets the 'locked' property to false, thereby unlocking the session. This example highlights the basic interaction with the session lock mechanism.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Wayland/WlSessionLock

LANGUAGE: QML
CODE:

```
WlSessionLock {
  id: lock

  WlSessionLockSurface {
    Button {
      text: "unlock me"
      onClicked: lock.locked = false
    }
  }
}

// ...
lock.locked = true
```

---

TITLE: Quickshell Core API Reference
DESCRIPTION: Provides the core functionalities and global properties of the Quickshell environment. This includes methods for application control, system interaction, and access to global settings. It is the primary entry point for most Quickshell operations.

SOURCE: https://quickshell.outfoxxed.me/docs/guide/introduction

LANGUAGE: APIDOC
CODE:

```
class Quickshell {
  // Properties
  readonly property string version;
  readonly property QuickshellSettings settings;
  readonly property ShellRoot root;

  // Methods
  void quit();
  void reloadConfig();
  string getEnv(string name);
  void setEnv(string name, string value);
  void openUrl(string url);

  // Signals
  signal configReloaded();
  signal aboutToQuit();
}
```

---

TITLE: QML Process Object Basic Configuration
DESCRIPTION: Demonstrates a basic QML Process object configuration, showing how to set its running state, command, and handle stdout output using a StdioCollector.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Io/Process

LANGUAGE: QML
CODE:

```
Process {
  running: true
  command: [ "some-command", "arg" ]
  stdout: StdioCollector {
    onStreamFinished: console.log(`line read: ${this.text}`)
  }
}
```

---

TITLE: Quickshell API Module and Component Hierarchy
DESCRIPTION: Comprehensive reference for Quickshell's modular API, detailing available components and sub-modules like DBusMenu and Hyprland. This section outlines the structure of Quickshell's extensible architecture, providing an overview of its various functional areas.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Services.Pipewire/PwAudioChannel

LANGUAGE: APIDOC
CODE:

```
{
  "module": "Quickshell",
  "description": "Core Quickshell module and its primary components, providing foundational functionalities for UI, system interaction, and application management.",
  "types": [
    {"name": "BoundComponent", "description": "Represents a UI component that is bound to data or logic."},
    {"name": "ColorQuantizer", "description": "Utility for reducing the number of distinct colors in an image or palette."},
    {"name": "DesktopAction", "description": "Defines an action associated with a desktop entry."},
    {"name": "DesktopEntries", "description": "Manages a collection of desktop entries."},
    {"name": "DesktopEntry", "description": "Represents a single desktop application entry."},
    {"name": "EasingCurve", "description": "Defines a curve for animation easing."},
    {"name": "Edges", "description": "Represents the edges of a geometric shape or region."},
    {"name": "ElapsedTimer", "description": "Provides a high-resolution timer for measuring elapsed time."},
    {"name": "ExclusionMode", "description": "Defines modes for excluding certain areas or elements."},
    {"name": "FloatingWindow", "description": "Represents a window that floats above others."},
    {"name": "Intersection", "description": "Defines the intersection of two geometric shapes."},
    {"name": "LazyLoader", "description": "A component for deferring the loading of resources until they are needed."},
    {"name": "ObjectModel", "description": "A model for managing collections of objects."},
    {"name": "ObjectRepeater", "description": "Repeats a given object or component multiple times."},
    {"name": "PanelWindow", "description": "Represents a panel-style window, typically docked."},
    {"name": "PersistentProperties", "description": "Manages properties that persist across sessions."},
    {"name": "PopupAdjustment", "description": "Defines adjustments for popup window positioning."},
    {"name": "PopupAnchor", "description": "Specifies an anchor point for popup windows."},
    {"name": "PopupWindow", "description": "Represents a transient popup window."},
    {"name": "QsMenuAnchor", "description": "Anchor point for Quickshell menus."},
    {"name": "QsMenuButtonType", "description": "Defines types of buttons within Quickshell menus."},
    {"name": "QsMenuEntry", "description": "Represents an entry in a Quickshell menu."},
    {"name": "QsMenuHandle", "description": "Handle for a Quickshell menu."},
    {"name": "QsMenuOpener", "description": "Component responsible for opening Quickshell menus."},
    {"name": "QsWindow", "description": "Base class for Quickshell windows."},
    {"name": "Quickshell", "description": "The main Quickshell application object."},
    {"name": "QuickshellSettings", "description": "Manages application-wide settings for Quickshell."},
    {"name": "Region", "description": "Defines a geometric region."},
    {"name": "RegionShape", "description": "Defines the shape of a region."},
    {"name": "Reloadable", "description": "Interface for components that can be reloaded."},
    {"name": "Retainable", "description": "Interface for objects that can be retained to prevent garbage collection."},
    {"name": "RetainableLock", "description": "A lock mechanism for retainable objects."},
    {"name": "Scope", "description": "Defines a scope for variables or components."},
    {"name": "ScriptModel", "description": "A model that can execute scripts."},
    {"name": "ShellRoot", "description": "The root component of the Quickshell environment."},
    {"name": "ShellScreen", "description": "Represents a display screen in the shell environment."},
    {"name": "Singleton", "description": "A class or component designed to have only one instance."},
    {"name": "SystemClock", "description": "Provides access to system time and clock functionalities."},
    {"name": "TransformWatcher", "description": "Monitors changes in transformations."},
    {"name": "Variants", "description": "A collection of various utility variant types."}
  ],
  "submodules": [
    {
      "module": "Quickshell.DBusMenu",
      "description": "Module for integrating with DBus menus, allowing Quickshell to interact with and display menus exposed via DBus.",
      "types": [
        {"name": "DBusMenuHandle", "description": "A handle for managing a DBus menu instance."},
        {"name": "DBusMenuItem", "description": "Represents an individual item within a DBus menu."}
      ]
    },
    {
      "module": "Quickshell.Hyprland",
      "description": "Module for integrating Quickshell with the Hyprland Wayland compositor, providing specific functionalities related to Hyprland's features.",
      "types": []
    }
  ]
}
```

---

TITLE: QML Document Structure Example
DESCRIPTION: Illustrates the fundamental syntax of a QML document, including imports, object declarations, property assignments, signal declarations, and function definitions. Semicolons are permitted and recommended in functions and expressions; explicit type declarations are advised for early problem detection.

SOURCE: https://quickshell.outfoxxed.me/docs/configuration/qml-overview

LANGUAGE: QML
CODE:

```
// QML Import statement
import QtQuick 6.0

// Javascript import statement
import "myjs.js" as MyJs

// Root Object
Item {
  // Id assignment

  id: root
  // Property declaration
  property int myProp: 5;

  // Property binding
  width: 100

  // Property binding
  height: width

  // Multiline property binding
  prop: {
    // ...
    5
  }

  // Object assigned to a property
  objProp: Object {
    // ...
  }

  // Object assigned to the parent's default property
  AnotherObject {
    // ...
  }

  // Signal declaration
  signal foo(bar: int)

  // Signal handler
  onSignal: console.log("received signal!")

  // Property change signal handler
  onWidthChanged: console.log(`width is now ${width}!`)

  // Multiline signal handler
  onOtherSignal: {
    console.log("received other signal!");
    console.log(`5 * 2 is ${dub(5)}`);
    // ...
  }

  // Attached property signal handler
  Component.onCompleted: MyJs.myfunction()

  // Function
  function dub(x: int): int {
    return x * 2
  }

  // Inline component
  component MyComponent: Object {
    // ...
  }
}
```

---

TITLE: Integrate with Quickshell.Services API Modules
DESCRIPTION: This section provides a comprehensive overview of the various service-specific modules within Quickshell.Services. It covers interactions with Greetd, MPRIS, Notifications, PAM, Pipewire, System Tray, and UPower, enabling robust system-level integrations.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Services.Mpris/MprisPlayer

LANGUAGE: APIDOC
CODE:

```
Module: Quickshell.Services
  Description: Contains sub-modules for interacting with various system services.

  Sub-Module: Quickshell.Services.Greetd
    Description: Provides types for interacting with the Greetd display manager.
    Types:
      Greetd: Main interface for Greetd service operations.
      GreetdState: Represents the current state of the Greetd service.

  Sub-Module: Quickshell.Services.Mpris
    Description: Provides types for interacting with MPRIS (Media Player Remote Interfacing Specification) compatible media players.
    Types:
      Mpris: Main interface for MPRIS service operations.
      MprisLoopState: Defines the playback loop state of an MPRIS player.
      MprisPlaybackState: Defines the playback state of an MPRIS player.
      MprisPlayer: Represents an MPRIS media player.

  Sub-Module: Quickshell.Services.Notifications
    Description: Provides types for interacting with the Freedesktop.org Desktop Notifications Specification.
    Types:
      Notification: Represents a desktop notification.
      NotificationAction: Defines an action associated with a notification.
      NotificationCloseReason: Specifies the reason a notification was closed.
      NotificationServer: Manages the notification server.
      NotificationUrgency: Defines the urgency level of a notification.

  Sub-Module: Quickshell.Services.Pam
    Description: Provides types for interacting with PAM (Pluggable Authentication Modules).
    Types:
      PamContext: Represents a PAM authentication context.
      PamError: Defines errors returned by PAM operations.
      PamResult: Represents the result of a PAM operation.

  Sub-Module: Quickshell.Services.Pipewire
    Description: Provides types for interacting with the Pipewire multimedia server.
    Types:
      Pipewire: Main interface for Pipewire service operations.
      PwAudioChannel: Represents an audio channel in Pipewire.
      PwLink: Represents a link between Pipewire nodes.
      PwLinkGroup: Groups related Pipewire links.
      PwLinkState: Defines the state of a Pipewire link.
      PwNode: Represents a node in the Pipewire graph.
      PwNodeAudio: Represents an audio-specific Pipewire node.
      PwNodeLinkTracker: Tracks links associated with a Pipewire node.
      PwNodeType: Defines the type of a Pipewire node.
      PwObjectTracker: Tracks various Pipewire objects.

  Sub-Module: Quickshell.Services.SystemTray
    Description: Provides types for interacting with the Freedesktop.org System Tray Specification.
    Types:
      Category: Defines the category of a system tray item.
      Status: Defines the status of a system tray item.
      SystemTray: Main interface for System Tray service operations.
      SystemTrayItem: Represents an item in the system tray.

  Sub-Module: Quickshell.Services.UPower
    Description: Provides types for interacting with the UPower D-Bus service for power management.
    Types:
      PerformanceDegradationReason: Specifies reasons for performance degradation.
      PowerProfile: Represents a power profile.
      PowerProfiles: Manages available power profiles.
      UPower: Main interface for UPower service operations.
      UPowerDevice: Represents a power device (e.g., battery, AC adapter).
      UPowerDeviceState: Defines the state of a UPower device.
      UPowerDeviceType: Defines the type of a UPower device.
```

---

TITLE: Integrate QML Singletons into Application Layouts
DESCRIPTION: The `Bar.qml` example demonstrates how to integrate components that rely on singletons into a larger application structure. By removing the explicit `time` object, the `ClockWidget` can be directly instantiated within the `PanelWindow`, simplifying the overall layout and leveraging the global accessibility of the `Time` singleton.

SOURCE: https://quickshell.outfoxxed.me/docs/configuration/intro

LANGUAGE: QML
CODE:

```
// Bar.qml
import Quickshell

Scope {
  // no more time object

  Variants {
    model: Quickshell.screens

    PanelWindow {
      property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: 30

      ClockWidget {
        anchors.centerIn: parent

        // no more time binding
      }
    }
  }
}
```

---

TITLE: Assign Functions and Lambdas to QML Properties
DESCRIPTION: Learn how to assign both traditional functions and concise lambda expressions to properties in QML. This example illustrates assigning a doubling operation, showcasing the flexibility of function as values.

SOURCE: https://quickshell.outfoxxed.me/docs/configuration/qml-overview

LANGUAGE: QML
CODE:

```
Item {
  // using functions
  function dub(number: int): int { return number * 2; }
  property var operation: dub

  // using lambdas
  property var operation: number => number * 2
}
```

---

TITLE: Create Basic Quickshell Panel Window with QML
DESCRIPTION: This QML snippet demonstrates how to define a simple top-anchored panel window using Quickshell's "PanelWindow" type. It imports "Quickshell" and "QtQuick" to create a fixed-height bar containing a centered 'hello world' "Text" element. The window automatically reserves screen space.

SOURCE: https://quickshell.outfoxxed.me/docs/configuration/intro

LANGUAGE: QML
CODE:

```
import Quickshell // for PanelWindow
import QtQuick // for Text

PanelWindow {
  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: 30

  Text {
    // center the bar in its parent component (the window)
    anchors.centerIn: parent

    text: "hello world"
  }
}
```

---

TITLE: Implement QML Functions with Reactivity
DESCRIPTION: Explore how QML functions are invoked within expressions and their reactive behavior. This example demonstrates a click counter where changes to a property trigger re-evaluation of expressions dependent on a function.

SOURCE: https://quickshell.outfoxxed.me/docs/configuration/qml-overview

LANGUAGE: QML
CODE:

```
ColumnLayout {
  property int clicks: 0

  function makeClicksLabel(): string {
    return "the button has been clicked " + clicks + " times!";
  }

  Button {
    text: "click me"
    onClicked: clicks += 1
  }

  Text {
    text: makeClicksLabel()
  }
}
```

---

TITLE: QML: Example Usage of RetainableLock
DESCRIPTION: This snippet demonstrates how to instantiate and use a `RetainableLock` object in QML. It shows how to associate a `Retainable` object and set the `locked` property to true, ensuring the object remains alive.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell/RetainableLock

LANGUAGE: QML
CODE:

```
RetainableLock {
  object: aRetainableObject
  locked: true
}
```

---

TITLE: Quickshell API: Services.Greetd Namespace Types
DESCRIPTION: Lists types and classes available under the 'Quickshell.Services.Greetd' namespace, facilitating integration with the Greetd display manager. Detailed API specifications for each type are available via their respective documentation links.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Hyprland/HyprlandEvent

LANGUAGE: APIDOC
CODE:

```
undefined
```

---

TITLE: Quickshell Base API Types Overview
DESCRIPTION: Comprehensive list of core Quickshell API types, covering components, UI elements, system interactions, and utility classes. These types form the foundational building blocks for developing and extending Quickshell applications.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Services.Greetd/GreetdState

LANGUAGE: APIDOC
CODE:

```
{
  "namespace": "Quickshell",
  "types": [
    "BoundComponent",
    "ColorQuantizer",
    "DesktopAction",
    "DesktopEntries",
    "DesktopEntry",
    "EasingCurve",
    "Edges",
    "ElapsedTimer",
    "ExclusionMode",
    "FloatingWindow",
    "Intersection",
    "LazyLoader",
    "ObjectModel",
    "ObjectRepeater",
    "PanelWindow",
    "PersistentProperties",
    "PopupAdjustment",
    "PopupAnchor",
    "PopupWindow",
    "QsMenuAnchor",
    "QsMenuButtonType",
    "QsMenuEntry",
    "QsMenuHandle",
    "QsMenuOpener",
    "QsWindow",
    "Quickshell",
    "QuickshellSettings",
    "Region",
    "RegionShape",
    "Reloadable",
    "Retainable",
    "RetainableLock",
    "Scope",
    "ScriptModel",
    "ShellRoot",
    "ShellScreen",
    "Singleton",
    "SystemClock",
    "TransformWatcher",
    "Variants"
  ]
}
```

---

TITLE: Quickshell Framework Type Definitions
DESCRIPTION: This section outlines the various data types and service interfaces provided by the Quickshell framework. It serves as a guide for developers to understand the available components and their organization within different namespaces.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Wayland/WlSessionLock

LANGUAGE: APIDOC
CODE:

```
Quickshell.Services.Notifications:
  - Notification
  - NotificationAction
  - NotificationCloseReason
  - NotificationServer
  - NotificationUrgency

Quickshell.Services.Pam:
  - PamContext
  - PamError
  - PamResult

Quickshell.Services.Pipewire:
  - Pipewire
  - PwAudioChannel
  - PwLink
  - PwLinkGroup
  - PwLinkState
  - PwNode
  - PwNodeAudio
  - PwNodeLinkTracker
  - PwNodeType
  - PwObjectTracker

Quickshell.Services.SystemTray:
  - Category
  - Status
  - SystemTray
  - SystemTrayItem

Quickshell.Services.UPower:
  - PerformanceDegradationReason
  - PowerProfile
  - PowerProfiles
  - UPower
  - UPowerDevice
  - UPowerDeviceState
  - UPowerDeviceType

Quickshell.Wayland:
  - ScreencopyView
  - Toplevel
  - ToplevelManager
  - WlSessionLock
  - WlSessionLockSurface
  - WlrKeyboardFocus
  - WlrLayer
  - WlrLayershell

Quickshell.Widgets:
  - ClippingRectangle
  - ClippingWrapperRectangle
  - IconImage
  - MarginWrapperManager
  - WrapperItem
  - WrapperManager
  - WrapperMouseArea
  - WrapperRectangle
```

---

TITLE: Quickshell.Services.SystemTray API Reference
DESCRIPTION: Provides API documentation for the Quickshell SystemTray service, detailing its available types for managing system tray items.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Hyprland/GlobalShortcut

LANGUAGE: APIDOC
CODE:

```
Quickshell.Services.SystemTray Module
--------------------------------------
Available Types:
- Category
- Status
- SystemTray
- SystemTrayItem
```

---

TITLE: Quickshell.Services.SystemTray: Category Type Reference
DESCRIPTION: Defines the category of a System Tray item, such as 'ApplicationStatus', 'HardwareStatus', or 'Communications'. This enumeration helps classify the purpose of an icon in the system tray. It guides the display and organization of tray items.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Services.UPower/UPowerDeviceType

LANGUAGE: APIDOC
CODE:

```
enum Category {
  APPLICATION_STATUS = "ApplicationStatus",
  HARDWARE_STATUS = "HardwareStatus",
  COMMUNICATIONS = "Communications",
  OTHER = "Other"
}
```

---

TITLE: QML: Displaying SystemClock Time
DESCRIPTION: This QML snippet demonstrates how to instantiate a SystemClock component and display its current time, formatted using Qt.formatDateTime(). It shows a basic setup for integrating the clock into a UI.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell/SystemClock

LANGUAGE: QML
CODE:

```
SystemClock {
  id: clock
  precision: SystemClock.Seconds
}

Text {
  text: Qt.formatDateTime(clock.date, "hh:mm:ss - yyyy-MM-dd")
}
```

---

TITLE: QML: Reusing a Window on Every Screen with Quickshell
DESCRIPTION: This QML snippet demonstrates how to create and manage a window instance on every connected screen using the Quickshell.screens property and a Variants component. As screens are added or removed, the corresponding window instances are dynamically created or destroyed, ensuring consistent UI across multiple displays.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell/Quickshell

LANGUAGE: QML
CODE:

```
ShellRoot {
  Variants {
    // see Variants for details
    variants: Quickshell.screens
    PanelWindow {
      property var modelData
      screen: modelData
    }
  }
}
```

---

TITLE: QML Example: Implement HyprlandFocusGrab for Popup Dismissal
DESCRIPTION: This QML snippet demonstrates how to use `HyprlandFocusGrab` to manage input focus for a `FloatingWindow`. It shows how to activate/deactivate the grab and whitelist the window to retain focus, useful for implementing dismissible popups.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Hyprland/HyprlandFocusGrab

LANGUAGE: QML
CODE:

```
import Quickshell
import Quickshell.Hyprland
import QtQuick.Controls

ShellRoot {
  FloatingWindow {
    id: window

    Button {
      anchors.centerIn: parent
      text: grab.active ? "Remove exclusive focus" : "Take exclusive focus"
      onClicked: grab.active = !grab.active
    }

    HyprlandFocusGrab {
      id: grab
      windows: [ window ]
    }
  }
}
```

---

TITLE: Quickshell API: parse Function Definition
DESCRIPTION: Defines the 'parse' function within the Quickshell API. This function is responsible for parsing specific data structures or inputs. Refer to the full documentation for detailed parameters, return types, and examples.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Hyprland/HyprlandEvent

LANGUAGE: APIDOC
CODE:

```
function parse(
  // parameters: type, description
) : ReturnType {
  // Function implementation details and full signature in documentation
}
```

---

TITLE: Quickshell.Services.Greetd Module API Reference
DESCRIPTION: API documentation for the Quickshell.Services.Greetd module, providing types for integration with the Greetd display manager. This includes classes for managing Greetd state and interactions.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Widgets/ClippingWrapperRectangle

LANGUAGE: APIDOC
CODE:

```
class Greetd {}
class GreetdState {}
```

---

TITLE: QML: Asynchronously Load PopupWindow with LazyLoader
DESCRIPTION: This QML example demonstrates how to asynchronously load a PopupWindow using a LazyLoader component. It allows the main UI bar to load before the popup is fully ready, preventing UI thread blocking unless the popup is accessed before completion. The LazyLoader manages the background loading, and accessing popupLoader.item forces immediate completion.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell/LazyLoader

LANGUAGE: QML
CODE:

```
import QtQuick
import QtQuick.Controls
import Quickshell

ShellRoot {
  PanelWindow {
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
      // frame time unless active is set to true, where it will be
      // loaded in the foreground
      PopupWindow {
        // position the popup above the button
        parentWindow: window
        relativeX: window.width / 2 - width / 2
        relativeY: -height

        // some heavy component here

        width: 200
        height: 200
      }
    }

    Button {
      anchors.centerIn: parent
      text: "show popup"

      // accessing popupLoader.item will force the loader to
      // finish loading on the UI thread if it isn't finished yet.
      onClicked: popupLoader.item.visible = !popupLoader.item.visible
    }
  }
}
```

---

TITLE: PamContext QML Type API Documentation
DESCRIPTION: This snippet provides the structured API documentation for the PamContext QML type, including its inheritance, import path, properties (active, config, message, etc.), methods (start, abort, respond), and signals (completed, error, pamMessage). It details parameter types, return types, and descriptions for each API member.

SOURCE: https://quickshell.outfoxxed.me/docs/types/Quickshell.Services.Pam/PamContext

LANGUAGE: APIDOC
CODE:

```
{
  "class": "PamContext",
  "inherits": "QtObject",
  "import": "Quickshell.Services.Pam",
  "description": "Connection to pam. See the module documentation for pam configuration advice.",
  "properties": [
    {
      "name": "active",
      "type": "bool",
      "description": "If the pam context is actively performing an authentication. Setting this value behaves exactly the same as calling start() and abort()."
    },
    {
      "name": "config",
      "type": "string",
      "description": "The pam configuration to use. Defaults to “login”. The configuration should name a file inside configDirectory. This property may not be set while active is true."
    },
    {
      "name": "configDirectory",
      "type": "string",
      "description": "The pam configuration directory to use. Defaults to “/etc/pam.d”. The configuration directory is resolved relative to the current file if not an absolute path. This property may not be set while active is true."
    },
    {
      "name": "message",
      "type": "string",
      "description": "The last message sent by pam.",
      "readonly": true
    },
    {
      "name": "messageIsError",
      "type": "bool",
      "description": "If the last message should be shown as an error.",
      "readonly": true
    },
    {
      "name": "responseRequired",
      "type": "bool",
      "description": "If pam currently wants a response. Responses can be returned with the respond() function.",
      "readonly": true
    },
    {
      "name": "responseVisible",
      "type": "bool",
      "description": "If the user’s response should be visible. Only valid when responseRequired is true.",
      "readonly": true
    },
    {
      "name": "user",
      "type": "string",
      "description": "The user to authenticate as. If unset the current user will be used. This property may not be set while active is true."
    }
  ],
  "methods": [
    {
      "name": "abort",
      "parameters": [],
      "returnType": "void",
      "description": "Abort a running authentication session."
    },
    {
      "name": "respond",
      "parameters": [
        {
          "name": "response",
          "type": "string"
        }
      ],
      "returnType": "void",
      "description": "Respond to pam. May not be called unless responseRequired is true."
    },
    {
      "name": "start",
      "parameters": [],
      "returnType": "bool",
      "description": "Start an authentication session. Returns if the session was started successfully."
    }
  ],
  "signals": [
    {
      "name": "completed",
      "parameters": [
        {
          "name": "result",
          "type": "PamResult"
        }
      ],
      "description": "Emitted whenever authentication completes."
    },
    {
      "name": "error",
      "parameters": [
        {
          "name": "error",
          "type": "PamError"
        }
      ],
      "description": "Emitted if pam fails to perform authentication normally. A `completed(PamResult.Error)` will be emitted after this event."
    },
    {
      "name": "pamMessage",
      "parameters": [],
      "description": "Emitted whenever pam sends a new message, after the change signals for `message`, `messageIsError`, and `responseRequired`."
    }
  ]
}
```
