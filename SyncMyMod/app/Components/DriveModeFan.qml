/***************************************************************************
 *                                                                         *
 *   Copyright (C) 2024 by Fmods.net. All rights reserved.                 *
 *   Author: Au{R}oN                                                       *
 *   Developed in collaboration with Nutron - https://promoto.nutron.pl    *
 *   Any form of resale is prohibited.                                     *
 *                                                                         *
 ***************************************************************************/

import QtQuick 2.6

// Drive mode picker that fans out in an arc to the right of the page's
// drive mode button (hub). Setting open = true dims the page and slides the
// mode buttons out from the hub; picking one emits picked(value) and closes.
// Tapping the hub, anywhere else, or waiting closeAfterMs also closes it
// without changing anything.
//
// Fill the page with it and declare it last so it sits above everything.
Item {
    id: fanRoot

    property bool open: false
    property int currentMode: 0
    property int closeAfterMs: 8000

    // The button the fan opens from; the fan is centred on it
    property Item hub

    // Distance from the hub's centre to each mode button's centre, and the
    // angle between neighbouring buttons (0 degrees points right)
    property real radius: 200
    property real stepDegrees: 30
    property int buttonSize: 88

    // driveMode values the ESP32 expects (4 isn't used), top to bottom
    property var modes: [
        { name: "Normal", value: 0 },
        { name: "Sport",  value: 1 },
        { name: "Track",  value: 2 },
        { name: "Drift",  value: 3 },
        { name: "Custom", value: 5 }
    ]

    signal picked(int value)

    function nameFor(value) {
        for (var i = 0; i < modes.length; i++) {
            if (modes[i].value === value) return modes[i].name;
        }
        return "?";
    }

    // The mode button at index i, e.g. for the dev harness to tap
    function modeButton(i) {
        return modeRepeater.itemAt(i);
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

    // Swallows taps so nothing underneath reacts; a tap outside the mode
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

        name: fanRoot.nameFor(fanRoot.currentMode)
        nameSize: fanRoot.hub ? fanRoot.hub.nameSize : 0
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
        id: modeRepeater
        model: fanRoot.modes

        ButtonGauge {
            readonly property real angle: (index - (fanRoot.modes.length - 1) / 2) * fanRoot.stepDegrees * Math.PI / 180
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
            currentValue: fanRoot.currentMode === modelData.value ? 1 : 0

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
