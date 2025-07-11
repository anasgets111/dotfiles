//@ pragma UseQApplication

import QtQuick
import Quickshell
import "./modules/Bar"

ShellRoot {
    id: root
    Loader {
        active: true
        sourceComponent: Bar {}
    }
}
