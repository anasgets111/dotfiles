pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Services.Utils

Singleton {
  id: root

  property string _expression: ""
  property string _resultText: ""
  readonly property string statusLabel: "CALC"
  readonly property string rowBadge: statusLabel
  readonly property string rowHint: qsTr("Enter to copy")
  readonly property string rowIcon: "󰃬"
  readonly property bool rowIconIsText: false
  readonly property string rowSubtitle: qsTr("Calculator")
  readonly property string rowTitle: _expression + " = " + _resultText

  function activate(): void {
    Utils.copyText(_resultText);
  }
  function claims(query: string): bool {
    const input = String(query || "").trim();
    if (!/^[\d\s+\-*/().,%^]+$/.test(input) || !/\d/.test(input) || !/[+\-*/^%]/.test(input) || /^\d+\.?\d*$/.test(input))
      return false;
    try {
      let expr = input.replace(/\^/g, "**");
      expr = expr.replace(/(\d+\.?\d*)%/g, "($1/100)").replace(/[^0-9+\-*/().%\s]/g, "");
      if (!expr.trim())
        return false;
      const value = Function("\"use strict\"; return (" + expr + ");")();
      if (typeof value !== "number" || !Number.isFinite(value))
        return false;
      _expression = input;
      _resultText = Number.isInteger(value) ? value.toLocaleString() : parseFloat(value.toPrecision(12)).toString();
      return true;
    } catch (_) {
      reset();
      return false;
    }
  }
  function reset(): void {
    _expression = "";
    _resultText = "";
  }
}
