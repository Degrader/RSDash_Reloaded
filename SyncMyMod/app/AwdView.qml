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

// The AWD page, the second gauge page. On the left, the AWD system: PTU,
// RDU and rear clutch temps, each clutch's torque, how the torque is split
// between them, the total, and how much faster the rear wheels turn than
// the front (slip). On the right, the car from above with each tyre's
// pressure and wheel speed beside it. Tapping the logo goes back to the
// engine page.
Rectangle {
    id: awdViewRect
    width: 800
    height: 480
    color: "black"

    // Red lines for the tyres, in bar (35 and 50 psi)
    readonly property real tireLow: 35 / 14.5038
    readonly property real tireHigh: 50 / 14.5038
    // The most a clutch's torque bar shows, in Nm
    readonly property real clutchTorqueMax: 1000
    // Below this total torque (Nm) there's no real split to show
    readonly property real minSplitTotal: 10

    readonly property color accent: "#38d3ee"
    readonly property color alert: "#ce1845"

    property var pidsData: [
        { gaugeId: ptuGauge,          param: "ptu" },
        { gaugeId: rduGauge,          param: "rdu" },
        { gaugeId: leftClutchGauge,   param: "rdutl" },
        { gaugeId: rightClutchGauge,  param: "rdutr" },
        { gaugeId: leftTqBar,         param: "rdutql" },
        { gaugeId: rightTqBar,        param: "rdutqr" },

        { gaugeId: frontLeftTireGauge,  param: "flw" },
        { gaugeId: frontRightTireGauge, param: "frw" },
        { gaugeId: rearLeftTireGauge,   param: "rlw" },
        { gaugeId: rearRightTireGauge,  param: "rrw" },

        { gaugeId: wheelFL, param: "wheelFL" },
        { gaugeId: wheelFR, param: "wheelFR" },
        { gaugeId: wheelRL, param: "wheelRL" },
        { gaugeId: wheelRR, param: "wheelRR" },

        { gaugeId: speedState, param: "speed" },

        // Not shown here; the Ready To Race logo watches it
        { gaugeId: oilState, param: "engine" }
    ]

    Item { id: wheelFL;  property real currentValue: 0 }
    Item { id: wheelFR;  property real currentValue: 0 }
    Item { id: wheelRL;  property real currentValue: 0 }
    Item { id: wheelRR;  property real currentValue: 0 }
    Item { id: speedState; property real currentValue: 0 }
    Item { id: oilState; property real currentValue: 0 }

    readonly property real torqueTotal: leftTqBar.currentValue + rightTqBar.currentValue
    // The left clutch's share of the rear torque, in %
    readonly property real leftShare: torqueTotal >= minSplitTotal ? 100 * leftTqBar.currentValue / torqueTotal : 50
    // How much faster the rear wheels turn than the front, km/h
    readonly property real slip: (wheelRL.currentValue + wheelRR.currentValue - wheelFL.currentValue - wheelFR.currentValue) / 2

    function torqueText(value) {
        return Controller.formatValue("torque", value, 0) + " " + Controller.unitLabel("torque")
    }

    function speedText(value) {
        return Controller.formatValue("speed", value, 0) + " " + Controller.unitLabel("speed")
    }

    function tireAlert(bar) {
        return bar < tireLow || bar > tireHigh
    }

    PageChrome {
        id: chrome
        anchors.fill: parent
    }

    ReadyToRace {
        id: readyToRaceLogo
        oil: oilState.currentValue
        ptu: ptuGauge.currentValue
        rdu: rduGauge.currentValue
    }

    // Tapping it goes back to the engine page
    Image {
        id: nutronLogo
        x: 68
        y: 8
        height: 40
        fillMode: Image.PreserveAspectFit
        source: "res/mountuners.png"
        smooth: true
        mipmap: true

        MouseArea {
            id: logoButton
            anchors.fill: parent
            onClicked: loader.source = "PrimaryView.qml"
        }
    }

    // --- Left: the AWD system. Temps first, then the rear torque

    PlasmaGauge {
        id: ptuGauge
        x: 68
        y: 54
        height: size
        width: size
        size: 130
        thick: 15

        unitSymbol: "°"

        name: "PTU"
        nameSize: 15

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 30
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
        x: ptuGauge.x + 138
        y: ptuGauge.y
        height: size
        width: size
        size: 130
        thick: 15

        unitSymbol: "°"

        name: "RDU"
        nameSize: 15

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 30
        minValue: 0
        maxValue: 130

        decimal: 0
        measureType: "temperature"

        lowTreshold: 20
        highTreshold: 110

        startAngleDegrees: 145
        endAngleDegrees: 395
    }

    // The RDU's clutch temps: 0-120 C scale, red line at 105 C
    PlasmaGauge {
        id: leftClutchGauge
        x: ptuGauge.x
        y: ptuGauge.y + 130
        height: size
        width: size
        size: 130
        thick: 15

        unitSymbol: "°"

        name: "Left clutch"
        nameSize: 14

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 30
        minValue: 0
        maxValue: 120

        decimal: 0
        measureType: "temperature"

        lowTreshold: 0
        highTreshold: 105

        startAngleDegrees: 145
        endAngleDegrees: 395
    }

    PlasmaGauge {
        id: rightClutchGauge
        x: rduGauge.x
        y: leftClutchGauge.y
        height: size
        width: size
        size: 130
        thick: 15

        unitSymbol: "°"

        name: "Right clutch"
        nameSize: 14

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 30
        minValue: 0
        maxValue: 120

        decimal: 0
        measureType: "temperature"

        lowTreshold: 0
        highTreshold: 105

        startAngleDegrees: 145
        endAngleDegrees: 395
    }

    Column {
        id: torqueBars
        x: 68
        y: 318
        width: 268
        spacing: 0

        // Each clutch's torque; its bar fills at clutchTorqueMax
        BarGauge {
            id: leftTqBar
            width: parent.width
            labelWidth: 56
            valueWidth: 100
            name: "Left"
            minValue: 0
            maxValue: clutchTorqueMax
            valueText: torqueText(currentValue)
        }

        BarGauge {
            id: rightTqBar
            width: parent.width
            labelWidth: 56
            valueWidth: 100
            name: "Right"
            minValue: 0
            maxValue: clutchTorqueMax
            valueText: torqueText(currentValue)
        }

        // Left share / right share of the torque, filling from the middle
        // towards the side that's carrying more
        BarGauge {
            id: splitBar
            width: parent.width
            labelWidth: 56
            valueWidth: 100
            name: "Split"
            centered: true
            minValue: 0
            maxValue: 100
            currentValue: leftShare
            valueText: torqueTotal >= minSplitTotal ? Math.round(leftShare) + " / " + Math.round(100 - leftShare) : "- / -"
        }

        BarGauge {
            id: totalBar
            width: parent.width
            labelWidth: 56
            valueWidth: 100
            name: "Total"
            minValue: 0
            maxValue: clutchTorqueMax * 2
            currentValue: torqueTotal
            valueText: torqueText(torqueTotal)
        }

        // Rear wheels faster than the front: positive, to the right
        BarGauge {
            id: slipBar
            width: parent.width
            labelWidth: 56
            valueWidth: 100
            name: "Slip"
            centered: true
            minValue: -20
            maxValue: 20
            // Past 8 km/h the bar turns red
            alertAbove: 8
            currentValue: slip
            valueText: (slip > 0.5 ? "+" : "") + Controller.formatValue("speed", slip, 0) + " " + Controller.unitLabel("speed")
        }
    }

    // --- Right: the car, with each tyre's pressure ring and wheel speed

    CarTopView {
        id: carView
        width: 200
        x: 565 - width / 2
        y: 20
        accentColour: awdViewRect.accent
        alertColour: awdViewRect.alert

        tireFLColour: tireAlert(frontLeftTireGauge.currentValue) ? alert : accent
        tireFRColour: tireAlert(frontRightTireGauge.currentValue) ? alert : accent
        tireRLColour: tireAlert(rearLeftTireGauge.currentValue) ? alert : accent
        tireRRColour: tireAlert(rearRightTireGauge.currentValue) ? alert : accent
    }

    // The rings open towards their tyres
    SemiCircularGauge {
        id: frontLeftTireGauge
        x: carView.x + carView.centreX - carView.tireOffset - carView.tireWidth / 2 - 8 - width
        y: carView.y + carView.frontAxleY - height / 2
        width: size
        height: size
        size: 104
        thick: 11

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 24
        minValue: 0
        maxValue: 4

        decimal: 1
        measureType: "pressure"

        // Values are in bar; limits set in psi
        lowTreshold: tireLow
        highTreshold: tireHigh
        showThresholdMarks: true

        startAngleDegrees: 70
        endAngleDegrees: 290
    }

    SemiCircularGauge {
        id: frontRightTireGauge
        x: carView.x + carView.centreX + carView.tireOffset + carView.tireWidth / 2 + 8
        y: frontLeftTireGauge.y
        width: size
        height: size
        size: 104
        thick: 11

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 24
        minValue: 0
        maxValue: 4

        decimal: 1
        measureType: "pressure"

        lowTreshold: tireLow
        highTreshold: tireHigh
        showThresholdMarks: true

        startAngleDegrees: 110
        endAngleDegrees: 250

        reverse: true
    }

    SemiCircularGauge {
        id: rearLeftTireGauge
        x: frontLeftTireGauge.x
        y: carView.y + carView.rearAxleY - height / 2
        width: size
        height: size
        size: 104
        thick: 11

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 24
        minValue: 0
        maxValue: 4

        decimal: 1
        measureType: "pressure"

        lowTreshold: tireLow
        highTreshold: tireHigh
        showThresholdMarks: true

        startAngleDegrees: 70
        endAngleDegrees: 290
    }

    SemiCircularGauge {
        id: rearRightTireGauge
        x: frontRightTireGauge.x
        y: rearLeftTireGauge.y
        width: size
        height: size
        size: 104
        thick: 11

        primaryColor: "#0c32ff"
        secondaryColor: "#ce1845"

        valueSize: 24
        minValue: 0
        maxValue: 4

        decimal: 1
        measureType: "pressure"

        lowTreshold: tireLow
        highTreshold: tireHigh
        showThresholdMarks: true

        startAngleDegrees: 110
        endAngleDegrees: 250

        reverse: true
    }

    // Pressure unit under each reading, and the wheel's speed below the ring
    Repeater {
        model: [
            { gauge: frontLeftTireGauge,  wheel: wheelFL },
            { gauge: frontRightTireGauge, wheel: wheelFR },
            { gauge: rearLeftTireGauge,   wheel: wheelRL },
            { gauge: rearRightTireGauge,  wheel: wheelRR }
        ]

        Item {
            x: modelData.gauge.x
            y: modelData.gauge.y
            width: modelData.gauge.width
            height: modelData.gauge.height

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 + 10
                font.pixelSize: 13
                font.weight: Font.Bold
                color: "#F8E63C"
                text: Controller.unitLabel("pressure")
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: -6
                font.pixelSize: 17
                font.weight: Font.Bold
                color: "white"
                text: speedText(modelData.wheel.currentValue)
            }
        }
    }

    // The car's speed, under it
    Text {
        id: vehicleSpeedText
        anchors.horizontalCenter: carView.horizontalCenter
        y: carView.y + carView.height + 6
        font.pixelSize: 36
        font.weight: Font.Bold
        color: "white"
        text: speedText(speedState.currentValue)
    }

    // Polls live PID values at the configured refresh rate
    Timer {
        id: fetchDataTimer
        interval: refresh
        running: true
        repeat: true
        onTriggered: {
            Controller.fetchData("pids", pidsData);
        }
    }

    Component.onCompleted: {
        mainPageSource = "AwdView.qml"
        Controller.fetchData("pids", pidsData);
    }
}
