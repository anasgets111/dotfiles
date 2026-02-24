pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Config
import qs.Modules.Global.Launcher
import qs.Services.Utils

Item {
  id: root

  property bool active: false
  property bool _closing: false
  property bool _shown: false
  property int currentIndex: 0
  property var filteredApps: []
  property var finder: null
  property string query: ""

  readonly property var allApps: typeof DesktopEntries !== "undefined" ? DesktopEntries.applications?.values || [] : []
  readonly property bool hasSpecial: query.trim().length > 0 && (CalcEngine.hasResult || CurrencyEngine.hasResult)
  readonly property bool calcMode: CalcEngine.hasResult
  readonly property bool fxMode: CurrencyEngine.hasResult
  readonly property int maxVisible: 8
  readonly property int visibleAppCount: Math.min(filteredApps.length, maxVisible)
  readonly property int totalRows: visibleAppCount + (hasSpecial ? 1 : 0)

  signal dismissed

  function open(): void {
    closeDelay.stop();
    _closing = false;
    if (_shown)
      return;
    Qt.callLater(() => root._shown = true);
  }
  function close(): void {
    if (!_shown || _closing)
      return;
    _closing = true;
    _shown = false;
    closeDelay.restart();
  }

  function toArray(v: var): var {
    if (!v)
      return [];
    if (Array.isArray(v))
      return v;
    if (typeof v.length === "number")
      return Array.from(v);
    return [];
  }

  function ensureFinder(force: bool): void {
    if (!force && finder)
      return;
    if (!Fzf?.finder) {
      finder = null;
      return;
    }
    try {
      finder = new Fzf.finder(toArray(allApps), {
        selector: e => {
          const n = e?.name || "";
          const c = e?.comment || "";
          return c ? `${n} ${c}` : n;
        },
        limit: 200,
        tiebreakers: [Fzf.by_start_asc, Fzf.by_length_asc]
      });
    } catch (_) {
      finder = null;
    }
  }

  function filterApps(text: string): void {
    ensureFinder(false);
    const q = String(text || "");
    if (!q) {
      filteredApps = toArray(allApps).slice(0, 200);
      return;
    }
    if (finder) {
      try {
        filteredApps = finder.find(q).map(r => r.item);
        return;
      } catch (_) {
      }
    }
    const lower = q.toLowerCase();
    filteredApps = toArray(allApps).filter(e => {
      const n = String(e?.name || "").toLowerCase();
      const c = String(e?.comment || "").toLowerCase();
      return n.includes(lower) || c.includes(lower);
    }).slice(0, 200);
  }

  function processInput(text: string): void {
    query = text;
    CalcEngine.reset();
    CurrencyEngine.reset();
    const trimmed = String(text || "").trim();
    if (!trimmed) {
      filterApps("");
      currentIndex = 0;
      return;
    }
    if (!CurrencyEngine.parseAndConvert(trimmed))
      CalcEngine.evaluate(trimmed);
    filterApps(trimmed);
    currentIndex = 0;
  }

  function isSpecialSelected(): bool { return hasSpecial && currentIndex === 0; }
  function selectedAppIndex(): int { return visibleAppCount <= 0 ? -1 : Math.max(0, Math.min(currentIndex - (hasSpecial ? 1 : 0), visibleAppCount - 1)); }
  function escapeSingle(s: string): string { return String(s || "").replace(/'/g, "'\\''"); }
  function copy(text: string): void { Quickshell.execDetached(["sh", "-c", "echo -n '" + escapeSingle(text) + "' | wl-copy"]); }
  function mockRateLabel(): string {
    if (!fxMode || CurrencyEngine.inputAmount === 0)
      return "";
    const rate = CurrencyEngine.outputAmount / CurrencyEngine.inputAmount;
    const decimals = rate >= 100 ? 2 : (rate >= 1 ? 4 : 6);
    return " · 1 " + CurrencyEngine.fromCode.toUpperCase() + " = " + rate.toLocaleString(Qt.locale(), "f", decimals) + " " + CurrencyEngine.toCode.toUpperCase();
  }

  function launch(entry: var): void {
    const id = String(entry?.id || "").replace(/\.desktop$/, "");
    if (!id)
      return;
    Quickshell.execDetached(["gtk-launch", id]);
    close();
  }

  function activateCurrent(): void {
    if (totalRows <= 0)
      return;
    if (isSpecialSelected()) {
      if (calcMode)
        copy(CalcEngine.resultText);
      else if (fxMode)
        copy(CurrencyEngine.resultText);
      return;
    }
    const idx = selectedAppIndex();
    if (idx >= 0)
      launch(filteredApps[idx]);
  }

  function move(delta: int): void {
    if (totalRows <= 0)
      return;
    currentIndex = Math.max(0, Math.min(currentIndex + delta, totalRows - 1));
  }

  anchors.fill: parent
  focus: active || _closing
  visible: active || _closing || _shown

  Component.onCompleted: {
    if (active)
      open();
  }
  onActiveChanged: {
    if (active) {
      open();
      ensureFinder(true);
      processInput("");
      Qt.callLater(() => search.forceActiveFocus());
      return;
    }
    if (_shown && !_closing)
      close();
  }
  onAllAppsChanged: {
    if (!active && !_shown)
      return;
    ensureFinder(true);
    filterApps(query.trim());
  }

  Timer {
    id: closeDelay

    interval: Theme.animationSlow
    repeat: false

    onTriggered: {
      root._closing = false;
      root._shown = false;
      root.dismissed();
    }
  }

  MouseArea { anchors.fill: parent; onClicked: root.close() }
  Rectangle {
    anchors.fill: parent
    color: Theme.withOpacity("#000", 0.35)
    opacity: root._shown ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutCubic
      }
    }
  }

  Rectangle {
    id: panel

    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(860, parent.width * 0.62)
    y: root._shown ? parent.height * 0.13 : parent.height * 0.11
    radius: Theme.radiusLg
    color: Theme.withOpacity(Theme.bgColor, 0.95)
    border.color: Theme.withOpacity(Theme.borderColor, 0.45)
    border.width: 1
    height: Math.min(parent.height * 0.75, content.implicitHeight + Theme.spacingLg * 2)
    opacity: root._shown ? 1 : 0

    Behavior on y {
      NumberAnimation {
        duration: Theme.animationSlow
        easing.type: Easing.OutCubic
      }
    }
    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutCubic
      }
    }
    MouseArea { anchors.fill: parent; onPressed: m => m.accepted = true }

    ColumnLayout {
      id: content

      anchors.fill: parent
      anchors.margins: Theme.spacingLg
      spacing: Theme.spacingSm

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.s(56)
        radius: Theme.radiusMd
        color: Theme.withOpacity(Theme.bgElevated, 0.75)
        border.color: search.activeFocus ? Theme.withOpacity(Theme.activeColor, 0.5) : Theme.withOpacity(Theme.borderColor, 0.4)
        border.width: search.activeFocus ? 2 : 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Theme.spacingMd
          anchors.rightMargin: Theme.spacingMd
          spacing: Theme.spacingSm

          OText {
            color: Theme.textInactiveColor
            font.pixelSize: Theme.iconSizeLg
            text: "󰍉"
          }

          TextInput {
            id: search

            Layout.fillHeight: true
            Layout.fillWidth: true
            color: Theme.textActiveColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLg
            selectedTextColor: Theme.textContrast(Theme.activeColor)
            selectionColor: Theme.activeColor
            verticalAlignment: Text.AlignVCenter
            onTextChanged: root.processInput(text)

            Keys.onPressed: e => {
              switch (e.key) {
              case Qt.Key_Escape:
                root.close();
                e.accepted = true;
                break;
              case Qt.Key_Down:
                root.move(1);
                e.accepted = true;
                break;
              case Qt.Key_Up:
                root.move(-1);
                e.accepted = true;
                break;
              case Qt.Key_Tab:
                root.move(1);
                e.accepted = true;
                break;
              case Qt.Key_Return:
              case Qt.Key_Enter:
                root.activateCurrent();
                e.accepted = true;
                break;
              }
            }

            OText {
              anchors.fill: parent
              color: Theme.textInactiveColor
              font: search.font
              opacity: search.text.length === 0 ? 0.6 : 0
              text: "Search apps, calculate, convert currency..."
            }
          }

          OText {
            color: Theme.withOpacity(Theme.activeColor, 0.8)
            font.pixelSize: Theme.fontXs
            text: calcMode ? "CALC" : (fxMode ? "FX-MOCK" : "")
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: (hasSpecial || visibleAppCount > 0) ? results.implicitHeight + Theme.spacingSm * 2 : 0
        Layout.preferredHeight: implicitHeight
        visible: implicitHeight > 0
        radius: Theme.radiusMd
        color: Theme.withOpacity(Theme.bgElevated, 0.65)

        ColumnLayout {
          id: results

          anchors.fill: parent
          anchors.margins: Theme.spacingSm
          spacing: Theme.spacingXs

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: hasSpecial ? Theme.s(86) : 0
            visible: hasSpecial
            radius: Theme.radiusMd
            color: isSpecialSelected() ? Theme.withOpacity(Theme.activeColor, 0.20) : Theme.withOpacity(Theme.onHoverColor, 0.12)

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.currentIndex = 0
              onClicked: {
                root.currentIndex = 0;
                root.activateCurrent();
              }
            }

            Column {
              anchors.fill: parent
              anchors.margins: Theme.spacingMd
              spacing: Theme.spacingXs

              OText {
                color: Theme.activeColor
                font.pixelSize: Theme.fontXs
                text: calcMode ? "Calculator" : ("Currency (Mock)" + root.mockRateLabel())
              }
              OText {
                font.pixelSize: Theme.fontLg
                width: parent.width
                text: calcMode ? (CalcEngine.expression + " = " + CalcEngine.resultText) : (CurrencyEngine.inputAmount + " " + CurrencyEngine.fromCode.toUpperCase() + " -> " + CurrencyEngine.resultText + " " + CurrencyEngine.toCode.toUpperCase())
              }
              OText {
                color: Theme.textInactiveColor
                font.pixelSize: Theme.fontXs
                opacity: 0.8
                text: "Enter to copy"
              }
            }
          }

          ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: visibleAppCount > 0 ? Math.min(visibleAppCount * Theme.s(64), Theme.s(64) * maxVisible) : 0
            currentIndex: root.isSpecialSelected() ? -1 : root.selectedAppIndex()
            model: filteredApps
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: true
            highlightMoveDuration: Theme.animationDuration
            highlight: Rectangle {
              radius: Theme.radiusSm
              color: Theme.withOpacity(Theme.activeColor, 0.30)
            }
            interactive: filteredApps.length > maxVisible

            delegate: Item {
              id: row

              required property int index
              required property var modelData
              readonly property int composedIndex: hasSpecial ? index + 1 : index
              readonly property bool selected: composedIndex === root.currentIndex
              width: list.width
              height: Theme.s(64)
              visible: index < maxVisible || list.interactive

              Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: "transparent"
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMd
                anchors.rightMargin: Theme.spacingMd
                spacing: Theme.spacingSm

                Image {
                  Layout.preferredHeight: Theme.s(34)
                  Layout.preferredWidth: Theme.s(34)
                  source: Utils.resolveIconSource(modelData?.id || modelData?.name || "", modelData?.icon, "application-x-executable")
                  fillMode: Image.PreserveAspectFit
                  scale: row.selected ? 1.3 : 1.0

                  Behavior on scale {
                    NumberAnimation {
                      duration: Theme.animationFast
                      easing.type: Easing.OutCubic
                    }
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  OText {
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontMd
                    text: modelData?.name || ""
                  }
                  OText {
                    Layout.fillWidth: true
                    color: Theme.textInactiveColor
                    font.pixelSize: Theme.fontXs
                    opacity: 0.7
                    text: modelData?.comment || ""
                    visible: text.length > 0
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.currentIndex = row.composedIndex
                onClicked: root.launch(row.modelData)
              }
            }
          }
        }
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textInactiveColor
        font.pixelSize: Theme.fontSm
        opacity: 0.7
        text: query.trim().length > 0 && totalRows === 0 ? "No results found" : ""
      }
    }
  }
}
