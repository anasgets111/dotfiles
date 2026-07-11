pragma Singleton
import QtQml
import Quickshell

// Pure workspace-arrangement math: turns a flat list of normalized Workspaces
// (each { id, idx, focused, populated, output, name }) into the ordered,
// output-grouped Arrangement the Bar's workspace strip renders. Holds no
// compositor knowledge — adapters normalize, this only shapes.
Singleton {
  id: root

  readonly property int _maximumContiguousSlots: 100

  function buildDisplayWorkspaces(sourceWorkspaces: var, activeWorkspaceIndex: int, fillEmptySlots: bool, minimumSlotCount: int): var {
    const normalizedWorkspaces = Array.isArray(sourceWorkspaces) ? sourceWorkspaces : [];

    if (!fillEmptySlots)
      return normalizedWorkspaces.map(workspace => ({
            idx: workspace?.idx ?? -1,
            workspace
          }));

    const workspacesByIndex = new Map(normalizedWorkspaces.filter(workspace => Number.isInteger(workspace?.idx) && workspace.idx > 0).map(workspace => [workspace.idx, workspace]));
    const highestWorkspaceIndex = Array.from(workspacesByIndex.keys()).reduce((highestIndex, workspaceIndex) => Math.max(highestIndex, workspaceIndex), 0);
    const contiguousSlotCount = Math.max(0, Math.min(_maximumContiguousSlots, Math.trunc(Math.max(Number(minimumSlotCount) || 0, Number(activeWorkspaceIndex) || 0, highestWorkspaceIndex))));
    const slotIndexes = new Set(Array.from({
      length: contiguousSlotCount
    }, (_unused, zeroBasedIndex) => zeroBasedIndex + 1));

    for (const workspaceIndex of workspacesByIndex.keys())
      slotIndexes.add(workspaceIndex);
    if (Number.isInteger(activeWorkspaceIndex) && activeWorkspaceIndex > 0)
      slotIndexes.add(activeWorkspaceIndex);

    // ponytail: contiguous empty navigation is capped at 100; arbitrary high
    // IDs stay sparse. Add paging if empty slots above that become navigable.
    return Array.from(slotIndexes).sort((leftIndex, rightIndex) => leftIndex - rightIndex).map(workspaceIndex => {
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
      const outputWorkspaces = (workspacesByOutput.get(outputName) ?? []).sort((leftWorkspace, rightWorkspace) => {
        const indexDifference = leftWorkspace.idx - rightWorkspace.idx;
        if (indexDifference)
          return indexDifference;
        const leftId = Number(leftWorkspace.id);
        const rightId = Number(rightWorkspace.id);
        return Number.isFinite(leftId) && Number.isFinite(rightId) ? leftId - rightId : String(leftWorkspace.id).localeCompare(String(rightWorkspace.id));
      });

      for (const workspace of outputWorkspaces)
        sortedWorkspaces.push(workspace);
      if (sortedWorkspaces.length < validWorkspaces.length)
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

  function _selfCheck(): bool {
    const sparse = buildDisplayWorkspaces([{
      id: 1,
      idx: 1
    }, {
      id: 1000000,
      idx: 1000000
    }], 1000000, true, 1000000);
    if (sparse.length !== _maximumContiguousSlots + 1 || sparse[sparse.length - 1]?.idx !== 1000000)
      return false;
    const contiguous = buildDisplayWorkspaces([{
      id: 15,
      idx: 15
    }], 15, true, 10);
    if (contiguous.length !== 15 || contiguous[14]?.idx !== 15)
      return false;

    const layout = buildLayout([{
      id: 1,
      idx: 1,
      focused: false,
      output: "A"
    }, {
      id: 2,
      idx: 1,
      focused: true,
      output: "B"
    }], "", ["A", "B"]);
    return layout.focusedOutput === "B" && layout.outputsOrder[0] === "B" && layout.groupBoundaries[0] === 1 && layout.workspaces[0]?.id === 2;
  }

  Component.onCompleted: console.assert(_selfCheck(), "WorkspaceArrangement self-check failed")
}
