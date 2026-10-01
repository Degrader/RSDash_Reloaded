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

// The car controls the ESP32 offers, as tiles in two rows, opened by tapping
// the logo on the main view. The top row changes the car straight away; the
// "Startup" row is preferences applied the next time the car starts. Launch
// Control, ESP Sport and auto start-stop switch on and off with a tap; the
// drive mode, ESP and Drift Stick tiles open a pop-up to pick an option. To
// add a control, add a ControlTile to liveRow or startupRow.
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

    // --- What the car is doing now, from /pids, read every second. -1 means
    // unknown: the car is asleep or silent, or the firmware is too old to say.
    // Drive mode: 0 Normal, 1 Sport, 2 Track, 3 Drift. ESP: 0 On, 1 Sport, 2 Off.

    property var liveData: [
        { gaugeId: liveModeState, param: "mode" },
        { gaugeId: liveEscState,  param: "esc" }
    ]

    Item {
        id: liveModeState
        property real currentValue: -1
        onCurrentValueChanged: if (currentValue === modePending) modePending = -1
    }

    Item {
        id: liveEscState
        property real currentValue: -1
        onCurrentValueChanged: if (currentValue === escPending) escPending = -1
    }

    // A change the car is still making (-1: none). A drive mode change takes
    // about 5 s; the tile says so until /pids shows it, or pendingTimer gives up.
    property int modePending: -1
    property int escPending: -1

    Timer {
        id: pendingTimer
        interval: 15000
        onTriggered: { modePending = -1; escPending = -1 }
    }

    Timer {
        id: liveTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: Controller.fetchData("pids", liveData)
    }

    Component.onCompleted: {
        Controller.fetchData("settings", settingsData)
        Controller.fetchData("pids", liveData)
    }

    // Tells the car to change now (POST /control) and waits for /pids to show it
    function setLive(param, value, message) {
        var done = function(ok, status) {
            if (!ok) {
                if (param === "mode") modePending = -1; else escPending = -1
                showToast(false, "", status)
                return
            }
            showToast(true, message)
        }
        if (param === "mode") modePending = value; else escPending = value
        pendingTimer.restart()
        Controller.sendData("control", param, value, null, done)
    }

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
            onClicked: loader.source = mainPageSource
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

    // --- The top row changes the car straight away

    Row {
        id: liveRow
        anchors.top: controlsTitle.bottom
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 20

        ControlTile {
            id: liveDriveModeTile
            label: "Drive Mode"
            status: modePending >= 0 ? "Changing to " + liveDriveModePopup.nameFor(modePending) + "..."
                    : (liveModeState.currentValue >= 0 ? liveDriveModePopup.nameFor(liveModeState.currentValue) : "Not available")
            icon: liveDriveModePopup.iconFor(liveModeState.currentValue)
            colour: driveModeColour
            lit: liveModeState.currentValue >= 0
            onTapped: liveDriveModePopup.open = true
        }

        ControlTile {
            id: escTile
            label: "ESP"
            status: escPending >= 0 ? "Changing to " + escPopup.nameFor(escPending) + "..."
                    : (liveEscState.currentValue >= 0 ? escPopup.nameFor(liveEscState.currentValue) : "Not available")
            icon: "espSport"
            colour: espColour
            lit: liveEscState.currentValue > 0
            onTapped: escPopup.open = true
        }

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
            id: driftStickTile
            label: "Drift Stick"
            status: driftStickPopup.nameFor(driftStickChoice).replace("\n", " ")
            icon: "driftStick"
            colour: driftStickColour
            lit: driftStickChoice !== 0
            onTapped: driftStickPopup.open = true
        }
    }

    // --- At startup: preferences the car applies the next time it starts

    Text {
        id: startupHeading
        anchors.left: liveRow.left
        anchors.top: liveRow.bottom
        anchors.topMargin: 6
        font.pixelSize: 16
        font.weight: Font.Bold
        color: "#329BFD"
        text: "STARTUP"
    }

    Rectangle {
        anchors.left: startupHeading.right
        anchors.leftMargin: 10
        anchors.right: liveRow.right
        anchors.verticalCenter: startupHeading.verticalCenter
        height: 1
        color: "#329BFD"
        opacity: 0.5
    }

    Row {
        id: startupRow
        anchors.top: startupHeading.bottom
        anchors.topMargin: 4
        anchors.left: liveRow.left
        spacing: liveRow.spacing

        ControlTile {
            id: driveModeTile
            label: "Drive Mode"
            status: driveModeState.currentValue === 5 ? "Custom" : driveModePopup.nameFor(driveModeState.currentValue)
            icon: driveModeState.currentValue === 5 ? "modeCustom" : driveModePopup.iconFor(driveModeState.currentValue)
            colour: driveModeColour
            lit: true
            onTapped: driveModePopup.open = true
        }

        ControlTile {
            id: espTile
            label: "ESP Sport"
            status: lit ? "On" : "Off"
            icon: "espSport"
            colour: espColour
            lit: espState.currentValue === 1
            onTapped: toggle("esp", espState, "ESP Sport on from the next start", "ESP Sport off from the next start")
        }

        ControlTile {
            id: startStopTile
            label: "Auto Start-Stop"
            status: lit ? "Off" : "On"
            icon: "autoStartStopOff"
            colour: startStopColour
            lit: startStopState.currentValue === 1
            onTapped: toggle("disableStartStop", startStopState,
                             "Auto start-stop off from the next start", "Auto start-stop on from the next start")
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
        text: "The top controls change the car straight away (a drive mode change takes a few seconds). "
              + "Those under Startup are saved and apply the next time the car starts."
    }

    // --- Short note after a change: what it does, or that it failed

    // status: the ESP32's HTTP status for a failure, if it answered. (Qt reports
    // a 409 "change already in progress" as no answer, so it gets the default.)
    function showToast(ok, message, status) {
        var failure = "Couldn't reach the ESP32 - not changed"
        if (status === 503) failure = "The car isn't ready (asleep, or no CAN) - not changed"
        else if (status === 404) failure = "This ESP32 firmware can't do that yet - not changed"
        toast.text = ok ? message : failure
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
        // driveMode values the ESP32 expects. It also takes 5 (Custom, which leaves
        // the car's mode alone), no longer offered here; driveModeTile still shows
        // it if the ESP32 has it saved.
        options: [
            { name: "Normal", value: 0, icon: "modeNormal" },
            { name: "Sport",  value: 1, icon: "modeSport" },
            { name: "Track",  value: 2, icon: "modeTrack" },
            { name: "Drift",  value: 3, icon: "modeDrift" }
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
        id: liveDriveModePopup
        anchors.fill: parent
        z: 1000
        title: "Drive mode now"
        subtitle: "Changes the car's drive mode right away. It takes about 5 seconds."
        accentColour: driveModeColour
        // The values POST /control takes
        options: [
            { name: "Normal", value: 0, icon: "modeNormal" },
            { name: "Sport",  value: 1, icon: "modeSport" },
            { name: "Track",  value: 2, icon: "modeTrack" },
            { name: "Drift",  value: 3, icon: "modeDrift" }
        ]
        currentValue: liveModeState.currentValue
        onPicked: {
            if (value !== liveModeState.currentValue)
                setLive("mode", value, "Switching to " + nameFor(value) + " mode")
        }
    }

    OptionPopup {
        id: escPopup
        anchors.fill: parent
        z: 1000
        title: "ESP now"
        subtitle: "Changes the car's stability control right away."
        accentColour: espColour
        options: [
            { name: "On",    value: 0 },
            { name: "Sport", value: 1 },
            { name: "Off",   value: 2 }
        ]
        currentValue: liveEscState.currentValue
        onPicked: {
            if (value !== liveEscState.currentValue)
                setLive("esc", value, "ESP " + nameFor(value))
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
