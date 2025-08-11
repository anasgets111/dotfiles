import QtQuick
import Quickshell.Services.Pam
import Quickshell.Wayland
import "../services" as Services

Item {
    id: root
    required property WlSessionLockSurface lock

    property string passwordBuffer: ""

    focus: true

    Keys.onPressed: event => {
        if (pam.active)
            return;

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            pam.start();
        } else if (event.key === Qt.Key_Backspace) {
            passwordBuffer = passwordBuffer.slice(0, -1);
        } else if (event.text.length > 0) {
            passwordBuffer += event.text;
        }
    }

    PamContext {
        id: pam

        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.passwordBuffer);
                root.passwordBuffer = "";
            }
        }

        onCompleted: res => {
            if (res === PamResult.Success) {
                Services.LockService.requestUnlock();
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.passwordBuffer.length > 0 ? "*".repeat(root.passwordBuffer.length) : "Enter password"
            font.pixelSize: 18
            color: "white"
        }

        Text {
            text: pam.active ? "Authenticating..." : ""
            font.pixelSize: 14
            color: "lightgray"
        }
    }
}
