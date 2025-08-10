// Abstract interface for WorkspaceService
pragma Singleton
import QtQuick 2.0

QtObject {
    // Define abstract signals, properties, and methods here
    // Example:
    signal workspaceChanged(int workspace)
    property int currentWorkspace: 0
    function switchTo(workspace) {
    }
}
