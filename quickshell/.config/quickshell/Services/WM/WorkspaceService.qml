pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: root

  readonly property string activeSpecial: backend?.activeSpecial ?? ""
  readonly property bool ready: backend !== null
  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.WorkspaceImpl : MainService.currentWM === "niri" ? Niri.WorkspaceImpl : null
  readonly property int currentWorkspace: backend?.currentWorkspace ?? -1
  readonly property int currentWorkspaceIndex: backend?.currentWorkspaceIndex ?? -1
  readonly property var displayWorkspaces: root.buildDisplayWorkspaces(workspaces, currentWorkspaceIndex, backend?.fillsEmptyWorkspaceSlots ?? false, 10)
  readonly property string focusedOutput: backend?.focusedOutput ?? ""
  readonly property var focusedWorkspace: backend?.focusedWorkspace ?? null
  readonly property bool fullscreenVisible: backend?.fullscreenVisible ?? false
  readonly property var groupBoundaries: backend?.groupBoundaries ?? []
  readonly property bool hasOverview: backend?.hasOverview ?? false
  readonly property var outputsOrder: backend?.outputsOrder ?? []
  readonly property var specialWorkspaces: backend?.specialWorkspaces ?? []
  readonly property bool supportsSpecialWorkspaces: backend?.supportsSpecialWorkspaces ?? false
  readonly property var workspaces: backend?.workspaces ?? []

  function buildDisplayWorkspaces(sourceWorkspaces: var, activeWorkspaceIndex: int, fillEmptySlots: bool, minimumSlotCount: int): var {
    const normalizedWorkspaces = Array.isArray(sourceWorkspaces) ? sourceWorkspaces : [];

    if (!fillEmptySlots)
      return normalizedWorkspaces.map(workspace => ({
            idx: workspace?.idx ?? -1,
            workspace
          }));

    const slotCount = normalizedWorkspaces.reduce((highestIndex, workspace) => Math.max(highestIndex, workspace?.idx ?? 0), Math.max(minimumSlotCount, activeWorkspaceIndex));
    const workspacesByIndex = new Map(normalizedWorkspaces.map(workspace => [workspace.idx, workspace]));

    return Array.from({
      length: slotCount
    }, (_unused, zeroBasedIndex) => {
      const workspaceIndex = zeroBasedIndex + 1;
      const workspace = workspacesByIndex.get(workspaceIndex) ?? null;
      return workspace ? {
        idx: workspaceIndex,
        workspace
      } : {
        idx: workspaceIndex,
        focused: workspaceIndex === activeWorkspaceIndex
      };
    });
  }

  function buildLayout(sourceWorkspaces: var, focusedOutputHint: string, outputOrderHint: var): var {
    const validWorkspaces = (Array.isArray(sourceWorkspaces) ? sourceWorkspaces : []).filter(workspace => (workspace?.id ?? 0) > 0);
    const workspacesByOutput = new Map();
    let focusedWorkspace = null;
    let focusedOutput = focusedOutputHint ?? "";

    for (const workspace of validWorkspaces) {
      const outputName = workspace.output ?? "";
      if (!workspacesByOutput.has(outputName))
        workspacesByOutput.set(outputName, []);
      workspacesByOutput.get(outputName).push(workspace);

      if (workspace.focused) {
        focusedWorkspace = workspace;
        focusedOutput = outputName;
      }
    }

    const outputNames = Array.from(workspacesByOutput.keys());
    const outputRank = new Map((Array.isArray(outputOrderHint) ? outputOrderHint : []).map((name, index) => [name, index]));
    const outputsOrder = outputNames.sort((leftName, rightName) => {
      if (focusedOutput) {
        if (leftName === focusedOutput)
          return -1;
        if (rightName === focusedOutput)
          return 1;
      }

      const leftRank = outputRank.get(leftName) ?? Number.MAX_SAFE_INTEGER;
      const rightRank = outputRank.get(rightName) ?? Number.MAX_SAFE_INTEGER;

      return leftRank - rightRank || leftName.localeCompare(rightName);
    });

    const sortedWorkspaces = [];
    const groupBoundaries = [];

    for (const outputName of outputsOrder) {
      const outputWorkspaces = (workspacesByOutput.get(outputName) ?? []).sort((leftWorkspace, rightWorkspace) => (leftWorkspace.idx - rightWorkspace.idx) || (leftWorkspace.id - rightWorkspace.id));

      for (const workspace of outputWorkspaces)
        sortedWorkspaces.push(workspace);
      if (sortedWorkspaces.length > 0 && sortedWorkspaces.length < validWorkspaces.length)
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

  function focusWorkspace(workspace: var): void {
    if (workspace)
      backend?.focusWorkspace(workspace);
  }

  function focusWorkspaceByIndex(workspaceIndex: int): void {
    backend?.focusWorkspaceByIndex(workspaceIndex);
  }

  function toggleSpecial(name: string): void {
    backend?.toggleSpecial(name);
  }
}
