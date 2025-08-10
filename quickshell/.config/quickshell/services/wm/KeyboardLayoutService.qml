// Abstract interface for KeyboardLayoutService
pragma Singleton
import QtQuick 2.0

QtObject {
    // Define abstract signals, properties, and methods here
    // Example:
    signal layoutChanged(string layout)
    property string currentLayout: ""
    function setLayout(layout) {
    }
}
