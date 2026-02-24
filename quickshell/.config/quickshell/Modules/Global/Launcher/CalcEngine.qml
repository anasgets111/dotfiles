pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Singleton {
  id: root

  property string _expression: ""
  property string _resultText: ""
  readonly property string expression: _expression
  readonly property bool hasResult: _resultText !== ""
  readonly property string resultText: _resultText

  function evaluate(text: string): bool {
    reset();
    const input = String(text || "").trim();
    if (!input)
      return false;
    if (!/^[\d\s+\-*/().,%^]+$/.test(input) || !/\d/.test(input) || !/[+\-*/^%]/.test(input) || /^\d+\.?\d*$/.test(input))
      return false;
    try {
      let expr = input.replace(/\^/g, "**");
      expr = expr.replace(/(\d+\.?\d*)%/g, "($1/100)").replace(/[^0-9+\-*/().%\s]/g, "");
      if (!expr.trim())
        return false;
      const fn = Function("\"use strict\"; return (" + expr + ");");
      const value = fn();
      if (typeof value !== "number" || !isFinite(value))
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
