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

// The engine page, the first of the two gauge pages: boost, the gear and
// the G-force plot across the top; coolant, oil, intake air, PTU and RDU
// temps in a row; and small brake, steering and yaw bars with the date and
// time along the bottom.
// Tapping the logo opens the AWD page (AwdView.qml); the button on the left
// edge opens Controls.
Rectangle {
    id: primaryViewRect
    width: 800
    height: 480
    color: "black"

    property var pidsData: [
        { gaugeId: boostGauge,    param: "boost" },
        { gaugeId: gearState,     param: "gear" },

        { gaugeId: coolantGauge,  param: "coolant" },
        { gaugeId: oilGauge,      param: "engine" },
        { gaugeId: iatGauge,      param: "iat" },
        { gaugeId: ptuGauge,      param: "ptu" },
        { gaugeId: rduGauge,      param: "rdu" },

        { gaugeId: latGState,     param: "latG" },
        { gaugeId: longGState,    param: "longG" },
        { gaugeId: vertGState,    param: "vertG" },
        { gaugeId: yawBar,        param: "yaw" },
        { gaugeId: steeringBar,   param: "steering" },
        { gaugeId: brakeBar,      param: "brake" },
        { gaugeId: batteryState,  param: "battery" }
    ]

    Item { id: gearState;  property real currentValue: -1 }
    Item { id: latGState;  property real currentValue: 0 }
    Item { id: longGState; property real currentValue: 0 }
    Item { id: vertGState; property real currentValue: 0 }
    // Volts at the OBD port; -1 until the ESP32 has a reading
    Item { id: batteryState; property real currentValue: -1 }

    PageChrome {
        id: chrome
        anchors.fill: parent
    }

    ReadyToRace {
        id: readyToRaceLogo
        oil: oilGauge.currentValue
        ptu: ptuGauge.currentValue
        rdu: rduGauge.currentValue
    }

    // --- Top row: boost, gear and logo, G-force

    PlasmaGauge {
        id: boostGauge
        x: 70
        y: 4
        size: 210
        thick: 24

        name: "Boost " + Controller.unitLabel("pressure")
        nameSize: 22

        valueSize: 43
        // Bar (limits set in psi); 0 under vacuum
        minValue: 0
        maxValue: Controller.psiToBar(35)

        decimal: 1
        measureType: "pressure"

        lowTreshold: -1
        highTreshold: 2.2
    }

    // Between boost and the G-force plot
    Item {
        id: gearArea
        x: boostGauge.x + boostGauge.width
        width: gForceGauge.x - x
        y: 0
        height: 140

        Text {
            id: gearLabel
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            font.pixelSize: 20
            font.weight: Font.Bold
            color: "#F8E63C"
            text: "GEAR"
        }

        Text {
            id: gearText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: gearLabel.bottom
            anchors.topMargin: -6
            font.pixelSize: 100
            font.weight: Font.Bold
            color: "white"
            // 0 neutral, 1-6, 7 reverse; -1 when the car isn't saying
            text: gearState.currentValue < 0 ? "-" : (gearState.currentValue === 0 ? "N"
                  : (gearState.currentValue === 7 ? "R" : String(gearState.currentValue)))
        }
    }

    // Tapping it opens the AWD page
    Image {
        id: nutronLogo
        height: 56
        x: gearArea.x + gearArea.width / 2 - width / 2
        y: 150
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
            onClicked: loader.source = "AwdView.qml"
        }
    }

    GForceGauge {
        id: gForceGauge
        x: 514
        y: 6
        width: 188
        height: 188
        latG: latGState.currentValue
        longG: longGState.currentValue
    }

    Text {
        id: gForceName
        anchors.horizontalCenter: gForceGauge.horizontalCenter
        anchors.top: gForceGauge.bottom
        anchors.topMargin: 0
        font.pixelSize: 16
        font.weight: Font.Bold
        color: "#F8E63C"
        text: "G-Force"
    }

    Column {
        id: gReadouts
        x: 706
        y: 14
        width: 94
        spacing: 12

        Repeater {
            model: [
                { label: "Lateral",      source: latGState },
                { label: "Fore / aft",    source: longGState },
                { label: "Vertical",     source: vertGState }
            ]

            Column {
                width: gReadouts.width

                Text {
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: "#F8E63C"
                    text: modelData.label
                }

                Text {
                    font.pixelSize: 26
                    font.weight: Font.Bold
                    color: "white"
                    text: modelData.source.currentValue.toFixed(2) + " g"
                }
            }
        }
    }

    // --- Temps: engine (coolant, oil, intake air), then the AWD system (PTU, RDU)

    TempGauge {
        id: coolantGauge
        x: 70
        y: 222

        name: "Coolant"
        maxValue: 130

        lowTreshold: 60
        highTreshold: 110
    }

    TempGauge {
        id: oilGauge
        x: coolantGauge.x + 147
        y: coolantGauge.y

        name: "Oil"
        maxValue: 150

        lowTreshold: 65
        highTreshold: 110
    }

    TempGauge {
        id: iatGauge
        x: oilGauge.x + 147
        y: coolantGauge.y

        name: "Intake"
        // Can read below freezing; only a hot intake is a problem
        minValue: -20
        maxValue: 80

        lowTreshold: -100
        highTreshold: 60
    }

    TempGauge {
        id: ptuGauge
        x: iatGauge.x + 147
        y: coolantGauge.y

        name: "PTU"
        maxValue: 130

        lowTreshold: 50
        highTreshold: 110
    }

    TempGauge {
        id: rduGauge
        x: ptuGauge.x + 147
        y: coolantGauge.y

        name: "RDU"
        maxValue: 130

        lowTreshold: 20
        highTreshold: 110
    }

    // --- Bottom: what the driver is doing

    Column {
        id: driverBars
        x: 70
        y: 382
        width: 350
        spacing: 3

        // Pressure on the brake pedal, % of the sensor's range
        BarGauge {
            id: brakeBar
            width: parent.width
            height: 22
            textSize: 14
            barHeight: 10
            labelWidth: 70
            valueWidth: 76
            name: "Brake"
            minValue: 0
            maxValue: 100
            valueText: Math.round(currentValue) + " %"
        }

        // Degrees from straight ahead, positive to the right
        BarGauge {
            id: steeringBar
            width: parent.width
            height: 22
            textSize: 14
            barHeight: 10
            labelWidth: 70
            valueWidth: 76
            name: "Steering"
            centered: true
            minValue: -450
            maxValue: 450
            valueText: Math.round(Math.abs(currentValue)) + "° " + (currentValue < -0.5 ? "L" : (currentValue > 0.5 ? "R" : ""))
        }

        // How fast the car is rotating, degrees per second
        BarGauge {
            id: yawBar
            width: parent.width
            height: 22
            textSize: 14
            barHeight: 10
            labelWidth: 70
            valueWidth: 76
            name: "Yaw"
            centered: true
            minValue: -90
            maxValue: 90
            valueText: Math.round(currentValue) + " °/s"
        }
    }

    // --- Battery voltage, between the bars and the clock

    Item {
        id: batteryArea
        x: 430
        y: 372
        width: 120
        height: 90

        Text {
            id: batteryLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 6
            font.pixelSize: 15
            font.weight: Font.Bold
            color: "#F8E63C"
            text: "BATTERY"
        }

        // Red when the battery is flat (under 12 V with the engine off, and
        // lower than the alternator should ever leave it with it running) or
        // the charging is too high
        Text {
            id: batteryText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: batteryLabel.bottom
            anchors.topMargin: 2
            font.pixelSize: 32
            font.weight: Font.Bold
            color: batteryState.currentValue >= 0 && (batteryState.currentValue < 12 || batteryState.currentValue > 15)
                   ? "#ce1845" : "white"
            text: batteryState.currentValue < 0 ? "--" : batteryState.currentValue.toFixed(1) + " V"
        }
    }

    // --- The system's date and time, bottom right

    // The time shown; the harness sets it to check the formatting
    property date now: new Date()

    Timer {
        id: clockTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: now = new Date()
    }

    Item {
        id: clockArea
        x: 560
        y: 372
        width: 236
        height: 90

        // In the system's own format, so 12 or 24 hour as the Sync 3 is set
        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            font.pixelSize: 46
            font.weight: Font.Bold
            color: "white"
            text: Qt.formatTime(now, Qt.DefaultLocaleShortDate)
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: timeText.bottom
            anchors.topMargin: -2
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#F8E63C"
            text: Qt.formatDate(now, "dddd, MMM d")
        }
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
        console.log("Primary View Loaded. Fetching data due to Page Load...")
        mainPageSource = "PrimaryView.qml"
        Controller.fetchData("pids", pidsData);
    }
}
