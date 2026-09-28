/***************************************************************************
 *                                                                         *
 *   Copyright (C) 2024 by Fmods.net. All rights reserved.                 *
 *   Author: Au{R}oN                                                       *
 *   Developed in collaboration with Nutron - https://promoto.nutron.pl    *
 *   Any form of resale is prohibited.                                     *
 *                                                                         *
 ***************************************************************************/

import QtQuick 2.6
import QtQuick.Controls 1.3

import "Controller.js" as Controller

Rectangle {
    id: plsamaGaugeRect
    color: "transparent"

    property string name
    property string unitSymbol

    property color colour
    property color primaryColor
    property color secondaryColor

    property int nameSize
    property int valueSize

    property int size
    property int thick

    property string measureType
    property int decimal

    property real minValue
    property real maxValue

    property real startAngleDegrees
    property real endAngleDegrees

    property real lowTreshold
    property real highTreshold

    property bool reverse: false
    property bool ignoreUnit: false

    // Blue/red marks on the ring at lowTreshold/highTreshold
    property bool showThresholdMarks: measureType === "temperature"

    property real currentValue: 0

    // Repaint only when the value actually changes, instead of an
    // unconditional 10x/second timer. This also
    // means a gauge that's currently hidden (e.g. behind another view)
    // does no redraw work at all until it becomes visible again.
    onCurrentValueChanged: if (visible) plasmaGaugeCanvas.requestPaint()
    onVisibleChanged: if (visible) plasmaGaugeCanvas.requestPaint()
    Component.onCompleted: plasmaGaugeCanvas.requestPaint()

    Item {
        anchors.centerIn: parent
        anchors.fill: parent
        Canvas {
            id: plasmaGaugeCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                var centerX = width / 2;
                var centerY = height / 2;
                var radius = Math.min(centerX, centerY);

                var startAngle = startAngleDegrees;
                var endAngle = endAngleDegrees;

                var normalizedValue = Math.min(Math.max((currentValue - minValue) / (maxValue - minValue), 0), 1);

                var delta = reverse ? (360 - (endAngle - startAngle)) : (endAngle - startAngle);

                var progressAngle = startAngle + (reverse ? -normalizedValue : normalizedValue) * delta;

                if (currentValue < lowTreshold || currentValue > highTreshold) {
                    colour = secondaryColor
                } else {
                    colour = primaryColor
                }

                ctx.reset();
                ctx.strokeStyle = "#1e1e1e";
                ctx.lineCap = "round";
                ctx.lineWidth = thick;
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius - thick, startAngle * Math.PI / 180, endAngle * Math.PI / 180, reverse);
                ctx.stroke();

                Controller.drawValueArc(ctx, centerX, centerY, radius - thick, thick, startAngle, progressAngle, reverse, colour);

                if (showThresholdMarks) {
                    Controller.drawThresholdMarks(ctx, centerX, centerY, radius - thick, thick, function(value) {
                        var n = (value - minValue) / (maxValue - minValue);
                        return startAngle + (reverse ? -n : n) * delta;
                    });
                }
            }
        }

        Text {
            id: gaugeValueText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -15
            font.pixelSize: valueSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: Controller.getValue() + unitSymbol
            color: "white"
        }

        Text {
            id: gaugeNameText
            anchors.centerIn: gaugeValueText
            anchors.verticalCenterOffset: 40
            font.pixelSize: nameSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: name
            color: "#F8E63C"
        }
    }
}
