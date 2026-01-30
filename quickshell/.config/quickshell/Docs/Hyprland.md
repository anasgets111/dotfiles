# QUICKSHELL HYPRLAND OBJECT REFERENCE

1. ROOT OBJECT (Singleton: Hyprland)

---

• monitors : Map<String, Monitor> -> Access: Array.from(Hyprland.monitors.values)
• workspaces : Map<int, Workspace> -> Access: Array.from(Hyprland.workspaces.values)
• toplevels : UntypedObjectModel -> Access: Array.from(Hyprland.toplevels.values)
• focusedMonitor : Monitor (nullable)
• focusedWorkspace : Workspace (nullable)
• dispatch(cmd) : Function (Executes Hyprland dispatchers)
• activeWindow : UNDEFINED (Use Events or focusedWorkspace.toplevels)

2. MONITOR OBJECT

---

• id : int
• name : string (e.g., "eDP-1")
• description : string
• x, y : int (Position)
• width, height : int (Resolution)
• scale : double
• focused : bool
• activeWorkspace : Workspace (Object)

3. WORKSPACE OBJECT

---

• id : int (Standard IDs > 0, Special IDs < -1)
• name : string (e.g., "1", "special:vesktop")
• focused : bool
• monitor : Monitor (Object)
• toplevels : Map<address, Window> (CRITICAL: Not an Array)
-> Usage: Array.from(w.toplevels.values)
• lastIpcObject : Object (Raw IPC data backup)
-> .windows : int (Count of windows, useful if Map is empty)

4. WINDOW OBJECT (Wrapper)

---

Found inside workspace.toplevels or Hyprland.toplevels.
• title : string
• address : string (Hex handle)
• monitor : Monitor
• workspace : Workspace
• MISSING DIRECTLY : class, appId, floating, geometry, fullscreen.
(Must use .lastIpcObject for these details)

5. WINDOW IPC OBJECT (.lastIpcObject)

---

The raw data source for window details.
• class : string (e.g., "vesktop", "firefox")
• initialClass : string
• title : string
• floating : bool
• fullscreen : int/bool (0 = false)
• pinned : bool
• xwayland : bool
• pid : int
• at : [x, y]
• size : [width, height]

6. EVENTS (via Connections { target: Hyprland ... })

---

Signal: onRawEvent(event)
• event.name : string
• event.data : string (comma-separated values)

Common Event Signatures:
• openwindow : address, workspaceName, class, title
• activewindow : class, title
• activewindowv2 : address (Hex handle)
• activespecial : workspaceName, monitorName
• activespecialv2 : workspaceId, workspaceName, monitorName
• destroyworkspace : workspaceName
• windowtitle : address
