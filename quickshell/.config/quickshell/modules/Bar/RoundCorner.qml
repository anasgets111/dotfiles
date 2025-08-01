import QtQuick 2.9

Item {
    id: root

    enum CornerEnum {
        TopLeft,
        TopRight,
        BottomLeft,
        BottomRight
    }

    property int corner: 0
    property int size: Theme.panelRadius
    property color color: Theme.bgColor

    implicitWidth: size
    implicitHeight: size
    onColorChanged: canvas.requestPaint()
    onCornerChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            var r = root.size;
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            ctx.beginPath();
            switch (root.corner) {
            case 0:
                // TopLeft
                ctx.arc(r, r, r, Math.PI, 1.5 * Math.PI);
                ctx.lineTo(0, 0);
                break;
            case 1:
                // TopRight
                ctx.arc(0, r, r, 1.5 * Math.PI, 2 * Math.PI);
                ctx.lineTo(r, 0);
                break;
            case 2:
                // BottomLeft
                ctx.arc(r, 0, r, 0.5 * Math.PI, Math.PI);
                ctx.lineTo(0, r);
                break;
            case 3:
                // BottomRight
                ctx.arc(0, 0, r, 0, 0.5 * Math.PI);
                ctx.lineTo(r, r);
                break;
            }
            ctx.closePath();
            ctx.fillStyle = root.color;
            ctx.fill();
        }
    }
}
