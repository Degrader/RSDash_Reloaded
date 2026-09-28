/***************************************************************************
 *                                                                         *
 *   Copyright (C) 2024 by Fmods.net. All rights reserved.                 *
 *   Author: Au{R}oN                                                       *
 *   Developed in collaboration with Nutron - https://promoto.nutron.pl    *
 *   Any form of resale is prohibited.                                     *
 *                                                                         *
 ***************************************************************************/

import QtQuick 2.6

// Picker that fans a few options out in an arc from one of the page's
// buttons (hub). Setting open = true dims the page and slides the option
// buttons out from the hub; picking one emits picked(value) and closes.
// Tapping the hub, anywhere else, or waiting closeAfterMs also closes it
// without changing anything.
//
// Fill the page with it and declare it last so it sits above everything.
Item {
    id: fanRoot

    property bool open: false
    // The value of the option to light, e.g. the current drive mode
    property int currentValue: 0
    property int closeAfterMs: 8000

    // The button the fan opens from; the fan is centred on it
    property Item hub

    // Distance from the hub's centre to each option button's centre, the
    // angle between neighbouring buttons, and the direction the middle of
    // the arc points (degrees; 0 points right, negative is up)
    property real radius: 200
    property real stepDegrees: 30
    property real centerDegrees: 0
    property int buttonSize: 88

    // [{ name, value }], first at the top of the arc
    property var options: []

    signal picked(int value)

    function nameFor(value) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].value === value) return options[i].name;
        }
        return "?";
    }

    // The option button at index i, e.g. for the dev harness to tap
    function optionButton(i) {
        return optionRepeater.itemAt(i);
    }

    // Hub centre in this item's coordinates. Read when opening, since the
    // page's layout is settled by then.
    property real hubX: 0
    property real hubY: 0
    onOpenChanged: {
        if (open && hub) {
            var p = hub.mapToItem(fanRoot, hub.width / 2, hub.height / 2)
            hubX = p.x
            hubY = p.y
        }
    }

    // 0 closed, 1 open. The buttons move and fade with it; nothing is
    // resized, so their canvases don't repaint per frame.
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    visible: progress > 0

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.85 * fanRoot.progress
    }

    // Swallows taps so nothing underneath reacts; a tap outside the option
    // buttons (including on the hub) closes without a change.
    MouseArea {
        id: dismissArea
        anchors.fill: parent
        enabled: fanRoot.open
        onClicked: fanRoot.open = false
    }

    // Stands in for the hub button while the page underneath is dimmed
    ButtonGauge {
        id: hubCopy
        x: fanRoot.hubX - width / 2
        y: fanRoot.hubY - height / 2
        width: fanRoot.hub ? fanRoot.hub.width : 0
        height: width
        size: width
        thick: fanRoot.hub ? fanRoot.hub.thick : 0
        opacity: fanRoot.progress

        name: fanRoot.hub ? fanRoot.hub.name : ""
        nameSize: fanRoot.hub ? fanRoot.hub.nameSize : 0
        nameOffset: fanRoot.hub ? fanRoot.hub.nameOffset : 0
        statusText: "Close"
        showStatus: 1
        primaryColor: "#329BFD"
        currentValue: 1

        minValue: 0
        maxValue: 1
        startAngleDegrees: 0
        endAngleDegrees: 360
    }

    Repeater {
        id: optionRepeater
        model: fanRoot.options

        ButtonGauge {
            readonly property real angle: (fanRoot.centerDegrees + (index - (fanRoot.options.length - 1) / 2) * fanRoot.stepDegrees) * Math.PI / 180
            readonly property real distance: fanRoot.radius * fanRoot.progress

            x: fanRoot.hubX + distance * Math.cos(angle) - width / 2
            y: fanRoot.hubY + distance * Math.sin(angle) - height / 2
            width: size
            height: size
            opacity: fanRoot.progress

            name: modelData.name
            primaryColor: "#0c32ff"
            nameSize: 17

            size: fanRoot.buttonSize
            thick: 10

            minValue: 0
            maxValue: 1
            currentValue: fanRoot.currentValue === modelData.value ? 1 : 0

            startAngleDegrees: 0
            endAngleDegrees: 360

            // Solid centre so the dimmed gauges don't show through the text
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 2 * parent.thick
                height: width
                radius: width / 2
                color: "black"
                z: -1
            }

            MouseArea {
                anchors.fill: parent
                enabled: fanRoot.open
                onClicked: {
                    fanRoot.open = false
                    fanRoot.picked(modelData.value)
                }
            }
        }
    }

    Timer {
        interval: fanRoot.closeAfterMs
        running: fanRoot.open
        onTriggered: fanRoot.open = false
    }
}
