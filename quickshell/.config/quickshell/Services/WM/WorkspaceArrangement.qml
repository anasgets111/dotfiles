pragma Singleton
import QtQuick

// Pure workspace-arrangement math: turns a flat list of normalized Workspaces
// (each { id, idx, focused, populated, output, name }) into the ordered,
// output-grouped Arrangement the Bar's workspace strip renders. Holds no
// compositor knowledge — adapters normalize, this only shapes. See CONTEXT.md
// (Workspaces → Workspace, Arrangement).
QtObject {
  id: root

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
}
