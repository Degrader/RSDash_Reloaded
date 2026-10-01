import QtQuick 2.6

// A top-down line drawing of the Focus RS, nose up: the honeycomb grille and
// corner intakes, the headlights, the bonnet creases, the glass and roof, the
// big rear wing, the diffuser with its twin exhausts, and the four tyres
// (with tread). Each tyre can be drawn in the alert colour. The drawing scales
// with the item's width; the positions the page needs to put readings next to
// the tyres (in this item's pixels) are exposed below.
Item {
    id: car

    width: 240
    height: width * 450 / 240

    property color bodyColour: "#8d96a8"
    property color accentColour: "#38d3ee"
    property color alertColour: "#ce1845"

    property color tireFLColour: accentColour
    property color tireFRColour: accentColour
    property color tireRLColour: accentColour
    property color tireRRColour: accentColour

    // The drawing is laid out 240 wide and 450 tall, then scaled by this
    readonly property real k: width / 240

    // Where the tyres are: the car's centre line, each axle, each tyre's distance
    // from the centre line, and the tyre's size
    readonly property real centreX: 120 * k
    readonly property real frontAxleY: 112 * k
    readonly property real rearAxleY: 372 * k
    readonly property real tireOffset: 96 * k
    readonly property real tireWidth: 30 * k
    readonly property real tireHeight: 76 * k

    onWidthChanged: carCanvas.requestPaint()
    onTireFLColourChanged: carCanvas.requestPaint()
    onTireFRColourChanged: carCanvas.requestPaint()
    onTireRLColourChanged: carCanvas.requestPaint()
    onTireRRColourChanged: carCanvas.requestPaint()
    onVisibleChanged: if (visible) carCanvas.requestPaint()
    Component.onCompleted: carCanvas.requestPaint()

    Canvas {
        id: carCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.scale(car.k, car.k);
            var cx = 120;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.strokeStyle = car.bodyColour;
            ctx.lineWidth = 2;

            // --- Body outline: right side from the nose down (each curve is
            // control 1, control 2, end, as offsets from the centre line),
            // then the same curves back up the left side. The front and rear
            // fenders bulge out over the wheels.
            var curves = [
                [30, 8, 62, 14, 74, 44],
                [80, 58, 86, 72, 86, 100],
                [86, 120, 82, 140, 81, 170],
                [80, 200, 80, 290, 80, 310],
                [82, 326, 90, 336, 90, 365],
                [90, 395, 88, 415, 78, 432],
                [66, 446, 36, 449, 0, 449]
            ];
            var ends = [[0, 8]];
            curves.forEach(function(c) { ends.push([c[4], c[5]]); });
            ctx.beginPath();
            ctx.moveTo(cx, 8);
            curves.forEach(function(c) {
                ctx.bezierCurveTo(cx + c[0], c[1], cx + c[2], c[3], cx + c[4], c[5]);
            });
            for (var i = curves.length - 1; i >= 0; --i) {
                var c = curves[i];
                ctx.bezierCurveTo(cx - c[2], c[3], cx - c[0], c[1], cx - ends[i][0], ends[i][1]);
            }
            ctx.closePath();
            ctx.stroke();

            ctx.lineWidth = 1.5;

            // --- Front: splitter lip, grille with its honeycomb, corner intakes, headlights
            ctx.beginPath();
            ctx.moveTo(cx - 58, 22);
            ctx.quadraticCurveTo(cx, 14, cx + 58, 22);
            ctx.stroke();

            ctx.beginPath();
            ctx.roundedRect(cx - 38, 26, 76, 20, 6, 6);
            ctx.stroke();
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (var gx = cx - 30; gx <= cx + 30; gx += 8) {
                ctx.moveTo(gx, 28);
                ctx.lineTo(gx, 44);
            }
            ctx.moveTo(cx - 36, 33);
            ctx.lineTo(cx + 36, 33);
            ctx.moveTo(cx - 36, 40);
            ctx.lineTo(cx + 36, 40);
            ctx.stroke();

            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.roundedRect(cx - 68, 26, 22, 16, 5, 5);
            ctx.roundedRect(cx + 46, 26, 22, 16, 5, 5);
            ctx.stroke();

            ctx.beginPath();
            ctx.moveTo(cx - 72, 52);
            ctx.lineTo(cx - 50, 48);
            ctx.lineTo(cx - 54, 62);
            ctx.lineTo(cx - 74, 68);
            ctx.closePath();
            ctx.moveTo(cx + 72, 52);
            ctx.lineTo(cx + 50, 48);
            ctx.lineTo(cx + 54, 62);
            ctx.lineTo(cx + 74, 68);
            ctx.closePath();
            ctx.stroke();

            // --- Bonnet: its edge and the two creases of the power bulge
            ctx.beginPath();
            ctx.moveTo(cx - 52, 74);
            ctx.quadraticCurveTo(cx, 66, cx + 52, 74);
            ctx.lineTo(cx + 62, 158);
            ctx.quadraticCurveTo(cx, 150, cx - 62, 158);
            ctx.closePath();
            ctx.moveTo(cx - 16, 70);
            ctx.lineTo(cx - 24, 152);
            ctx.moveTo(cx + 16, 70);
            ctx.lineTo(cx + 24, 152);
            ctx.stroke();

            // --- Glass and roof
            ctx.beginPath();
            ctx.moveTo(cx - 60, 168);
            ctx.quadraticCurveTo(cx, 158, cx + 60, 168);
            ctx.lineTo(cx + 68, 232);
            ctx.quadraticCurveTo(cx, 242, cx - 68, 232);
            ctx.closePath();
            ctx.stroke();

            ctx.beginPath();
            ctx.roundedRect(cx - 60, 244, 120, 76, 14, 14);
            ctx.stroke();

            ctx.beginPath();
            ctx.moveTo(cx - 62, 328);
            ctx.quadraticCurveTo(cx, 320, cx + 62, 328);
            ctx.lineTo(cx + 52, 352);
            ctx.quadraticCurveTo(cx, 358, cx - 52, 352);
            ctx.closePath();
            ctx.stroke();

            // --- Side skirts and mirrors
            ctx.beginPath();
            ctx.moveTo(cx - 72, 178);
            ctx.lineTo(cx - 72, 298);
            ctx.moveTo(cx + 72, 178);
            ctx.lineTo(cx + 72, 298);
            ctx.stroke();

            ctx.fillStyle = "#000000";
            ctx.beginPath();
            ctx.moveTo(cx - 81, 186);
            ctx.lineTo(cx - 99, 192);
            ctx.lineTo(cx - 99, 204);
            ctx.lineTo(cx - 81, 208);
            ctx.closePath();
            ctx.moveTo(cx + 81, 186);
            ctx.lineTo(cx + 99, 192);
            ctx.lineTo(cx + 99, 204);
            ctx.lineTo(cx + 81, 208);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();

            // --- The rear wing, with its end plates
            ctx.fillStyle = "#10151c";
            ctx.beginPath();
            ctx.roundedRect(cx - 72, 366, 144, 16, 5, 5);
            ctx.fill();
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(cx - 74, 360);
            ctx.lineTo(cx - 74, 388);
            ctx.moveTo(cx + 74, 360);
            ctx.lineTo(cx + 74, 388);
            ctx.stroke();

            // --- Rear: tail lights, diffuser, the twin exhausts and the central fog lamp
            ctx.beginPath();
            ctx.moveTo(cx - 76, 404);
            ctx.lineTo(cx - 50, 416);
            ctx.moveTo(cx + 76, 404);
            ctx.lineTo(cx + 50, 416);
            ctx.moveTo(cx - 52, 422);
            ctx.lineTo(cx + 52, 422);
            for (var fx = cx - 24; fx <= cx + 24; fx += 12) {
                ctx.moveTo(fx, 424);
                ctx.lineTo(fx, 444);
            }
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx - 36, 434, 6, 0, 2 * Math.PI);
            ctx.arc(cx + 36, 434, 6, 0, 2 * Math.PI);
            ctx.roundedRect(cx - 6, 432, 12, 6, 2, 2);
            ctx.stroke();

            // --- Tyres with tread
            function tire(x, y, colour) {
                var w = 30, h = 76;
                ctx.fillStyle = "#050505";
                ctx.strokeStyle = colour;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.roundedRect(x - w / 2, y - h / 2, w, h, 6, 6);
                ctx.fill();
                ctx.stroke();
                ctx.lineWidth = 1.2;
                ctx.beginPath();
                for (var row = 0; row < 6; ++row) {
                    var top = y - h / 2 + 10 + row * 11;
                    ctx.moveTo(x - w / 2 + 4, top + 7);
                    ctx.lineTo(x, top);
                    ctx.lineTo(x + w / 2 - 4, top + 7);
                }
                ctx.stroke();
            }
            tire(cx - 96, 112, car.tireFLColour);
            tire(cx + 96, 112, car.tireFRColour);
            tire(cx - 96, 372, car.tireRLColour);
            tire(cx + 96, 372, car.tireRRColour);
        }
    }
}
