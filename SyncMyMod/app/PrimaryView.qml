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
        // Bottom left corner, below RDU's ring (the close button has the
        // top left)
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 5
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
        // Centred: the four big gauges, the gap, and the right column
        anchors.left: parent.left
        anchors.leftMargin: (parent.width - (2 * width + 8 + 10 + sensorArea.width)) / 2
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
    // Tapping it opens the Controls page.
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

        MouseArea {
            id: logoButton
            anchors.fill: parent
            onClicked: loader.source = "ControlsView.qml"
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
        }
    }

    Component.onCompleted: {
        console.log("Primary View Loaded. Fetching data due to Page Load...")
        Controller.fetchData("pids", pidsData);
        Controller.checkNotAlone();
    }
}
