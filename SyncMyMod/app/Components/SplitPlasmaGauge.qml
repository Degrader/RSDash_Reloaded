import QtQuick 2.6

import "Controller.js" as Controller

// Plasma-style gauge split into two half-rings that fill from the bottom
// up, for showing a left/right pair of readings in one gauge slot.
Rectangle {
    id: splitPlasmaGaugeRect
    color: "transparent"

    property string name
    property string caption
    property color captionColor
    property string unitSymbol

    property color primaryColor
    property color secondaryColor

    property int nameSize
    property int valueSize
    property int captionSize

    property int thick

    property string measureType
    property int decimal
    property bool ignoreUnit: false

    property real minValue
    property real maxValue

    property real lowTreshold
    property real highTreshold

    // Blue/red marks on each half at lowTreshold/highTreshold
    property bool showThresholdMarks: measureType === "temperature"

    // Degrees left clear between the two halves, at both top and bottom.
    property real gapDegrees: 20

    property real leftValue: 0
    property real rightValue: 0

    // Same repaint-on-change approach as the other gauges.
    onLeftValueChanged: if (visible) splitGaugeCanvas.requestPaint()
    onRightValueChanged: if (visible) splitGaugeCanvas.requestPaint()
    onVisibleChanged: if (visible) splitGaugeCanvas.requestPaint()
    Component.onCompleted: splitGaugeCanvas.requestPaint()

    Item {
        anchors.fill: parent

        Canvas {
            id: splitGaugeCanvas
            anchors.fill: parent

            // Canvas angles run clockwise from 3 o'clock: 90 is straight
            // down, 270 straight up. The left half runs clockwise from the
            // bottom, the right half anticlockwise.
            function drawHalf(ctx, value, rightSide) {
                var centerX = width / 2;
                var centerY = height / 2;
                var radius = Math.min(centerX, centerY) - thick;
                var indicatorRadius = 14;

                var span = 180 - 2 * gapDegrees;
                var startAngle = rightSide ? 90 - gapDegrees : 90 + gapDegrees;
                var endAngle = rightSide ? startAngle - span : startAngle + span;

                var normalizedValue = Math.min(Math.max((value - minValue) / (maxValue - minValue), 0), 1);
                var progressAngle = startAngle + (rightSide ? -normalizedValue : normalizedValue) * span;

                var colour = (value < lowTreshold || value > highTreshold) ? secondaryColor : primaryColor;

                ctx.lineCap = "round";
                ctx.lineWidth = thick;
                ctx.strokeStyle = "#1e1e1e";
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, startAngle * Math.PI / 180, endAngle * Math.PI / 180, rightSide);
                ctx.stroke();

                ctx.strokeStyle = colour;
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, startAngle * Math.PI / 180, progressAngle * Math.PI / 180, rightSide);
                ctx.stroke();

                if (showThresholdMarks) {
                    Controller.drawThresholdMarks(ctx, centerX, centerY, radius, thick, function(value) {
                        var n = (value - minValue) / (maxValue - minValue);
                        return startAngle + (rightSide ? -n : n) * span;
                    });
                }

                ctx.fillStyle = "#2A2A2A";
                ctx.strokeStyle = colour;
                ctx.lineWidth = 5;
                ctx.beginPath();
                ctx.arc(centerX + radius * Math.cos(progressAngle * Math.PI / 180), centerY + radius * Math.sin(progressAngle * Math.PI / 180), indicatorRadius, 0, 2 * Math.PI);
                ctx.fill();
                ctx.stroke();
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                drawHalf(ctx, leftValue, false);
                drawHalf(ctx, rightValue, true);
            }
        }

        Text {
            id: captionText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -50
            font.pixelSize: captionSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: caption
            color: captionColor
        }

        Text {
            id: leftValueText
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -36
            anchors.verticalCenterOffset: -8
            font.pixelSize: valueSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: Controller.getValue(leftValue) + unitSymbol
            color: "white"
        }

        Text {
            id: rightValueText
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 36
            anchors.verticalCenterOffset: -8
            font.pixelSize: valueSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: Controller.getValue(rightValue) + unitSymbol
            color: "white"
        }

        Text {
            id: gaugeNameText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 28
            font.pixelSize: nameSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: name
            color: "#F8E63C"
        }
    }
}
