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

    property int cobbAvailable: lambdaGauge.cobb;

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
        { gaugeId: espGauge,           param: "esp" }
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

        property bool conditionOk: (oilGauge.currentValue >= oilGauge.lowTreshold
                                   && rduGauge.currentValue >= rduGauge.lowTreshold
                                   && ptuGauge.currentValue >= ptuGauge.lowTreshold) && !rtrDisplayed

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
            if (conditionOk) {
                fadeInAnim.start()
            }
        }
    }

    Image {
        id: nutronLogo
        height: 47
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectFit
        source: "res/nutron.png"
        anchors.verticalCenterOffset: 8
        anchors.horizontalCenterOffset: -135
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
        id: lambdaGauge
        anchors.margins: 30
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: size
        width: size
        size: 220
        thick: 24
        cobbThick: 12

        unitSymbol: cobb ? "" : "^"
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

        cobb: false

        MouseArea {
            id: cobbControllerMouseArea
            anchors.top: parent.top
            width: parent.width
            height: parent.height - 40
            onClicked: {
                console.log("Current COBB Presence Status: " +cobbAvailable)
                cobbAvailable ? cobbAvailable=0 : cobbAvailable=1
                console.log("Set COBB Presence Status to: " + cobbAvailable)
                Controller.sendData("settings", "cobbFriendly", cobbAvailable, null, true)
            }
        }
    }

    PlasmaGauge {
        id: oilGauge
        anchors.bottom: parent.bottom
        anchors.left: lambdaGauge.left
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

    ButtonGauge {
        id: lcGauge
        anchors.top: lambdaGauge.top
        anchors.left: lambdaGauge.right
        anchors.leftMargin: 10
        width: size
        height: size
        size: 110
        thick: 12

        name: "LC"
        nameSize: 23

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

    ButtonGauge {
        id: espGauge
        anchors.leftMargin: 30
        anchors.top: lcGauge.top
        anchors.left: lcGauge.right
        height: size
        width: size

        name: "ESP"
        statusText: "Sport"
        primaryColor: "#3bb539"
        nameSize: 22

        size: 110
        thick: 12

        minValue: 0
        maxValue: 1
        showStatus: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: espButton
            anchors.fill: parent
            onClicked: {
                var newValue = espGauge.currentValue ? 0 : 1
                console.log("Current value: " + espGauge.currentValue + " New Value: " +newValue)
                Controller.sendData("settings", "esp", newValue, espGauge, false)
            }
        }
    }

    Rectangle {
        id: extraTPMSArea
        anchors.top: lcGauge.bottom
        anchors.left: lcGauge.left
        anchors.bottom: oilGauge.bottom
        anchors.right: espGauge.right

        color: "transparent"
        visible: extraAreaView === "TPMS"

        SemiCircularGauge {
            id: frontLeftTireGauge
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 40

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

            lowTreshold: 1.9
            highTreshold: 3.0

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

            lowTreshold: 1.9
            highTreshold: 3.0

            startAngleDegrees: 110
            endAngleDegrees: 250

            reverse: true
        }

        Text {
            id: tpmsText
            anchors.centerIn: parent

            font.weight: Font.Bold
            font.pixelSize: 23
            horizontalAlignment: Text.AlignHCenter
            color: "#F8E63C"
            text: "TPMS"

            MouseArea {
                id: rduTpmsSwitcher2MouseArea
                anchors.fill: parent
                onClicked: {
                    extraTPMSArea.visible = false
                    extraRDUArea.visible = true
                }
            }
        }

        SemiCircularGauge {
            id: rearLeftTireGauge
            anchors.left: frontLeftTireGauge.left
            anchors.top: frontLeftTireGauge.bottom
            anchors.topMargin: 40

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

            lowTreshold: 1.9
            highTreshold: 3.0

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

            lowTreshold: 1.9
            highTreshold: 3.0

            startAngleDegrees: 110
            endAngleDegrees: 250

            reverse: true
        }
    }

    Rectangle {
        id: extraRDUArea
        anchors.top: lcGauge.bottom
        anchors.left: lcGauge.left
        anchors.bottom: oilGauge.bottom
        anchors.right: espGauge.right

        color: "transparent"
        visible: extraAreaView === "RDU"

        SemiCircularGauge {
            id: leftRDUTempGauge
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 40

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
            highTreshold: 120

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
            text: "Temp"
        }

        SemiCircularGauge {
            id: rightRDUTempGauge
            anchors.bottom: leftRDUTempGauge.bottom
            anchors.left: leftRDUTempGauge.right
            anchors.leftMargin: 30

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
            highTreshold: 120

            startAngleDegrees: 110
            endAngleDegrees: 250

            reverse: true
        }

        Text {
            id: rduText
            anchors.centerIn: parent

            font.weight: Font.Bold
            font.pixelSize: 23
            horizontalAlignment: Text.AlignHCenter
            color: "#F8E63C"
            text: "RDU"

            MouseArea {
                id: rduTpmsSwitcher1MouseArea
                anchors.fill: parent
                onClicked: {
                    extraTPMSArea.visible = true
                    extraRDUArea.visible = false
                }
            }
        }

        SemiCircularGauge {
            id: leftRDUTqGauge
            anchors.left: leftRDUTempGauge.left
            anchors.top: leftRDUTempGauge.bottom
            anchors.topMargin: 40

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
            id: rearRDUText
            anchors.centerIn: rightRDUTqGauge
            anchors.horizontalCenterOffset: -70
            font.weight: Font.Bold
            font.pixelSize: 21
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
    }

    // Polls live PID values (temps, pressures, etc.) at the configured
    // refresh rate. COBB presence is intentionally NOT checked here
    // anymore - see cobbTimer below.
    Timer {
        id: fetchDataTimer
        interval: refresh
        running: true
        repeat: true
        onTriggered: {
            Controller.fetchData("pids", pidsData, false);
        }
    }

    // COBB Access Port presence rarely changes mid-drive (it's set when
    // the user plugs/unplugs the device, or toggles it by tapping the
    // lambda gauge, which already updates it optimistically). Polling it
    // on the same 250ms cadence as live sensor data just doubled network
    // traffic to the ESP32 for no benefit, so it gets its own, much
    // slower timer instead.
    Timer {
        id: cobbTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            Controller.checkCOBB();
        }
    }

    Component.onCompleted: {
        console.log("Primary View Loaded. Fetching data due to Page Load...")
        Controller.fetchData("pids", pidsData, false);
        Controller.fetchData("settings", settingsData, false);
        Controller.checkCOBB();
    }
}
