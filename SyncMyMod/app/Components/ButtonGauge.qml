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

Rectangle {
    id: buttonGaugeRect
    color: "transparent"

    property string name
    property string statusText
    property color colour: primaryColor
    property color primaryColor
    property int size
    property int thick

    property int showStatus: 0

    property int nameSize
    property int valueSize

    property real minValue
    property real maxValue
    property real startAngleDegrees
    property real endAngleDegrees

    property real currentValue: 0

    // Repaint only when the value actually changes, and skip redrawing
    // while hidden (this component is also used for always-invisible
    // "dummy" gauges, which now never have to paint at all).
    onCurrentValueChanged: if (visible) buttonGaugeCanvas.requestPaint()
    onVisibleChanged: if (visible) buttonGaugeCanvas.requestPaint()
    Component.onCompleted: buttonGaugeCanvas.requestPaint()

    Item  {
        anchors.centerIn: parent
        anchors.fill: parent
        Canvas {
            id: buttonGaugeCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                var centerX = width / 2;
                var centerY = height / 2;
                var radius = Math.min(centerX, centerY);

                var startAngle = startAngleDegrees;
                var endAngle = endAngleDegrees;

                var normalizedValue = Math.min(Math.max((currentValue - minValue) / (maxValue - minValue), 0), 1);

                var delta = endAngle - startAngle

                var progressAngle = startAngle + normalizedValue * delta;

                ctx.reset();
                ctx.strokeStyle = "#1e1e1e";
                ctx.lineCap = "round";
                ctx.lineWidth = thick;
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius - thick, startAngle * Math.PI / 180, endAngle * Math.PI / 180);
                ctx.stroke();

                ctx.strokeStyle = colour;
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius - thick, startAngle * Math.PI / 180, progressAngle * Math.PI / 180);
                ctx.stroke();
            }
        }

        Text {
            id: gaugeNameText
            anchors.centerIn: buttonGaugeCanvas
            font.pixelSize: nameSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: name
            color: "#F8E63C"
        }

        Text {
            id: gaugeStatusText
            anchors.centerIn: buttonGaugeCanvas
            anchors.verticalCenterOffset: 15
            font.pixelSize: 10
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            visible: showStatus == 1 ? true : false
            text: statusText
            color: "#F8E63C"
        }
    }
}
