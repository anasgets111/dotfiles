pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.Services.Utils

Singleton {
  id: root

  readonly property alias flow: agent.flow
  readonly property bool isActive: agent.isActive

  function prepareAgent() {
    return agent.isActive;
  }

  PolkitAgent {
    id: agent

    onAuthenticationRequestStarted: {
      Logger.log("PolkitService", `Auth started: ${agent.flow ? agent.flow.message : '<no flow>'} for ${agent.flow ? agent.flow.actionId : '<no-action>'}`);
    }
  }
}
