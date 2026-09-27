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
        { gaugeId: lcGauge,             param: "enableLC" }
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
        id: nutronLogo
        // Heads the right column; LC has the spot between the big gauges.
        height: 50
        anchors.top: parent.top
        anchors.topMargin: 40
        anchors.horizontalCenter: sensorArea.horizontalCenter
        fillMode: Image.PreserveAspectFit
        source: "res/nutron.png"
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

        MouseArea {
            anchors.fill: parent
            onClicked: {
                loader.source = "SecondaryView.qml"
                currentView = 2
            }
        }
    }

    PlasmaGauge {
        id: ptuGauge
        anchors.margins: 30
        anchors.top: parent.top
        anchors.left: parent.left
        height: size
        width: size
        size: 220
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
        anchors.left: ptuGauge.left
        width: size
        height: size
        size: 220
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
        anchors.margins: 30
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: size
        width: size
        size: 220
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
        anchors.bottom: parent.bottom
        anchors.left: oilGauge.left
        height: size
        width: size
        size: 220
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

        // OBD "Alone" - see clutchTempGauge for "Not Alone"
        visible: !notAlone
    }

    // In OBD "Not Alone" mode (settings page) the ESP32 stops requesting
    // lambda, the only value it asks the PCM for, so this slot shows both
    // RDU clutch temps instead - they come from the AWD module and keep
    // updating.
    SplitPlasmaGauge {
        id: clutchTempGauge
        anchors.fill: lambdaGauge
        visible: notAlone

        thick: 24

        caption: "OBD\nNOT ALONE"
        captionColor: "#329BFD"
        captionSize: 14

        name: "RDU Clutch"
        nameSize: 20

        unitSymbol: "°"

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 26
        decimal: 0
        measureType: "temperature"

        // Clutch temps: 0-120 C scale, red line at 105 C per clutch
        minValue: 0
        maxValue: 120

        lowTreshold: 0
        highTreshold: 105

        leftValue: leftRDUTempGauge.currentValue
        rightValue: rightRDUTempGauge.currentValue
    }

    // In the gap between the four big gauges, sized to clear their rings
    ButtonGauge {
        id: lcGauge
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -135
        anchors.verticalCenterOffset: 8
        width: size
        height: size
        size: 90
        thick: 11

        name: "LC"
        nameSize: 21

        primaryColor: "#3bb539"

        minValue: 0
        maxValue: 1
        showStatus: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: lcButton
            anchors.fill: parent
            onClicked: {
                var newValue = lcGauge.currentValue ? 0 : 1
                console.log("Current value: " + lcGauge.currentValue + " New Value: " +newValue)
                Controller.sendData("settings", "enableLC", newValue, lcGauge, false)
            }
        }
    }

    // Tire pressures and RDU torque under the logo, all shown at once (this
    // used to switch between TPMS and RDU with the Extra View setting).
    Item {
        id: sensorArea
        anchors.top: nutronLogo.bottom
        anchors.left: oilGauge.right
        anchors.leftMargin: 10
        anchors.bottom: parent.bottom
        width: 250

        SemiCircularGauge {
            id: frontLeftTireGauge
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 14

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
            anchors.verticalCenterOffset: 9

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
            anchors.topMargin: 18

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

        // Bottom row: RDU torque, or the RDU clutch temps - tap to switch
        SemiCircularGauge {
            id: leftRDUTqGauge
            anchors.left: rearLeftTireGauge.left
            anchors.top: rearLeftTireGauge.bottom
            anchors.topMargin: 18
            visible: !showRDUTemps

            width: size
            height: size
            size: 110
            thick: 12

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 23
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
            id: rduRowText
            anchors.centerIn: leftRDUTqGauge
            anchors.horizontalCenterOffset: 70
            font.weight: Font.Bold
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            color: "#F8E63C"
            text: showRDUTemps ? "RDU\nTemps" : "RDU\nTorque"
        }

        SemiCircularGauge {
            id: rightRDUTqGauge
            anchors.top: leftRDUTqGauge.top
            anchors.left: leftRDUTqGauge.right
            anchors.leftMargin: 30
            visible: !showRDUTemps

            width: size
            height: size
            size: 110
            thick: 12

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 23
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

        // RDU clutch temps: 0-120 C scale, red line at 105 C. These also
        // feed the split gauge that replaces lambda in OBD Not Alone
        // mode, so they get updated even while hidden.
        SemiCircularGauge {
            id: leftRDUTempGauge
            anchors.left: leftRDUTqGauge.left
            anchors.top: leftRDUTqGauge.top
            visible: showRDUTemps

            width: size
            height: size
            size: 110
            thick: 12

            unitSymbol: "°"

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 23
            minValue: 0
            maxValue: 120

            decimal: 0
            measureType: "temperature"

            lowTreshold: 0
            highTreshold: 105

            startAngleDegrees: 70
            endAngleDegrees: 290
        }

        SemiCircularGauge {
            id: rightRDUTempGauge
            anchors.left: rightRDUTqGauge.left
            anchors.top: rightRDUTqGauge.top
            visible: showRDUTemps

            width: size
            height: size
            size: 110
            thick: 12

            unitSymbol: "°"

            primaryColor: "#0c32ff"
            secondaryColor: "#ce1845"

            valueSize: 23
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

        MouseArea {
            id: rduRowToggle
            anchors.left: leftRDUTqGauge.left
            anchors.right: rightRDUTqGauge.right
            anchors.top: leftRDUTqGauge.top
            anchors.bottom: leftRDUTqGauge.bottom
            onClicked: showRDUTemps = !showRDUTemps
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
            Controller.fetchData("pids", pidsData, false);
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
        }
    }

    Component.onCompleted: {
        console.log("Primary View Loaded. Fetching data due to Page Load...")
        Controller.fetchData("pids", pidsData, false);
        Controller.fetchData("settings", settingsData, false);
        Controller.checkNotAlone();
    }
}
