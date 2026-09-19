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
    id: ecuGauge
    color: "transparent"

    property string name
    property string statusText
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

    property real currentValue: 1

    // Repaint only when the value actually changes, and skip redrawing
    // while hidden.
    onCurrentValueChanged: if (visible) ecuGaugeCanvas.requestPaint()
    onVisibleChanged: if (visible) ecuGaugeCanvas.requestPaint()
    Component.onCompleted: ecuGaugeCanvas.requestPaint()

    Item {
        anchors.centerIn: parent
        anchors.fill: parent
        Canvas {
            id: ecuGaugeCanvas
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

                ctx.strokeStyle = primaryColor;
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius - thick, startAngle * Math.PI / 180, progressAngle * Math.PI / 180);
                ctx.stroke();
            }
        }

        Text {
            id: ecuGaugeText
            anchors.centerIn: ecuGaugeCanvas
            anchors.verticalCenterOffset: -3
            font.pixelSize: nameSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: name
            color: "#F8E63C"
        }
    }
}
