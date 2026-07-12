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

  property bool _closing: false
  property real _lastPointerX: -1
  property real _lastPointerY: -1
  property bool _shown: false
  property bool active: false
  readonly property var allApps: Array.from(DesktopEntries.applications?.values ?? [])
  property int currentIndex: 0
  property var filteredApps: []
  property var finder: null
  readonly property bool hasSpecial: LauncherService.hasSpecial
  property bool hoverSelectionArmed: false
  readonly property int maxResults: 200
  readonly property int maxVisible: 8
  readonly property int selectedAppIdx: filteredApps.length === 0 ? -1 : Math.max(0, Math.min(currentIndex - (hasSpecial ? 1 : 0), filteredApps.length - 1))
  readonly property bool specialSelected: hasSpecial && currentIndex === 0
  readonly property int totalRows: filteredApps.length + (hasSpecial ? 1 : 0)
  readonly property int visibleAppCount: Math.min(filteredApps.length, maxVisible)

  signal dismissed

  function activateCurrent(): void {
    if (totalRows <= 0)
      return;
    if (specialSelected) {
      LauncherService.activateSpecial();
      close();
      return;
    }
    if (selectedAppIdx >= 0)
      launch(filteredApps[selectedAppIdx]);
  }

  function armHoverSelectionIfMoved(x: real, y: real): void {
    if (!Number.isFinite(x) || !Number.isFinite(y) || (x === _lastPointerX && y === _lastPointerY))
      return;
    _lastPointerX = x;
    _lastPointerY = y;
    hoverSelectionArmed = true;
  }

  function close(): void {
    if (!_shown || _closing)
      return;
    _closing = true;
    _shown = false;
    closeDelay.restart();
  }

  function disarmHoverSelection(): void {
    hoverSelectionArmed = false;
  }

  function ensureFinder(force: bool): void {
    if (!force && finder)
      return;
    finder = Fzf.createFinder(allApps, {
      selector: entry => {
        const name = entry?.name || "";
        const comment = entry?.comment || "";
        return comment ? `${name} ${comment}` : name;
      },
      limit: maxResults,
      tiebreakers: [Fzf.byStartAsc, Fzf.byLengthAsc]
    });
  }

  function filterApps(text: string): real {
    ensureFinder(false);
    const q = String(text || "");
    if (!q) {
      filteredApps = allApps.slice(0, maxResults);
      return 0;
    }
    const results = finder.find(q);
    filteredApps = results.map(result => result.item);
    return results.length > 0 ? results[0].score : 0;
  }

  function handleHoverMove(x: real, y: real, targetIndex: int): void {
    armHoverSelectionIfMoved(x, y);
    if (hoverSelectionArmed)
      currentIndex = targetIndex;
  }

  function launch(entry: var): void {
    const id = String(entry?.id || "").replace(/\.desktop$/, "");
    if (!id)
      return;
    Quickshell.execDetached(["gtk-launch", id]);
    close();
  }

  function move(delta: int): void {
    if (totalRows <= 0)
      return;
    disarmHoverSelection();
    currentIndex = Math.max(0, Math.min(currentIndex + delta, totalRows - 1));
  }

  function open(): void {
    closeDelay.stop();
    _closing = false;
    if (_shown)
      return;
    Qt.callLater(() => root._shown = true);
  }

  function processInput(text: string): void {
    disarmHoverSelection();
    const trimmed = String(text || "").trim();
    const maxAppScore = filterApps(trimmed);
    LauncherService.route(trimmed, filteredApps.length, maxAppScore);
    currentIndex = 0;
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
      LauncherService.refresh();
      open();
      disarmHoverSelection();
      _lastPointerX = -1;
      _lastPointerY = -1;
      ensureFinder(true);
      if (search.text !== "")
        search.text = "";
      else
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
    processInput(search.text);
  }

  Timer {
    id: closeDelay

    interval: Theme.animationSlow

    onTriggered: {
      root._closing = false;
      root._shown = false;
      root.dismissed();
    }
  }

  MouseArea {
    anchors.fill: parent

    onClicked: root.close()
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.bgOverlay
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
    border.color: Theme.withOpacity(Theme.borderColor, 0.45)
    border.width: Theme.borderWidthThin
    color: Theme.withOpacity(Theme.bgColor, 0.95)
    height: Math.min(parent.height * 0.75, content.implicitHeight + Theme.spacingLg * 2)
    opacity: root._shown ? 1 : 0
    radius: Theme.radiusLg
    width: Math.min(860, parent.width * 0.62)
    y: root._shown ? parent.height * 0.13 : parent.height * 0.11

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutCubic
      }
    }
    Behavior on y {
      NumberAnimation {
        duration: Theme.animationSlow
        easing.type: Easing.OutCubic
      }
    }

    MouseArea {
      anchors.fill: parent

      onPressed: m => m.accepted = true
    }

    ColumnLayout {
      id: content

      anchors.fill: parent
      anchors.margins: Theme.spacingLg
      spacing: Theme.spacingSm

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.s(56)
        border.color: search.activeFocus ? Theme.withOpacity(Theme.activeColor, 0.5) : Theme.withOpacity(Theme.borderColor, 0.4)
        border.width: search.activeFocus ? Theme.borderWidthMedium : Theme.borderWidthThin
        color: Theme.withOpacity(Theme.bgElevated, 0.75)
        radius: Theme.radiusMd

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

            Keys.onPressed: e => {
              switch (e.key) {
              case Qt.Key_Escape:
                root.close();
                e.accepted = true;
                break;
              case Qt.Key_Down:
              case Qt.Key_Tab:
                root.move(1);
                e.accepted = true;
                break;
              case Qt.Key_Up:
                root.move(-1);
                e.accepted = true;
                break;
              case Qt.Key_Return:
              case Qt.Key_Enter:
                root.activateCurrent();
                e.accepted = true;
                break;
              }
            }
            onTextChanged: root.processInput(text)

            OText {
              anchors.fill: parent
              color: Theme.textInactiveColor
              font: search.font
              opacity: search.text.length === 0 ? 0.6 : 0
              text: qsTr("Search apps, calculate, convert currency…")
            }
          }

          OText {
            color: Theme.withOpacity(Theme.activeColor, 0.8)
            font.pixelSize: Theme.fontXs
            text: LauncherService.activeProvider?.statusLabel ?? ""
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        color: Theme.withOpacity(Theme.bgElevated, 0.65)
        implicitHeight: (hasSpecial || visibleAppCount > 0) ? results.implicitHeight + Theme.spacingSm * 2 : 0
        radius: Theme.radiusMd
        visible: implicitHeight > 0

        ColumnLayout {
          id: results

          anchors.fill: parent
          anchors.margins: Theme.spacingSm
          spacing: Theme.spacingXs

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: hasSpecial ? Theme.s(86) : 0
            color: root.specialSelected ? Theme.withOpacity(Theme.activeColor, 0.20) : Theme.withOpacity(Theme.onHoverColor, 0.12)
            radius: Theme.radiusMd
            visible: hasSpecial

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true

              onClicked: {
                root.currentIndex = 0;
                root.activateCurrent();
              }
              onPositionChanged: mouse => {
                const p = mapToItem(root, mouse.x, mouse.y);
                root.handleHoverMove(p.x, p.y, 0);
              }
            }

            Loader {
              anchors.fill: parent
              anchors.margins: Theme.spacingMd
              sourceComponent: LauncherService.activeProvider?.delegate ?? null
            }
          }

          ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: visibleAppCount * Theme.s(64)
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            currentIndex: root.specialSelected ? -1 : root.selectedAppIdx
            highlightMoveDuration: Theme.animationDuration
            interactive: filteredApps.length > maxVisible
            model: ScriptModel {
              values: root.filteredApps
            }

            delegate: Item {
              id: row

              readonly property int composedIndex: hasSpecial ? index + 1 : index
              required property int index
              required property var modelData
              readonly property bool selected: composedIndex === root.currentIndex

              height: Theme.s(64)
              width: list.width

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMd
                anchors.rightMargin: Theme.spacingMd
                spacing: Theme.spacingSm

                Image {
                  Layout.preferredHeight: Theme.s(34)
                  Layout.preferredWidth: Theme.s(34)
                  fillMode: Image.PreserveAspectFit
                  scale: row.selected ? 1.3 : 1.0
                  source: Utils.resolveIconSource(modelData?.id || modelData?.name || "", modelData?.icon, "application-x-executable")

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
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: root.launch(row.modelData)
                onPositionChanged: mouse => {
                  const p = mapToItem(root, mouse.x, mouse.y);
                  root.handleHoverMove(p.x, p.y, row.composedIndex);
                }
              }
            }
            highlight: Rectangle {
              color: Theme.withOpacity(Theme.activeColor, 0.30)
              radius: Theme.radiusSm
            }
          }
        }
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textInactiveColor
        font.pixelSize: Theme.fontSm
        opacity: 0.7
        text: search.text.trim().length > 0 && totalRows === 0 ? qsTr("No results found") : ""
      }
    }
  }
}
