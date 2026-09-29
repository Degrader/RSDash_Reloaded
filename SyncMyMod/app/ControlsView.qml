/***************************************************************************
 *                                                                         *
 *   Copyright (C) 2024 by Fmods.net. All rights reserved.                 *
 *   Author: Au{R}oN                                                       *
 *   Developed in collaboration with Nutron - https://promoto.nutron.pl    *
 *   Any form of resale is prohibited.                                     *
 *                                                                         *
 ***************************************************************************/

import QtQuick 2.6

import "Components"
import "Components/Controller.js" as Controller

// The car controls the ESP32 offers, as a grid of tiles, opened by tapping
// the logo on the main view. Launch Control, ESP Sport and auto start-stop
// switch on and off with a tap; Drive Mode and Drift Stick open a pop-up to
// pick an option. To add a control, add a ControlTile to controlGrid.
Rectangle {
    id: controlsViewRect
    width: 800
    height: 480
    color: "black"

    // --- The ESP32's settings, read on opening and every 5 s after, so the
    // page catches up if a setting changes from the RSapp phone app

    property var settingsData: [
        { gaugeId: lcState,             param: "enableLC" },
        { gaugeId: espState,            param: "esp" },
        { gaugeId: startStopState,      param: "disableStartStop" },
        { gaugeId: driveModeState,      param: "driveMode" },
        { gaugeId: driftStickState,     param: "enableDriftMode" },
        { gaugeId: driftInState,        param: "driftInAllModes" }
    ]

    Item { id: lcState;         property real currentValue: 0 }
    Item { id: espState;        property real currentValue: 0 }
    Item { id: startStopState;  property real currentValue: 0 }
    Item { id: driveModeState;  property real currentValue: 0 }
    Item { id: driftStickState; property real currentValue: 0 }
    // Whether Drift Stick works in every drive mode (1) or only in Drift (0)
    Item { id: driftInState;    property real currentValue: 0 }

    Timer {
        id: settingsTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: Controller.fetchData("settings", settingsData)
    }

    Component.onCompleted: Controller.fetchData("settings", settingsData)

    // Drift Stick as one choice: 0 off, 1 Drift mode only, 2 all modes
    readonly property int driftStickChoice: driftStickState.currentValue !== 1 ? 0
                                            : (driftInState.currentValue === 1 ? 2 : 1)

    // Sends only what changes. Turning it on goes first and the mode choice
    // follows once the ESP32 accepts, the same order as the original app.
    function setDriftStick(choice) {
        var name = driftStickPopup.nameFor(choice).replace("\n", " ")
        var done = function(ok) { showToast(ok, "Drift Stick: " + name) }
        if (choice === 0) {
            if (driftStickState.currentValue !== 0)
                Controller.sendData("settings", "enableDriftMode", 0, driftStickState, done)
            return
        }
        var allModes = choice === 2 ? 1 : 0
        var setModes = function() {
            if (driftInState.currentValue !== allModes)
                Controller.sendData("settings", "driftInAllModes", allModes, driftInState, done)
            else
                done(true)
        }
        if (driftStickState.currentValue !== 1) {
            Controller.sendData("settings", "enableDriftMode", 1, driftStickState, function(ok) {
                if (ok) setModes(); else done(false)
            })
        } else {
            setModes()
        }
    }

    // Flips an on/off setting and says what happened
    function toggle(param, state, onMessage, offMessage) {
        var newValue = state.currentValue ? 0 : 1
        Controller.sendData("settings", param, newValue, state, function(ok) {
            showToast(ok, newValue ? onMessage : offMessage)
        })
    }

    // --- Page

    Image {
        id: backButton
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 5
        width: 34
        fillMode: Image.PreserveAspectFit
        source: "res/back.png"
        mipmap: true
        antialiasing: true

        MouseArea {
            anchors.fill: parent
            onClicked: loader.source = "PrimaryView.qml"
        }
    }

    Text {
        id: controlsTitle
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        font.pixelSize: 34
        font.weight: Font.Bold
        text: "Controls"
        color: "#329BFD"
    }

    // Three across; the sixth space is free for a future control
    Grid {
        id: controlGrid
        anchors.top: controlsTitle.bottom
        anchors.topMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 3
        columnSpacing: 40
        rowSpacing: 8

        ControlTile {
            id: lcTile
            label: "Launch Control"
            status: lit ? "On" : "Off"
            icon: "launchControl"
            colour: lcColour
            lit: lcState.currentValue === 1
            onTapped: toggle("enableLC", lcState, "Launch Control on", "Launch Control off")
        }

        ControlTile {
            id: espTile
            label: "ESP Sport"
            status: (lit ? "On" : "Off") + " at startup"
            icon: "espSport"
            colour: espColour
            lit: espState.currentValue === 1
            onTapped: toggle("esp", espState, "ESP Sport on from the next start", "ESP Sport off from the next start")
        }

        ControlTile {
            id: driveModeTile
            label: "Drive Mode"
            status: driveModePopup.nameFor(driveModeState.currentValue) + " at startup"
            icon: driveModePopup.iconFor(driveModeState.currentValue)
            colour: driveModeColour
            lit: true
            onTapped: driveModePopup.open = true
        }

        ControlTile {
            id: startStopTile
            label: "Auto Start-Stop"
            status: (lit ? "Off" : "On") + " at startup"
            icon: "autoStartStopOff"
            colour: startStopColour
            lit: startStopState.currentValue === 1
            onTapped: toggle("disableStartStop", startStopState,
                             "Auto start-stop off from the next start", "Auto start-stop on from the next start")
        }

        ControlTile {
            id: driftStickTile
            label: "Drift Stick"
            status: driftStickPopup.nameFor(driftStickChoice).replace("\n", " ")
            icon: "driftStick"
            colour: driftStickColour
            lit: driftStickChoice !== 0
            onTapped: driftStickPopup.open = true
        }
    }

    Text {
        id: controlsNote
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 40
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        color: "#FFFFFF"
        text: "ESP Sport, Auto Start-Stop and Drive Mode apply the next time the car starts; "
              + "while driving, use the car's own buttons. Launch Control and Drift Stick work right away."
    }

    // --- Short note after a change: what it does, or that it failed

    function showToast(ok, message) {
        toast.text = ok ? message : "Couldn't reach the ESP32 - not changed"
        toast.failed = !ok
        toastTimer.restart()
    }

    Rectangle {
        id: toast
        property alias text: toastText.text
        property bool failed: false
        z: 900
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: controlsNote.top
        anchors.bottomMargin: 8
        width: toastText.width + 28
        height: toastText.height + 16
        radius: height / 2
        color: "black"
        border.width: 2
        border.color: failed ? "#ce1845" : "#329BFD"
        opacity: toastTimer.running ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            id: toastText
            anchors.centerIn: parent
            font.pixelSize: 17
            font.weight: Font.Bold
            color: "#F8E63C"
        }
    }

    Timer {
        id: toastTimer
        interval: 3500
    }

    // --- Pop-ups, last so they cover the page

    OptionPopup {
        id: driveModePopup
        anchors.fill: parent
        z: 1000
        title: "Startup drive mode"
        subtitle: "The mode the car starts in. Applies the next time the car starts."
        accentColour: driveModeColour
        // driveMode values the ESP32 expects (4 isn't used)
        options: [
            { name: "Normal", value: 0, icon: "modeNormal" },
            { name: "Sport",  value: 1, icon: "modeSport" },
            { name: "Track",  value: 2, icon: "modeTrack" },
            { name: "Drift",  value: 3, icon: "modeDrift" },
            { name: "Custom", value: 5, icon: "modeCustom" }
        ]
        currentValue: driveModeState.currentValue
        onPicked: {
            var mode = nameFor(value)
            Controller.sendData("settings", "driveMode", value, driveModeState, function(ok) {
                showToast(ok, "Starts in " + mode + " mode from the next start")
            })
        }
    }

    OptionPopup {
        id: driftStickPopup
        anchors.fill: parent
        z: 1000
        title: "Drift Stick"
        subtitle: "Rear wheel lock through the ABS. Works right away."
        accentColour: driftStickColour
        options: [
            { name: "Off",         value: 0 },
            { name: "Drift\nOnly", value: 1 },
            { name: "All\nModes",  value: 2 }
        ]
        currentValue: driftStickChoice
        onPicked: setDriftStick(value)
    }
}
