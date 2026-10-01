import QtQuick 2.6

// A G-force plot: a dot that moves with the car's lateral and longitudinal
// acceleration, on rings 0.5 g apart. The dot turns red past ringMax / 1.5.
// It sticks to the edge of the plot when the force is bigger than the plot.
//
// Directions: a positive latG puts the dot to the right and a positive longG
// puts it up (towards the car's nose); set flipLateral / flipLongitudinal if
// the car's sign is the other way.
Item {
    id: gForce

    property real latG: 0
    property real longG: 0

    // The force at the plot's edge, in g
    property real maxG: 1.5
    property real alertG: 1.0
    property bool flipLateral: false
    property bool flipLongitudinal: false

    property color ringColour: "#2a2a2a"
    property color dotColour: "#329BFD"
    property color alertColour: "#ce1845"

    width: 190
    height: 190

    onLatGChanged: if (visible) gCanvas.requestPaint()
    onLongGChanged: if (visible) gCanvas.requestPaint()
    onVisibleChanged: if (visible) gCanvas.requestPaint()
    onWidthChanged: gCanvas.requestPaint()
    Component.onCompleted: gCanvas.requestPaint()

    Canvas {
        id: gCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var cx = width / 2, cy = height / 2;
            var radius = Math.min(cx, cy) - 4;

            // Filled background and the rings, each 0.5 g
            ctx.fillStyle = "#0d0d0d";
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
            ctx.fill();

            ctx.strokeStyle = gForce.ringColour;
            ctx.lineWidth = 2;
            for (var g = 0.5; g <= gForce.maxG + 0.001; g += 0.5) {
                ctx.beginPath();
                ctx.arc(cx, cy, radius * g / gForce.maxG, 0, 2 * Math.PI);
                ctx.stroke();
            }
            ctx.lineWidth = 5;
            ctx.strokeStyle = "#1e1e1e";
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
            ctx.stroke();

            // Crosshair
            ctx.lineWidth = 2;
            ctx.strokeStyle = gForce.ringColour;
            ctx.beginPath();
            ctx.moveTo(cx - radius, cy);
            ctx.lineTo(cx + radius, cy);
            ctx.moveTo(cx, cy - radius);
            ctx.lineTo(cx, cy + radius);
            ctx.stroke();

            // The dot
            var x = (gForce.flipLateral ? -gForce.latG : gForce.latG);
            var y = (gForce.flipLongitudinal ? -gForce.longG : gForce.longG);
            var total = Math.sqrt(x * x + y * y);
            var shown = Math.min(total, gForce.maxG);
            var scale = total > 0 ? shown / total : 0;
            var px = cx + x * scale * radius / gForce.maxG;
            var py = cy - y * scale * radius / gForce.maxG;
            var colour = total > gForce.alertG ? gForce.alertColour : gForce.dotColour;

            ctx.fillStyle = colour;
            ctx.beginPath();
            ctx.arc(px, py, 11, 0, 2 * Math.PI);
            ctx.fill();
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = 2;
            ctx.stroke();
        }
    }
}
