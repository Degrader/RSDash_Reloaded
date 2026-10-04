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
    property color colour: primaryColor
    property color primaryColor
    property int size
    property int thick

    property int nameSize

    // How far the name sits below the centre, e.g. to leave room for an icon
    property int nameOffset: 0

    // Optional icon (a name from Icons.js), drawn in the text colour. With
    // an icon, the name sits below it (see nameOffset).
    property string icon: ""
    property int iconSize: 30
    property int iconOffset: 0

    property real minValue
    property real maxValue
    property real startAngleDegrees
    property real endAngleDegrees

    property real currentValue: 0

    // Repaint only when the value or colour actually changes, and skip
    // redrawing while hidden.
    onCurrentValueChanged: if (visible) buttonGaugeCanvas.requestPaint()
    onVisibleChanged: if (visible) buttonGaugeCanvas.requestPaint()
    onColourChanged: if (visible) buttonGaugeCanvas.requestPaint()
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
            anchors.verticalCenterOffset: nameOffset
            font.pixelSize: nameSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: name
            color: "#F8E63C"
        }

        SvgIcon {
            id: gaugeIcon
            anchors.centerIn: buttonGaugeCanvas
            anchors.verticalCenterOffset: iconOffset
            width: iconSize
            height: iconSize
            icon: buttonGaugeRect.icon
            color: "#F8E63C"
        }
    }
}
