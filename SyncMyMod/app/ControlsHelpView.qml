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

// What each control on the main view does, opened from the settings page.
// Each row shows the control as it looks when lit.
Rectangle {
    id: controlsHelpViewRect
    width: 800
    height: 480
    color: "black"

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
            onClicked: {
                loader.source = "SettingsView.qml"
            }
        }
    }

    Text {
        id: helpTitle
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        font.pixelSize: 28
        font.weight: Font.Bold
        text: "Controls Help"
        color: "#329BFD"
    }

    Column {
        id: helpRows
        anchors.top: helpTitle.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20
        spacing: 2

        HelpRow {
            id: closeHelp
            width: parent.width
            iconSize: 54
            label: "Close"
            description: "Closes RSdash."

            Image {
                anchors.centerIn: parent
                width: 34
                fillMode: Image.PreserveAspectFit
                source: "res/close.png"
                mipmap: true
            }
        }

        HelpRow {
            id: settingsHelp
            width: parent.width
            iconSize: 54
            label: "Settings"
            description: "Opens the settings page: units, the OBD mode, and this help."

            Image {
                anchors.centerIn: parent
                width: 34
                fillMode: Image.PreserveAspectFit
                source: "res/settings.png"
                mipmap: true
            }
        }

        HelpRow {
            id: lcHelp
            width: parent.width
            iconSize: 54
            label: "LC - Launch Control"
            description: "Lit when Launch Control is enabled; tap to turn it on or off. With it on, launch from a stop "
                         + "with the clutch down and the throttle floored: the engine holds launch revs until you "
                         + "release the clutch."

            ButtonGauge {
                anchors.fill: parent
                size: 54
                thick: 7
                name: "LC"
                nameSize: 16
                primaryColor: "#0c32ff"
                currentValue: 1
                minValue: 0
                maxValue: 1
                startAngleDegrees: 0
                endAngleDegrees: 360
            }
        }

        HelpRow {
            id: espHelp
            width: parent.width
            iconSize: 54
            label: "ESP Sport"
            description: "Lit when the stability control (ESP) is in Sport mode, which allows more slip before it "
                         + "steps in. Tap to switch between Sport and normal."

            ButtonGauge {
                anchors.fill: parent
                size: 54
                thick: 7
                name: "ESP"
                nameSize: 13
                nameOffset: -3
                statusText: "Sport"
                statusOffset: 10
                showStatus: 1
                primaryColor: "#0c32ff"
                currentValue: 1
                minValue: 0
                maxValue: 1
                startAngleDegrees: 0
                endAngleDegrees: 360
            }
        }

        HelpRow {
            id: driveModeHelp
            width: parent.width
            iconSize: 54
            label: "Drive Mode"
            description: "Shows the drive mode. Tap it to fan out Normal, Sport, Track, Drift and Custom, then tap "
                         + "one to switch to it. Tap the button again, or anywhere else, to close without a change."

            ButtonGauge {
                anchors.fill: parent
                size: 54
                thick: 7
                topText: "Drive"
                topOffset: -11
                name: "Sport"
                nameSize: 11
                statusText: "Mode"
                statusOffset: 11
                showStatus: 1
                primaryColor: "#0c32ff"
                currentValue: 1
                minValue: 0
                maxValue: 1
                startAngleDegrees: 0
                endAngleDegrees: 360
            }
        }

        HelpRow {
            id: startStopHelp
            width: parent.width
            iconSize: 54
            label: "Auto Start-Stop"
            description: "Lit when auto start-stop is turned off, so the engine keeps running when you stop. "
                         + "Tap to turn auto start-stop off or back on."

            ButtonGauge {
                anchors.fill: parent
                size: 54
                thick: 7
                statusText: "OFF"
                statusOffset: 14
                showStatus: 1
                primaryColor: "#0c32ff"
                currentValue: 1
                minValue: 0
                maxValue: 1
                startAngleDegrees: 0
                endAngleDegrees: 360

                StartStopIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -3
                    width: 24
                    height: 24
                }
            }
        }

        HelpRow {
            id: driftStickHelp
            width: parent.width
            iconSize: 54
            label: "Drift Stick"
            description: "Lit while Drift Stick is on. Tap it to choose Off, Drift Only (works only in Drift mode) "
                         + "or All Modes (works in every drive mode). The button shows the current choice."

            ButtonGauge {
                anchors.fill: parent
                size: 54
                thick: 7
                name: "Drift\nStick"
                nameSize: 11
                primaryColor: "#0c32ff"
                currentValue: 1
                minValue: 0
                maxValue: 1
                startAngleDegrees: 0
                endAngleDegrees: 360
            }
        }
    }
}
