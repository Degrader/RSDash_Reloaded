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

import "Components"
import "Components/Controller.js" as Controller

Rectangle {
    id: primaryViewRect
    width: 800
    height: 480
    color: "black"

    property var pidsData: [
        { gaugeId: ptuGauge,            param: "ptu" },
        { gaugeId: rduGauge,            param: "rdu" },
        { gaugeId: lambdaGauge,         param: "lambda" },
        { gaugeId: oilGauge,            param: "engine" },

        { gaugeId: frontLeftTireGauge,  param: "flw" },
        { gaugeId: frontRightTireGauge, param: "frw" },
        { gaugeId: rearLeftTireGauge,   param: "rlw" },
        { gaugeId: rearRightTireGauge,  param: "rrw" },

        { gaugeId: leftRDUTempGauge,    param: "rdutl" },
        { gaugeId: rightRDUTempGauge,   param: "rdutr" },
        { gaugeId: leftRDUTqGauge,      param: "rdutql" },
        { gaugeId: rightRDUTqGauge,     param: "rdutqr" }
    ]

    property var settingsData: [
        { gaugeId: lcGauge,             param: "enableLC" },
        { gaugeId: driftStickGauge,     param: "enableDriftMode" },
        { gaugeId: espGauge,            param: "esp" },
        { gaugeId: autoStartStopGauge,  param: "disableStartStop" },
        { gaugeId: driveModeState,      param: "driveMode" },
        { gaugeId: driftInState,        param: "driftInAllModes" }
    ]

    Image {
        id: closeButton
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 5
        width: 34
        fillMode: Image.PreserveAspectFit
        source: "res/close.png"
        mipmap: true

        MouseArea {
            anchors.fill: parent
            onClicked: {
                backMouseArea.enabled = true
                back();
            }
        }
    }


    Image {
        id: readyToRaceLogo
        anchors.centerIn: parent
        height: 400
        z: 999
        fillMode: Image.PreserveAspectFit
        source: "res/rtr.png"
        smooth: true
        mipmap: true
        scale: 1.0
        opacity: 0.0

        // rtrDisplayed is checked in onConditionOkChanged rather than here:
        // fadeInAnim sets it while conditionOk is still changing, which made
        // this a binding loop.
        property bool conditionOk: oilGauge.currentValue >= oilGauge.lowTreshold
                                   && rduGauge.currentValue >= rduGauge.lowTreshold
                                   && ptuGauge.currentValue >= ptuGauge.lowTreshold

        Timer {
            id: mainTimer
            interval: 3000
            repeat: false
            onTriggered: {
                fadeOutAnim.start()
                scaleAnim.running = false
            }
        }

        SequentialAnimation {
            id: fadeInAnim
            running: false
            onStarted: {
                readyToRaceLogo.opacity = 0
                readyToRaceLogo.scale = 1.0
                scaleAnim.running = true
                rtrDisplayed = true
            }
            PropertyAnimation { target: readyToRaceLogo; property: "opacity"; from: 0; to: 1; duration: 500 }
            ScriptAction { script: mainTimer.start() }
        }

        PropertyAnimation {
            id: fadeOutAnim
            target: readyToRaceLogo
            property: "opacity"
            from: 1
            to: 0
            duration: 500
        }

        SequentialAnimation {
            id: scaleAnim
            loops: Animation.Infinite
            running: false
            PropertyAnimation { target: readyToRaceLogo; property: "scale"; to: 1.3; duration: 400; easing.type: Easing.InOutQuad }
            PropertyAnimation { target: readyToRaceLogo; property: "scale"; to: 0.8; duration: 400; easing.type: Easing.InOutQuad }
        }

        onConditionOkChanged: {
            if (conditionOk && !rtrDisplayed) {
                fadeInAnim.start()
            }
        }
    }

    Image {
        id: settingsButton
        // Beside the close button; the right column runs to the top edge
        anchors.top: closeButton.top
        anchors.left: closeButton.right
        anchors.leftMargin: 10
        width: 34
        fillMode: Image.PreserveAspectFit
        source: "res/settings.png"
        mipmap: true

        MouseArea {
            anchors.fill: parent
            onClicked: loader.source = "SettingsView.qml"
        }
    }

    PlasmaGauge {
        id: ptuGauge
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.left: buttonColumn.right
        anchors.leftMargin: 6
        height: size
        width: size
        size: 210
        thick: 24

        unitSymbol: "°"

        name: "PTU"
        nameSize: 25

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 43
        minValue: 0
        maxValue: 130

        decimal: 0
        measureType: "temperature"

        lowTreshold: 50
        highTreshold: 110

        startAngleDegrees: 145
        endAngleDegrees: 395
    }

    PlasmaGauge {
        id: rduGauge
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.left: ptuGauge.left
        width: size
        height: size
        size: 210
        thick: 24

        unitSymbol: "°"

        name: "RDU"
        nameSize: 25

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 43
        minValue: 0
        maxValue: 130

        decimal: 0
        measureType: "temperature"

        lowTreshold: 20
        highTreshold: 110

        startAngleDegrees: 145
        endAngleDegrees: 395
    }

    PlasmaGauge {
        id: oilGauge
        anchors.top: ptuGauge.top
        anchors.left: ptuGauge.right
        anchors.leftMargin: 8
        height: size
        width: size
        size: 210
        thick: 24

        unitSymbol: "°"

        name: "Oil"
        nameSize: 24

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 43
        minValue: 0
        maxValue: 150

        decimal: 0
        measureType: "temperature"

        lowTreshold: 65
        highTreshold: 110

        startAngleDegrees: 145
        endAngleDegrees: 395
    }

    PlasmaGauge {
        id: lambdaGauge
        anchors.bottom: rduGauge.bottom
        anchors.left: oilGauge.left
        height: size
        width: size
        size: 210
        thick: 24

        unitSymbol: "^"
        ignoreUnit: true

        name: "Lambda"
        nameSize: 25

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        decimal: 2
        measureType: "raw"

        valueSize: 43
        minValue: 0
        maxValue: 2

        lowTreshold: 0.5
        highTreshold: 1.5

        startAngleDegrees: 145
        endAngleDegrees: 395

        // OBD "Alone" - see torqueSplitGauge for "Not Alone"
        visible: !notAlone
    }

    // In OBD "Not Alone" mode (settings page) the ESP32 stops requesting
    // lambda, the only value it asks the PCM for, so this slot shows how the
    // rear torque is split between the left and right RDU clutches instead:
    // each half is that clutch's share of the total, in %. The clutch torques
    // come from the AWD module and keep updating.
    SplitPlasmaGauge {
        id: torqueSplitGauge
        anchors.fill: lambdaGauge
        visible: notAlone

        // Below this total (Nm) there's no real split to show, e.g. cruising
        // or parked, so both halves read 0 instead of jumping around.
        readonly property real minTotal: 10
        readonly property real total: leftRDUTqGauge.currentValue + rightRDUTqGauge.currentValue

        thick: 24

        caption: "OBD\nNOT ALONE"
        captionColor: "#329BFD"
        captionSize: 14

        name: "Torque Split"
        nameSize: 20

        unitSymbol: "%"

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        // Spread out so "47%" and "53%" don't run together; "100%" still
        // clears the ring
        valueSize: 24
        valueSpread: 40
        decimal: 0
        measureType: "raw"

        minValue: 0
        maxValue: 100

        // A share is never "too high" or "too low", so it never turns red
        lowTreshold: 0
        highTreshold: 100

        leftValue: total >= minTotal ? 100 * leftRDUTqGauge.currentValue / total : 0
        rightValue: total >= minTotal ? 100 * rightRDUTqGauge.currentValue / total : 0
    }

    // In the free space between the four big gauges, pulsing. The top
    // gauges' rings are open at the bottom, so that space is centred higher
    // than the gauges themselves: midway between the lower ends of the top
    // rings and the tops of the bottom rings. The image has transparent
    // space above and below the artwork, so at 80 px tall the visible part
    // clears all four rings by about 14 px at the top of its pulse.
    Image {
        id: nutronLogo
        height: 80

        // Lowest point of the top rings (their ends) and highest point of
        // the bottom rings, including the rings' thickness
        readonly property real topRingsBottom: ptuGauge.y + ptuGauge.height / 2
            + (ptuGauge.width / 2 - ptuGauge.thick) * Math.sin(ptuGauge.startAngleDegrees * Math.PI / 180)
            + ptuGauge.thick / 2
        readonly property real bottomRingsTop: rduGauge.y + rduGauge.thick / 2

        x: (ptuGauge.x + oilGauge.x + oilGauge.width) / 2 - width / 2
        y: (topRingsBottom + bottomRingsTop) / 2 - height / 2
        fillMode: Image.PreserveAspectFit
        source: "res/mountuners.png"
        smooth: true
        mipmap: true

        Behavior on scale {
            NumberAnimation {
                duration: 3000
                easing.type: Easing.InOutQuad
            }
        }

        Timer {
            id: pulseTimer
            interval: 3000
            repeat: true
            running: true
            triggeredOnStart: true
            onTriggered: {
                if (scaleUp) {
                    nutronLogo.scale = 1.1
                } else {
                    nutronLogo.scale = 1.0
                }
                scaleUp = !scaleUp
            }
            property bool scaleUp: true
        }
    }

    // Controls down the left edge, under the close button. Each ring is lit
    // while its setting is on.
    Column {
        id: buttonColumn
        anchors.top: closeButton.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.leftMargin: 6
        spacing: 8

        ButtonGauge {
            id: lcGauge
            width: size
            height: size
            size: 80
            thick: 9

            icon: "launchControl"
            iconSize: 38

            primaryColor: lcColour

            minValue: 0
            maxValue: 1

            startAngleDegrees: 0
            endAngleDegrees: 360

            MouseArea {
                id: lcButton
                anchors.fill: parent
                onClicked: {
                    var newValue = lcGauge.currentValue ? 0 : 1
                    Controller.sendData("settings", "enableLC", newValue, lcGauge)
                }
            }
        }

        ButtonGauge {
            id: espGauge
            width: size
            height: size
            size: 80
            thick: 9

            icon: "espSport"
            iconSize: 38

            primaryColor: espColour

            minValue: 0
            maxValue: 1

            startAngleDegrees: 0
            endAngleDegrees: 360

            MouseArea {
                id: espButton
                anchors.fill: parent
                onClicked: {
                    var newValue = espGauge.currentValue ? 0 : 1
                    Controller.sendData("settings", "esp", newValue, espGauge, function(ok) {
                        showStartupToast(ok, newValue ? "ESP Sport on from the next start"
                                                      : "ESP Sport off from the next start")
                    })
                }
            }
        }

        // Shows the drive mode; tapping it fans the modes out to the right.
        // In the middle of the column so the fan has the full height.
        ButtonGauge {
            id: driveModeGauge
            width: size
            height: size
            size: 80
            thick: 9

            // The current mode's icon, with its name on a tab over the
            // bottom of the ring
            icon: driveModeFan.iconFor(driveModeState.currentValue)
            iconSize: 38
            badgeText: driveModeFan.nameFor(driveModeState.currentValue)
            badgeSize: 10
            badgeOffset: 30
            currentValue: 1

            primaryColor: driveModeColour

            minValue: 0
            maxValue: 1

            startAngleDegrees: 0
            endAngleDegrees: 360

            MouseArea {
                id: driveModeButton
                anchors.fill: parent
                onClicked: driveModeFan.open = true
            }
        }

        ButtonGauge {
            id: autoStartStopGauge
            width: size
            height: size
            size: 80
            thick: 9

            icon: "autoStartStopOff"
            iconSize: 38

            primaryColor: startStopColour

            minValue: 0
            maxValue: 1

            startAngleDegrees: 0
            endAngleDegrees: 360

            MouseArea {
                id: autoStartStopButton
                anchors.fill: parent
                onClicked: {
                    var newValue = autoStartStopGauge.currentValue ? 0 : 1
                    Controller.sendData("settings", "disableStartStop", newValue, autoStartStopGauge, function(ok) {
                        showStartupToast(ok, newValue ? "Auto start-stop off from the next start"
                                                      : "Auto start-stop on from the next start")
                    })
                }
            }
        }

        // Lit while Drift Stick is on; the status shows where it works.
        // Tapping it fans out Off / Drift Only / All Modes.
        ButtonGauge {
            id: driftStickGauge
            width: size
            height: size
            size: 80
            thick: 9

            // The lever icon, with the current choice on a tab over the
            // bottom of the ring
            icon: "driftStick"
            iconSize: 38
            badgeText: driftStickFan.nameFor(driftStickChoice).replace("\n", " ")
            badgeSize: 10
            badgeOffset: 30

            primaryColor: driftStickColour

            minValue: 0
            maxValue: 1

            startAngleDegrees: 0
            endAngleDegrees: 360

            MouseArea {
                id: driftStickButton
                anchors.fill: parent
                onClicked: driftStickFan.open = true
            }
        }
    }

    // The ESP32's driveMode, shown by driveModeGauge and its fan
    Item {
        id: driveModeState
        property real currentValue: 0
    }

    // Drive mode, ESP Sport and auto start-stop are startup settings: the
    // ESP32 applies them the next time the car starts, not straight away.
    // Changing one shows a short note saying so, or that it failed.
    function showStartupToast(ok, message) {
        startupToast.text = ok ? message : "Couldn't reach the ESP32 - not changed"
        startupToast.failed = !ok
        startupToastTimer.restart()
    }

    Rectangle {
        id: startupToast
        property alias text: startupToastText.text
        property bool failed: false
        z: 900
        anchors.horizontalCenter: nutronLogo.horizontalCenter
        anchors.verticalCenter: nutronLogo.verticalCenter
        width: startupToastText.width + 28
        height: startupToastText.height + 16
        radius: height / 2
        color: "black"
        border.width: 2
        border.color: failed ? "#ce1845" : "#329BFD"
        opacity: startupToastTimer.running ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            id: startupToastText
            anchors.centerIn: parent
            font.pixelSize: 17
            font.weight: Font.Bold
            color: "#F8E63C"
        }
    }

    Timer {
        id: startupToastTimer
        interval: 3500
    }

    // The ESP32's driftInAllModes: whether Drift Stick works in every drive
    // mode (1) or only in Drift (0)
    Item {
        id: driftInState
        property real currentValue: 0
    }

    // Drift Stick as one choice: 0 off, 1 Drift mode only, 2 all modes
    readonly property int driftStickChoice: driftStickGauge.currentValue !== 1 ? 0
                                            : (driftInState.currentValue === 1 ? 2 : 1)

    // Sends only what changes. Turning it on goes first and the mode choice
    // follows once the ESP32 accepts, the same order as the old buttons.
    function setDriftStick(choice) {
        if (choice === 0) {
            if (driftStickGauge.currentValue !== 0)
                Controller.sendData("settings", "enableDriftMode", 0, driftStickGauge)
            return
        }
        var allModes = choice === 2 ? 1 : 0
        var setModes = function() {
            if (driftInState.currentValue !== allModes)
                Controller.sendData("settings", "driftInAllModes", allModes, driftInState)
        }
        if (driftStickGauge.currentValue !== 1) {
            Controller.sendData("settings", "enableDriftMode", 1, driftStickGauge, function(ok) {
                if (ok) setModes()
            })
        } else {
            setModes()
        }
    }
    // Right column, four rows: front and rear tire pressures, RDU clutch
    // temps and RDU torque, all shown at once.
    Item {
        id: sensorArea
        anchors.top: parent.top
        anchors.left: oilGauge.right
        anchors.leftMargin: 10
        anchors.bottom: parent.bottom
        width: 250

        SemiCircularGauge {
            id: frontLeftTireGauge
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 8

            width: size
            height: size
            size: 110
            thick: 12

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 23
            minValue: 0
            maxValue: 4

            decimal: 1
            measureType: "pressure"

            // Values are in bar; limits set in psi
            lowTreshold: 35 / 14.5038
            highTreshold: 50 / 14.5038
            showThresholdMarks: true

            startAngleDegrees: 70
            endAngleDegrees: 290
        }

        Text {
            id: frontText
            anchors.centerIn: frontLeftTireGauge
            anchors.horizontalCenterOffset: 70

            font.weight: Font.Bold
            font.pixelSize: 23
            horizontalAlignment: Text.AlignHCenter
            color: "#F8E63C"
            text: "Front"
        }

        SemiCircularGauge {
            id: frontRightTireGauge
            anchors.bottom: frontLeftTireGauge.bottom
            anchors.left: frontLeftTireGauge.right
            anchors.leftMargin: 30

            width: size
            height: size
            size: 110
            thick: 12

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 23
            minValue: 0
            maxValue: 4

            decimal: 1
            measureType: "pressure"

            // Values are in bar; limits set in psi
            lowTreshold: 35 / 14.5038
            highTreshold: 50 / 14.5038
            showThresholdMarks: true

            startAngleDegrees: 110
            endAngleDegrees: 250

            reverse: true
        }

        // Between the front and rear rows
        Text {
            id: tpmsText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: frontLeftTireGauge.bottom
            anchors.verticalCenterOffset: 4

            font.weight: Font.Bold
            font.pixelSize: 23
            horizontalAlignment: Text.AlignHCenter
            color: "#F8E63C"
            text: "TPMS"
        }

        SemiCircularGauge {
            id: rearLeftTireGauge
            anchors.left: frontLeftTireGauge.left
            anchors.top: frontLeftTireGauge.bottom
            anchors.topMargin: 8

            width: size
            height: size
            size: 110
            thick: 12

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 23
            minValue: 0
            maxValue: 4

            decimal: 1
            measureType: "pressure"

            // Values are in bar; limits set in psi
            lowTreshold: 35 / 14.5038
            highTreshold: 50 / 14.5038
            showThresholdMarks: true

            startAngleDegrees: 70
            endAngleDegrees: 290
        }

        Text {
            id: rearText
            anchors.centerIn: rearRightTireGauge
            anchors.horizontalCenterOffset: -70
            font.weight: Font.Bold
            font.pixelSize: 23
            horizontalAlignment: Text.AlignHCenter
            color: "#F8E63C"
            text: "Rear"
        }

        SemiCircularGauge {
            id: rearRightTireGauge
            anchors.top: rearLeftTireGauge.top
            anchors.left: rearLeftTireGauge.right
            anchors.leftMargin: 30

            width: size
            height: size
            size: 110
            thick: 12

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 23
            minValue: 0
            maxValue: 4

            decimal: 1
            measureType: "pressure"

            // Values are in bar; limits set in psi
            lowTreshold: 35 / 14.5038
            highTreshold: 50 / 14.5038
            showThresholdMarks: true

            startAngleDegrees: 110
            endAngleDegrees: 250

            reverse: true
        }

        // RDU clutch temps: 0-120 C scale, red line at 105 C
        SemiCircularGauge {
            id: leftRDUTempGauge
            anchors.left: rearLeftTireGauge.left
            anchors.top: rearLeftTireGauge.bottom
            anchors.topMargin: 8

            width: size
            height: size
            size: 110
            thick: 12

            unitSymbol: "°"

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 21
            valueOffset: -4
            minValue: 0
            maxValue: 120

            decimal: 0
            measureType: "temperature"

            lowTreshold: 0
            highTreshold: 105

            startAngleDegrees: 70
            endAngleDegrees: 290
        }

        Text {
            id: rduTempText
            anchors.centerIn: leftRDUTempGauge
            anchors.horizontalCenterOffset: 70
            font.weight: Font.Bold
            font.pixelSize: 23
            horizontalAlignment: Text.AlignHCenter
            color: "#F8E63C"
            text: "Temps"
        }

        SemiCircularGauge {
            id: rightRDUTempGauge
            anchors.top: leftRDUTempGauge.top
            anchors.left: leftRDUTempGauge.right
            anchors.leftMargin: 30

            width: size
            height: size
            size: 110
            thick: 12

            unitSymbol: "°"

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 21
            valueOffset: 4
            minValue: 0
            maxValue: 120

            decimal: 0
            measureType: "temperature"

            lowTreshold: 0
            highTreshold: 105

            startAngleDegrees: 110
            endAngleDegrees: 250

            reverse: true
        }

        // Between the temps and torque rows
        Text {
            id: rduText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: leftRDUTempGauge.bottom
            anchors.verticalCenterOffset: 4

            font.weight: Font.Bold
            font.pixelSize: 23
            horizontalAlignment: Text.AlignHCenter
            color: "#F8E63C"
            text: "RDU"
        }

        // RDU torque. Also feeds the torque split gauge that replaces lambda
        // in OBD Not Alone mode.
        SemiCircularGauge {
            id: leftRDUTqGauge
            anchors.left: leftRDUTempGauge.left
            anchors.top: leftRDUTempGauge.bottom
            anchors.topMargin: 8

            width: size
            height: size
            size: 110
            thick: 12

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 21
            valueOffset: -4
            minValue: 0
            maxValue: 1600

            decimal: 0
            measureType: "torque"

            lowTreshold: 1
            highTreshold: 1600

            startAngleDegrees: 70
            endAngleDegrees: 290
        }

        Text {
            id: rduTorqueText
            anchors.centerIn: leftRDUTqGauge
            anchors.horizontalCenterOffset: 70
            font.weight: Font.Bold
            font.pixelSize: 23
            horizontalAlignment: Text.AlignHCenter
            color: "#F8E63C"
            text: "Torque"
        }

        SemiCircularGauge {
            id: rightRDUTqGauge
            anchors.top: leftRDUTqGauge.top
            anchors.left: leftRDUTqGauge.right
            anchors.leftMargin: 30

            width: size
            height: size
            size: 110
            thick: 12

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 21
            valueOffset: 4
            minValue: 0
            maxValue: 1600

            decimal: 0
            measureType: "torque"

            lowTreshold: 1
            highTreshold: 1600

            startAngleDegrees: 110
            endAngleDegrees: 250

            reverse: true
        }
    }

    // Polls live PID values (temps, pressures, etc.) at the configured
    // refresh rate. The OBD Alone / Not Alone mode is intentionally NOT
    // checked here - see notAloneTimer below.
    Timer {
        id: fetchDataTimer
        interval: refresh
        running: true
        repeat: true
        onTriggered: {
            Controller.fetchData("pids", pidsData);
        }
    }

    // The OBD mode rarely changes mid-drive (it's set on the settings page,
    // or from the RSapp phone app, which shares it through the ESP32).
    // Polling it on the same 250ms cadence as live sensor data just doubled
    // network traffic to the ESP32 for no benefit, so it gets its own, much
    // slower timer instead.
    Timer {
        id: notAloneTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            Controller.checkNotAlone();
            // The app may have opened before the Sync 3 joined the ESP32's
            // Wi-Fi, and the RSapp phone app can change these too
            Controller.fetchData("settings", settingsData);
        }
    }

    // The fans go last and above the Ready To Race popup, so each covers
    // the whole page while open. The drive mode button is mid-column, so its
    // fan opens straight right; Drift Stick is at the bottom, so its fan
    // opens up and to the right.
    RadialFan {
        id: driveModeFan
        anchors.fill: parent
        accentColour: driveModeColour
        z: 1000
        hub: driveModeGauge
        // driveMode values the ESP32 expects (4 isn't used)
        options: [
            { name: "Normal", value: 0, icon: "modeNormal" },
            { name: "Sport",  value: 1, icon: "modeSport" },
            { name: "Track",  value: 2, icon: "modeTrack" },
            { name: "Drift",  value: 3, icon: "modeDrift" },
            { name: "Custom", value: 5, icon: "modeCustom" }
        ]
        currentValue: driveModeState.currentValue
        title: "Startup drive mode"
        subtitle: "The mode the car starts in. Applies the next time the car starts; "
                  + "while driving, use the drive mode button by the gear lever."
        onPicked: {
            var mode = nameFor(value)
            Controller.sendData("settings", "driveMode", value, driveModeState, function(ok) {
                showStartupToast(ok, "Starts in " + mode + " mode from the next start")
            })
        }
    }

    RadialFan {
        id: driftStickFan
        anchors.fill: parent
        accentColour: driftStickColour
        z: 1000
        hub: driftStickGauge
        centerDegrees: -30
        options: [
            { name: "All\nModes", value: 2 },
            { name: "Drift\nOnly", value: 1 },
            { name: "Off",         value: 0 }
        ]
        currentValue: driftStickChoice
        title: "Drift Stick"
        subtitle: "Works right away."
        onPicked: setDriftStick(value)
    }

    Component.onCompleted: {
        console.log("Primary View Loaded. Fetching data due to Page Load...")
        Controller.fetchData("pids", pidsData);
        Controller.fetchData("settings", settingsData);
        Controller.checkNotAlone();
    }
}
