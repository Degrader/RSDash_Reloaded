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
    id: secondaryViewRect
    width: 800
    height: 480
    color: "black"

    property var settingsData: [
        { gaugeId: driftGauge,       param: "enableDriftMode" },
        { gaugeId: autoStartStopGauge,  param: "disableStartStop" },
        { gaugeId: dummySDMGauge,       param: "driveMode" },
        { gaugeId: dummyDriftInGauge,   param: "driftInAllModes" }
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
        visible: false

        MouseArea {
            anchors.fill: parent
            onClicked: {
                backMouseArea.enabled = true
                back();
            }
        }
    }

    Image {
        id: settingsButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 5
        width: 34
        fillMode: Image.PreserveAspectFit
        source: "res/settings.png"
        mipmap: true

        MouseArea {
            anchors.fill: parent
            onClicked: {
                loader.source = "SettingsView.qml"
            }
        }
    }

    Image {
        id: nutronLogo2
        height: 70
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectFit
        source: "res/nutron.png"
        anchors.verticalCenterOffset: 150
        sourceSize.height: 274
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
                    nutronLogo2.scale = 1.1
                } else {
                    nutronLogo2.scale = 1.0
                }
                scaleUp = !scaleUp
            }
            property bool scaleUp: true
        }

        MouseArea {
            id: nutronClick2
            anchors.fill: parent
            onClicked: {
                loader.source = "PrimaryView.qml"
                currentView = 1
            }
        }
    }

    Text {
        id: driveModesText
        anchors.horizontalCenter: trackModeGauge.horizontalCenter
        anchors.bottom: trackModeGauge.top
        anchors.bottomMargin: 10
        font.weight: Font.Bold
        font.pixelSize: 30
        horizontalAlignment: Text.AlignHCenter
        color: "#329BFD"
        text: "DRIVE MODES"
    }

    ButtonGauge {
        id: trackModeGauge
        anchors.top: parent.top
        anchors.topMargin: 75
        anchors.horizontalCenter: parent.horizontalCenter
        height: size
        width: size

        name: "Track"
        primaryColor: "#3bb539"
        nameSize: 23

        size: 160
        thick: 18

        minValue: 0
        maxValue: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: trackModeButton
            anchors.fill: parent
            onClicked: {
                var driveMode = 2
                Controller.sendData("settings", "driveMode", driveMode, dummySDMGauge, true)
            }
        }
    }

    ButtonGauge {
        id: sportModeGauge
        anchors.verticalCenter: trackModeGauge.verticalCenter
        anchors.right: trackModeGauge.left
        height: size
        width: size

        name: "Sport"
        primaryColor: "#3bb539"
        nameSize: 23

        size: 160
        thick: 18

        minValue: 0
        maxValue: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: sportModeButton
            anchors.fill: parent
            onClicked: {
                var driveMode = 1
                Controller.sendData("settings", "driveMode", driveMode, dummySDMGauge, true)
            }
        }
    }

    ButtonGauge {
        id: normalModeGauge
        anchors.verticalCenter: trackModeGauge.verticalCenter
        anchors.right: sportModeGauge.left
        height: size
        width: size

        name: "Normal"
        primaryColor: "#3bb539"
        nameSize: 23

        size: 160
        thick: 18

        minValue: 0
        maxValue: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: normalModeButton
            anchors.fill: parent
            onClicked: {
                var driveMode = 0
                Controller.sendData("settings", "driveMode", driveMode, dummySDMGauge, true)
            }
        }
    }

    ButtonGauge {
        id: driftModeGauge
        anchors.verticalCenter: trackModeGauge.verticalCenter
        anchors.left: trackModeGauge.right
        height: size
        width: size

        name: "Drift"
        primaryColor: "#3bb539"
        nameSize: 23

        size: 160
        thick: 18

        minValue: 0
        maxValue: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: driftModeButton
            anchors.fill: parent
            onClicked: {
                var driveMode = 3
                Controller.sendData("settings", "driveMode", driveMode, dummySDMGauge, true)
            }
        }
    }

    ButtonGauge {
        id: lastModeGauge
        anchors.verticalCenter: trackModeGauge.verticalCenter
        anchors.left: driftModeGauge.right
        height: size
        width: size

        name: "Custom"
        primaryColor: "#3bb539"
        nameSize: 23

        size: 160
        thick: 18

        minValue: 0
        maxValue: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: lastModeButton
            anchors.fill: parent
            onClicked: {
                var driveMode = 5
                Controller.sendData("settings", "driveMode", driveMode, dummySDMGauge, true)
            }
        }
    }

    Text {
        id: driftInText
        anchors.horizontalCenter: driftInDriftModeOnlyGauge.horizontalCenter
        anchors.horizontalCenterOffset: -driftInDriftModeOnlyGauge.width / 2
        anchors.bottom: driftInDriftModeOnlyGauge.top
        anchors.bottomMargin: 10
        font.weight: Font.Bold
        font.pixelSize: 30
        horizontalAlignment: Text.AlignHCenter
        color: "#329BFD"
        text: "DRIFT IN"
    }

    ButtonGauge {
        id: driftInDriftModeOnlyGauge
        anchors.centerIn: nutronLogo2
        anchors.horizontalCenterOffset: -200
        height: size
        width: size

        name: "Drift"
        primaryColor: "#3bb539"
        nameSize: 23

        size: 120
        thick: 14

        minValue: 0
        maxValue: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: driftInDriftModeOnlyButton
            anchors.fill: parent
            onClicked: {
                var driftMode = 0
                Controller.sendData("settings", "driftInAllModes", driftMode, dummyDriftInGauge, true)
            }
        }
    }

    ButtonGauge {
        id: driftInAllModesGauge
        anchors.verticalCenter: driftInDriftModeOnlyGauge.verticalCenter
        anchors.right: driftInDriftModeOnlyGauge.left
        height: size
        width: size

        name: "All"
        primaryColor: "#3bb539"
        nameSize: 23

        size: 120
        thick: 14

        minValue: 0
        maxValue: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: driftInAllModesButton
            anchors.fill: parent
            onClicked: {
                var driftMode = 1
                Controller.sendData("settings", "driftInAllModes", driftMode, dummyDriftInGauge, true)
            }
        }
    }

    Text {
        id: othersText
        anchors.horizontalCenter: driftGauge.horizontalCenter
        anchors.horizontalCenterOffset: driftGauge.width / 2
        anchors.bottom: driftGauge.top
        anchors.bottomMargin: 10
        font.weight: Font.Bold
        font.pixelSize: 30
        horizontalAlignment: Text.AlignHCenter
        color: "#329BFD"
        text: "OTHERS"
    }

    ButtonGauge {
        id: driftGauge
        anchors.centerIn: nutronLogo2
        anchors.horizontalCenterOffset: 200
        height: size
        width: size

        name: "DRIFT\nFURY"
        primaryColor: "#3bb539"
        nameSize: 14

        size: 120
        thick: 14

        minValue: 0
        maxValue: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: driftButton
            anchors.fill: parent
            onClicked: {
                var newValue = driftGauge.currentValue ? 0 : 1
                Controller.sendData("settings", "enableDriftMode", newValue, driftGauge, false)
            }
        }
    }

    ButtonGauge {
        id: autoStartStopGauge
        anchors.verticalCenter: driftGauge.verticalCenter
        anchors.left: driftGauge.right
        height: size
        width: size

        name: "ASS"
        statusText: "OFF"
        primaryColor: "#3bb539"
        nameSize: 22

        size: 120
        thick: 14
        showStatus: 1

        minValue: 0
        maxValue: 1

        startAngleDegrees: 0
        endAngleDegrees: 360

        MouseArea {
            id: autoStartStopButton
            anchors.fill: parent
            onClicked: {
                var newValue = autoStartStopGauge.currentValue ? 0 : 1
                Controller.sendData("settings", "disableStartStop", newValue, autoStartStopGauge, false)
            }
        }
    }

    ButtonGauge {
        id: dummySDMGauge
        visible: false
        minValue: 0
        maxValue: 5
    }

    ButtonGauge {
        id: dummyDriftInGauge
        visible: false
        minValue: 0
        maxValue: 1
    }

    Component.onCompleted: {
        Controller.fetchData("settings", settingsData, true);
    }
}