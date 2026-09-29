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
            description: "Lit when automatic Launch Control is on; tap to turn it on or off. Keep it off if your "
                         + "engine tune already turns Launch Control on."

            ButtonGauge {
                anchors.fill: parent
                size: 54
                thick: 7
                icon: "launchControl"
                iconSize: 26
                primaryColor: lcColour
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
            label: "ESP Sport (at startup)"
            description: "Lit when the car starts with Sport traction control. Applies the next time the car starts; "
                         + "while driving, use the car's own button."

            ButtonGauge {
                anchors.fill: parent
                size: 54
                thick: 7
                icon: "espSport"
                iconSize: 26
                primaryColor: espColour
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
            label: "Drive Mode (at startup)"
            description: "The mode the car starts in. Tap it to fan out Normal, Sport, Track, Drift and Custom, "
                         + "then tap one; it applies the next time the car starts. While driving, use the car's button."

            ButtonGauge {
                anchors.fill: parent
                size: 54
                thick: 7
                icon: "modeSport"
                iconSize: 26
                primaryColor: driveModeColour
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
            label: "Auto Start-Stop Off (at startup)"
            description: "Lit when the car starts with auto start-stop turned off. Applies the next time the car "
                         + "starts. Keep it unlit if your engine tune already turns auto start-stop off."

            ButtonGauge {
                anchors.fill: parent
                size: 54
                thick: 7
                icon: "autoStartStopOff"
                iconSize: 26
                primaryColor: startStopColour
                currentValue: 1
                minValue: 0
                maxValue: 1
                startAngleDegrees: 0
                endAngleDegrees: 360
            }
        }

        HelpRow {
            id: driftStickHelp
            width: parent.width
            iconSize: 54
            label: "Drift Stick"
            description: "Rear wheel lock through the ABS (a handbrake for drifting). Tap to choose Off, Drift "
                         + "Only or All Modes; works right away. Needs the ABS module flashed with the right calibration."

            ButtonGauge {
                anchors.fill: parent
                size: 54
                thick: 7
                icon: "driftStick"
                iconSize: 26
                primaryColor: driftStickColour
                currentValue: 1
                minValue: 0
                maxValue: 1
                startAngleDegrees: 0
                endAngleDegrees: 360
            }
        }
    }
}
