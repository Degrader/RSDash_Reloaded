import QtQuick 2.6

// The Focus RS from above, nose up: a picture of the car (res/car_top.png,
// made from docs/car/focus_rs_top.webp by dev/make_car.py) with the four
// tyres drawn on top of it, so each can be drawn in the alert colour. The
// picture and the tyres scale with the item's width; the positions the page
// needs to put readings next to the tyres (in this item's pixels) are
// exposed below.
Item {
    id: car

    // The drawing is laid out in the units of the picture's full-size self,
    // 824 x 1752 (the picture is kept at 360 wide, to look sharp at the 180 it's
    // shown at), then scaled by k. The numbers come from dev/make_car.py.
    readonly property real designWidth: 824
    readonly property real designHeight: 1752

    width: designWidth
    height: width * designHeight / designWidth

    property color accentColour: "#38d3ee"
    property color alertColour: "#ce1845"

    property color tireFLColour: accentColour
    property color tireFRColour: accentColour
    property color tireRLColour: accentColour
    property color tireRRColour: accentColour

    readonly property real k: width / designWidth

    // The picture of the car, e.g. for the dev harness to check it loaded
    readonly property alias picture: carPicture

    // Where the tyres are: the centre line between them, each axle, each
    // tyre's distance from the centre line, and the tyre's size
    readonly property real centreX: 409.2 * k
    readonly property real frontAxleY: 418.8 * k
    readonly property real rearAxleY: 1325.8 * k
    readonly property real tireOffset: 356.8 * k
    readonly property real tireWidth: 79 * k
    readonly property real tireHeight: 206 * k

    onWidthChanged: carCanvas.requestPaint()
    onTireFLColourChanged: carCanvas.requestPaint()
    onTireFRColourChanged: carCanvas.requestPaint()
    onTireRLColourChanged: carCanvas.requestPaint()
    onTireRRColourChanged: carCanvas.requestPaint()
    onVisibleChanged: if (visible) carCanvas.requestPaint()
    Component.onCompleted: carCanvas.requestPaint()

    Image {
        id: carPicture
        anchors.fill: parent
        source: "../res/car_top.png"
        smooth: true
        mipmap: true
    }

    Canvas {
        id: carCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.scale(car.k, car.k);
            ctx.lineJoin = "round";
            ctx.lineCap = "round";

            // A tyre as the picture draws it: a dark pill with an outline of
            // the tyre's colour and five chevrons pointing to the nose
            function tire(x, y, colour) {
                var w = 79, h = 206, outline = 6;
                ctx.fillStyle = "#040608";
                ctx.strokeStyle = colour;
                ctx.lineWidth = outline;
                ctx.beginPath();
                ctx.roundedRect(x - w / 2 + outline / 2, y - h / 2 + outline / 2, w - outline, h - outline, 17, 17);
                ctx.fill();
                ctx.stroke();

                ctx.lineWidth = 3.6;
                ctx.beginPath();
                var tips = [25, 57.5, 89, 122, 157];
                for (var i = 0; i < tips.length; ++i) {
                    var tip = y - h / 2 + tips[i];
                    ctx.moveTo(x - 27, tip + 21);
                    ctx.lineTo(x, tip);
                    ctx.lineTo(x + 27, tip + 21);
                }
                ctx.stroke();
            }
            tire(409.2 - 356.8, 418.8, car.tireFLColour);
            tire(409.2 + 356.8, 418.8, car.tireFRColour);
            tire(409.2 - 356.8, 1325.8, car.tireRLColour);
            tire(409.2 + 356.8, 1325.8, car.tireRRColour);
        }
    }
}
