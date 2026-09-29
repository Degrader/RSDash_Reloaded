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

    // Vertical positions of the name and status text, e.g. to fit a
    // two-line name or an icon above the status.
    property int nameOffset: 0
    property int statusOffset: 15
    property int statusSize: 10

    // Optional small line above the name, in the same size as the status
    // (e.g. "Drive" over the drive mode's name, with "Mode" under it)
    property string topText: ""
    property int topOffset: -15

    // Optional icon (a name from Icons.js), drawn in the text colour. With
    // an icon, the status line usually carries the button's label below it.
    property string icon: ""
    property int iconSize: 30
    property int iconOffset: 0

    // Optional label on a solid black rounded backing, so it stays
    // readable over the icon or the ring (e.g. the drive mode's name).
    // badgeOffset moves it down from the centre; can be two lines.
    property string badgeText: ""
    property int badgeSize: 11
    property int badgeOffset: 0
    readonly property alias badgeWidth: badge.width
    readonly property alias badgeHeight: badge.height

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

        Text {
            id: gaugeTopText
            anchors.centerIn: buttonGaugeCanvas
            anchors.verticalCenterOffset: topOffset
            font.pixelSize: 10
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            visible: topText !== ""
            text: topText
            color: "#F8E63C"
        }

        Text {
            id: gaugeStatusText
            anchors.centerIn: buttonGaugeCanvas
            anchors.verticalCenterOffset: statusOffset
            font.pixelSize: statusSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            visible: showStatus == 1 ? true : false
            text: statusText
            color: "#F8E63C"
        }

        Rectangle {
            id: badge
            anchors.centerIn: buttonGaugeCanvas
            anchors.verticalCenterOffset: badgeOffset
            visible: badgeText !== ""
            width: badgeLabel.width + 8
            height: badgeLabel.height + 2
            radius: height / 2
            color: "black"

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                font.pixelSize: badgeSize
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 0.9
                text: badgeText
                color: "#F8E63C"
            }
        }
    }
}
