pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: root

  readonly property string activeSpecial: backend?.activeSpecial ?? ""
  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.WorkspaceImpl : MainService.currentWM === "niri" ? Niri.WorkspaceImpl : null
  readonly property int currentWorkspace: backend?.currentWorkspace ?? -1
  readonly property int currentWorkspaceIndex: backend?.currentWorkspaceIndex ?? -1
  readonly property var displayWorkspaces: root.buildDisplayWorkspaces(workspaces, currentWorkspaceIndex, MainService.currentWM === "hyprland")
  readonly property string focusedOutput: backend?.focusedOutput ?? ""
  readonly property var focusedWorkspace: backend?.focusedWorkspace ?? null
  readonly property var groupBoundaries: backend?.groupBoundaries ?? []
  readonly property var outputsOrder: backend?.outputsOrder ?? []
  readonly property var specialWorkspaces: backend?.specialWorkspaces ?? []
  readonly property var workspaces: backend?.workspaces ?? []

  function buildDisplayWorkspaces(workspaces: var, currentWorkspaceIndex: int, denseSlots: bool, minimumSlotCount = 10): var {
    const normalized = Array.isArray(workspaces) ? workspaces : [];

    if (!denseSlots)
      return normalized.map(ws => ({
            idx: ws?.idx ?? -1,
            workspace: ws
          }));

    const maxIndex = normalized.reduce((maxValue, ws) => Math.max(maxValue, ws?.idx ?? 0), Math.max(minimumSlotCount, currentWorkspaceIndex));
    const workspaceMap = {};

    for (const workspace of normalized)
      workspaceMap[workspace.idx] = workspace;

    return Array.from({
      length: maxIndex
    }, (_, index) => {
      const idx = index + 1;
      const workspace = workspaceMap[idx] ?? null;
      if (workspace)
        return {
          idx,
          workspace
        };

      return {
        idx,
        focused: idx === currentWorkspaceIndex
      };
    });
  }

  function buildLayout(workspaces: var, focusedOutputHint: string, outputOrderHint: var): var {
    const normalized = (Array.isArray(workspaces) ? workspaces : []).filter(ws => (ws?.id ?? 0) > 0);
    const grouped = {};
    const seenOutputs = new Set();
    let focusedWorkspace = null;
    let focusedOutput = focusedOutputHint ?? "";

    for (const workspace of normalized) {
      const outputName = workspace.output ?? "";
      if (!grouped[outputName])
        grouped[outputName] = [];
      grouped[outputName].push(workspace);
      seenOutputs.add(outputName);

      if (workspace.focused) {
        focusedWorkspace = workspace;
        focusedOutput = outputName;
      }
    }

    const hintedOrder = Array.isArray(outputOrderHint) ? outputOrderHint.filter(name => seenOutputs.has(name)) : [];
    const outputsOrder = Array.from(seenOutputs).sort((a, b) => {
      if (focusedOutput) {
        if (a === focusedOutput)
          return -1;
        if (b === focusedOutput)
          return 1;
      }

      const aHint = hintedOrder.indexOf(a);
      const bHint = hintedOrder.indexOf(b);
      if (aHint !== -1 || bHint !== -1)
        return (aHint === -1 ? Number.MAX_SAFE_INTEGER : aHint) - (bHint === -1 ? Number.MAX_SAFE_INTEGER : bHint);

      return a.localeCompare(b);
    });

    const sortedWorkspaces = [];
    const groupBoundaries = [];
    const totalWorkspaces = normalized.length;

    for (const outputName of outputsOrder) {
      const sortedGroup = (grouped[outputName] ?? []).sort((a, b) => {
        if (a.idx !== b.idx)
          return a.idx - b.idx;
        return a.id - b.id;
      });

      for (const workspace of sortedGroup)
        sortedWorkspaces.push(workspace);
      if (sortedWorkspaces.length > 0 && sortedWorkspaces.length < totalWorkspaces)
        groupBoundaries.push(sortedWorkspaces.length);
    }

    return {
      focusedOutput,
      focusedWorkspace,
      groupBoundaries,
      outputsOrder,
      workspaces: sortedWorkspaces
    };
  }

  function focusWorkspace(ws) {
    if (ws)
      backend?.focusWorkspace(ws);
  }

  function focusWorkspaceByIndex(idx) {
    backend?.focusWorkspaceByIndex(idx);
  }

  function toggleSpecial(name) {
    backend?.toggleSpecial(name);
  }
}
