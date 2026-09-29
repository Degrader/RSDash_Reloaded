import QtQuick 2.6

import "Icons.js" as Icons

// Draws one of the button icons from Icons.js (generated from the SVGs in
// docs/icons/ by dev/make_icons.py) in any colour, centred and as large as
// fits the item. Each of an icon's shapes (one per SVG path) is filled on
// its own with the even-odd rule, so outlines inside others become holes,
// as in the SVGs.
Item {
    id: svgIcon

    property string icon: ""
    property color color: "#F8E63C"

    visible: icon !== ""

    onIconChanged: iconCanvas.requestPaint()
    onColorChanged: iconCanvas.requestPaint()
    onWidthChanged: iconCanvas.requestPaint()
    onHeightChanged: iconCanvas.requestPaint()

    Canvas {
        id: iconCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var shapes = Icons.shapes[svgIcon.icon];
            if (!shapes) return;

            var size = Math.min(width, height);
            var ox = (width - size) / 2, oy = (height - size) / 2;
            ctx.fillStyle = svgIcon.color;
            ctx.fillRule = Qt.OddEvenFill;
            for (var s = 0; s < shapes.length; ++s) {
                var polygons = shapes[s];
                ctx.beginPath();
                for (var i = 0; i < polygons.length; ++i) {
                    var p = polygons[i];
                    ctx.moveTo(ox + p[0] * size, oy + p[1] * size);
                    for (var j = 2; j < p.length; j += 2) {
                        ctx.lineTo(ox + p[j] * size, oy + p[j + 1] * size);
                    }
                    ctx.closePath();
                }
                ctx.fill();
            }
        }
    }
}
