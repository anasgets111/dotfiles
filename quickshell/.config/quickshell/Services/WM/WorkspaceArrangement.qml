pragma Singleton
import QtQml
import Quickshell

// Pure workspace display math. Adapters normalize compositor state; this
// orders it for the shared workspace strip and adds Hyprland's empty slots.
Singleton {
  id: root

  readonly property int _maximumContiguousSlots: 100

  function _selfCheck(): bool {
    const sparse = buildDisplayWorkspaces([
      {
        id: 1,
        idx: 1
      },
      {
        id: 1000000,
        idx: 1000000
      }
    ], 1000000, true, 1000000);
    const ordered = orderWorkspaces([
      {
        id: 1,
        idx: 1,
        focused: false,
        output: "A"
      },
      {
        id: 2,
        idx: 1,
        focused: true,
        output: "B"
      }
    ], "");
    return sparse.length === _maximumContiguousSlots + 1 && sparse[sparse.length - 1]?.idx === 1000000 && ordered[0]?.id === 2;
  }
  function buildDisplayWorkspaces(sourceWorkspaces: var, activeWorkspaceIndex: int, fillEmptySlots: bool, minimumSlotCount: int): var {
    const workspaces = Array.isArray(sourceWorkspaces) ? sourceWorkspaces : [];
    if (!fillEmptySlots)
      return workspaces.map(workspace => ({
            idx: workspace?.idx ?? -1,
            workspace
          }));

    const workspacesByIndex = new Map(workspaces.filter(workspace => Number.isInteger(workspace?.idx) && workspace.idx > 0).map(workspace => [workspace.idx, workspace]));
    const highestWorkspaceIndex = Array.from(workspacesByIndex.keys()).reduce((highest, index) => Math.max(highest, index), 0);
    const slotCount = Math.max(0, Math.min(_maximumContiguousSlots, Math.trunc(Math.max(Number(minimumSlotCount) || 0, Number(activeWorkspaceIndex) || 0, highestWorkspaceIndex))));
    const indexes = new Set(Array.from({
      length: slotCount
    }, (_unused, index) => index + 1));

    for (const index of workspacesByIndex.keys())
      indexes.add(index);
    if (Number.isInteger(activeWorkspaceIndex) && activeWorkspaceIndex > 0)
      indexes.add(activeWorkspaceIndex);

    // ponytail: contiguous empty navigation is capped at 100; arbitrary high
    // IDs stay sparse. Add paging if empty slots above that become navigable.
    return Array.from(indexes).sort((left, right) => left - right).map(index => {
      const workspace = workspacesByIndex.get(index) ?? null;
      return workspace ? {
        idx: index,
        workspace
      } : {
        idx: index,
        focused: index === activeWorkspaceIndex
      };
    });
  }
  function orderWorkspaces(sourceWorkspaces: var, focusedOutputHint: string): var {
    const workspaces = (Array.isArray(sourceWorkspaces) ? sourceWorkspaces : []).filter(workspace => (workspace?.id ?? 0) > 0);
    const byOutput = new Map();
    let focusedOutput = focusedOutputHint ?? "";

    for (const workspace of workspaces) {
      const output = workspace.output ?? "";
      if (!byOutput.has(output))
        byOutput.set(output, []);
      byOutput.get(output).push(workspace);
      if (workspace.focused)
        focusedOutput = output;
    }

    const outputs = Array.from(byOutput.keys()).sort((left, right) => {
      if (left === focusedOutput)
        return -1;
      if (right === focusedOutput)
        return 1;
      return left.localeCompare(right);
    });
    const ordered = [];
    for (const output of outputs)
      for (const workspace of byOutput.get(output).sort((left, right) => left.idx - right.idx))
        ordered.push(workspace);
    return ordered;
  }

  Component.onCompleted: console.assert(_selfCheck(), "WorkspaceArrangement self-check failed")
}
