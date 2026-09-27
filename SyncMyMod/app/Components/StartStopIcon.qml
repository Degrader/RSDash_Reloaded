import QtQuick 2.6

// The auto start/stop symbol: an "A" inside a clockwise arrow that's open at
// the bottom. Drawn rather than an image, so it scales and takes any colour.
Item {
    id: startStopIcon

    property color color: "#F8E63C"

    onColorChanged: arrowCanvas.requestPaint()
    onWidthChanged: arrowCanvas.requestPaint()
    onHeightChanged: arrowCanvas.requestPaint()

    Canvas {
        id: arrowCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            var size = Math.min(width, height);
            var centerX = width / 2;
            var centerY = height / 2;
            var radius = size * 0.4;

            // Canvas angles run clockwise from 3 o'clock; the arrow goes from
            // lower left, over the top, to lower right.
            var startAngle = 134 * Math.PI / 180;
            var endAngle = 400 * Math.PI / 180;

            ctx.reset();
            ctx.strokeStyle = startStopIcon.color;
            ctx.fillStyle = startStopIcon.color;
            ctx.lineWidth = Math.max(2, size * 0.075);
            ctx.lineCap = "butt";
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, startAngle, endAngle, false);
            ctx.stroke();

            // Arrowhead at the end of the arc, pointing along it
            var endX = centerX + radius * Math.cos(endAngle);
            var endY = centerY + radius * Math.sin(endAngle);
            var alongX = -Math.sin(endAngle);
            var alongY = Math.cos(endAngle);
            var headLength = size * 0.24;
            var halfWidth = size * 0.13;
            ctx.beginPath();
            ctx.moveTo(endX + alongX * headLength, endY + alongY * headLength);
            ctx.lineTo(endX + alongY * halfWidth, endY - alongX * halfWidth);
            ctx.lineTo(endX - alongY * halfWidth, endY + alongX * halfWidth);
            ctx.closePath();
            ctx.fill();
        }
    }

    Text {
        anchors.centerIn: parent
        text: "A"
        color: startStopIcon.color
        font.pixelSize: Math.round(Math.min(parent.width, parent.height) * 0.56)
        font.weight: Font.Bold
    }
}
