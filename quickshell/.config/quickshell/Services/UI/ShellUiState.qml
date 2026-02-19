pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  property string activeModal: ""
  property string activePanelId: ""
  property string activeScreenName: ""
  property rect anchorRect: Qt.rect(0, 0, 0, 0)
  readonly property bool isAnyInteractiveOpen: isAnyPanelOpen || isAnyModalOpen
  readonly property bool isAnyModalOpen: activeModal.length > 0
  readonly property bool isAnyPanelOpen: activePanelId.length > 0
  property bool isInitializingKeyboard: false
  property var modalData: null
  property var panelData: null

  function anchorRectForItem(item) {
    if (!item)
      return Qt.rect(0, 0, 0, 0);
    const point = item.mapToItem(null, 0, 0);
    return Qt.rect(point.x, point.y, item.width || 0, item.height || 0);
  }

  function closeModal(modalId) {
    if (modalId && activeModal !== modalId)
      return;
    activeModal = "";
    modalData = null;
    isInitializingKeyboard = false;
    if (!isAnyPanelOpen)
      activeScreenName = "";
  }

  function closePanel() {
    activePanelId = "";
    anchorRect = Qt.rect(0, 0, 0, 0);
    panelData = null;
    isInitializingKeyboard = false;
    if (!isAnyModalOpen)
      activeScreenName = "";
  }

  function isModalOpenOn(screenName, modalId) {
    return activeScreenName === (screenName || "") && activeModal === (modalId || "");
  }

  function isPanelOpenOn(screenName) {
    return isAnyPanelOpen && activeScreenName === (screenName || "");
  }

  function isPanelOpen(panelId, screenName) {
    return activePanelId === (panelId || "") && activeScreenName === (screenName || "");
  }

  function openModal(modalId, screenName, data) {
    if (!modalId)
      return;
    activePanelId = "";
    panelData = null;
    isInitializingKeyboard = true;
    activeScreenName = screenName || "";
    activeModal = modalId;
    modalData = data ?? null;
    keyboardInitTimer.restart();
  }

  function openPanel(panelId, screenName, anchor, data) {
    if (!panelId)
      return;
    activeModal = "";
    modalData = null;
    activePanelId = panelId;
    activeScreenName = screenName || "";
    anchorRect = anchor ?? Qt.rect(0, 0, 0, 0);
    panelData = data ?? null;
    isInitializingKeyboard = true;
    keyboardInitTimer.restart();
  }

  function togglePanel(panelId, screenName, anchor, data) {
    if (activePanelId === panelId && activeScreenName === (screenName || "")) {
      closePanel();
      return;
    }
    openPanel(panelId, screenName, anchor, data);
  }

  function togglePanelForItem(panelId, screenName, item, data) {
    togglePanel(panelId, screenName, anchorRectForItem(item), data);
  }

  Timer {
    id: keyboardInitTimer

    interval: 180
    repeat: false

    onTriggered: root.isInitializingKeyboard = false
  }
}
