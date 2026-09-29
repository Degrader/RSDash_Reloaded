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

// What each control does, opened from the settings page: the main view's
// close button, settings button and logo, then each tile on the Controls
// page, shown as it looks when lit. Descriptions follow the RSdash manual.
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
        anchors.topMargin: 6
        font.pixelSize: 26
        font.weight: Font.Bold
        text: "Controls Help"
        color: "#329BFD"
    }

    Column {
        id: helpRows
        anchors.top: helpTitle.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20
        spacing: 2

        HelpRow {
            id: closeHelp
            width: parent.width
            iconSize: 44
            label: "Close"
            description: "Closes RSdash."

            Image {
                anchors.centerIn: parent
                width: 30
                fillMode: Image.PreserveAspectFit
                source: "res/close.png"
                mipmap: true
            }
        }

        HelpRow {
            id: settingsHelp
            width: parent.width
            iconSize: 44
            label: "Settings"
            description: "Opens the settings page: units, the OBD mode, and this help."

            Image {
                anchors.centerIn: parent
                width: 30
                fillMode: Image.PreserveAspectFit
                source: "res/settings.png"
                mipmap: true
            }
        }

        HelpRow {
            id: logoHelp
            width: parent.width
            iconSize: 44
            label: "Logo - Controls"
            description: "Tap the logo between the big gauges to open the Controls page, with the controls below."

            Image {
                anchors.centerIn: parent
                width: 44
                fillMode: Image.PreserveAspectFit
                source: "res/mountuners.png"
                mipmap: true
            }
        }

        HelpRow {
            id: lcHelp
            width: parent.width
            iconSize: 44
            label: "Launch Control"
            description: "Turns automatic Launch Control on or off, right away. Keep it off if your engine tune "
                         + "already turns Launch Control on."

            ButtonGauge {
                anchors.fill: parent
                size: 44
                thick: 6
                icon: "launchControl"
                iconSize: 22
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
            iconSize: 44
            label: "ESP Sport (at startup)"
            description: "Whether the car starts with Sport traction control. Applies the next time the car starts."

            ButtonGauge {
                anchors.fill: parent
                size: 44
                thick: 6
                icon: "espSport"
                iconSize: 22
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
            iconSize: 44
            label: "Drive Mode (at startup)"
            description: "The mode the car starts in: Normal, Sport, Track, Drift or Custom. Applies the next time "
                         + "the car starts; while driving, use the car's drive mode button."

            ButtonGauge {
                anchors.fill: parent
                size: 44
                thick: 6
                icon: "modeSport"
                iconSize: 22
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
            iconSize: 44
            label: "Auto Start-Stop (at startup)"
            description: "Whether the car starts with auto start-stop turned off. Leave it alone if your engine "
                         + "tune already turns auto start-stop off."

            ButtonGauge {
                anchors.fill: parent
                size: 44
                thick: 6
                icon: "autoStartStopOff"
                iconSize: 22
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
            iconSize: 44
            label: "Drift Stick"
            description: "Rear wheel lock through the ABS: Off, Drift Only or All Modes, right away. Needs the ABS "
                         + "module flashed with the right calibration."

            ButtonGauge {
                anchors.fill: parent
                size: 44
                thick: 6
                icon: "driftStick"
                iconSize: 22
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
