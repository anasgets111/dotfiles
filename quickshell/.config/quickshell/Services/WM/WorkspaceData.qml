pragma Singleton

import QtQuick
import Quickshell

Singleton {
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

    return Array.from({length: maxIndex}, (_, index) => {
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
}
