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
    id: settingsViewRect
    width: 800
    height: 480
    color: "black"

    Component.onCompleted: version = Controller.getVersion()


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
                loader.source = "SecondaryView.qml"
            }
        }
    }

    Text {
        id: settingsTitle
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 40
        font.pixelSize: 40
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        text: "RSdash Settings"
        color: "#329BFD"
    }


    Column {
        anchors.centerIn: parent
        spacing: 20

        CustomToggle {
            id: temperatureToggle
            label: "Temperature"
            option1: "Celsius"
            option2: "Fahrenheit"
            currentState: temperatureUnit

            MouseArea {
                id: temperatureToggleMouseArea
                anchors.fill: parent
                propagateComposedEvents: true
                onClicked: {
                    mouse.accepted = false
                    temperatureToggle.currentState = (temperatureToggle.currentState === temperatureToggle.option1 ? temperatureToggle.option2 : temperatureToggle.option1);
                    saveSettings()
                }
            }
        }

        CustomToggle {
            id: pressureToggle
            label: "Pressure"
            option1: "Bar"
            option2: "PSI"
            currentState: pressureUnit

            MouseArea {
                id: pressureToggleMouseArea
                anchors.fill: parent
                propagateComposedEvents: true
                onClicked: {
                    mouse.accepted = false
                    pressureToggle.currentState = (pressureToggle.currentState === pressureToggle.option1 ? pressureToggle.option2 : pressureToggle.option1);
                    saveSettings()
                }
            }
        }

        CustomToggle {
            id: torqueToggle
            label: "Torque"
            option1: "Nm"
            option2: "Lb-Ft"
            currentState: torqueUnit

            MouseArea {
                id: torqueToggleMouseArea
                anchors.fill: parent
                propagateComposedEvents: true
                onClicked: {
                    mouse.accepted = false
                    torqueToggle.currentState = (torqueToggle.currentState === torqueToggle.option1 ? torqueToggle.option2 : torqueToggle.option1);
                    saveSettings()
                }
            }
        }

        CustomToggle {
            id: extraAreaViewToggle
            label: "Extra View"
            option1: "TPMS"
            option2: "RDU"
            currentState: extraAreaView

            MouseArea {
                id: additioanlViewToggleMouseArea
                anchors.fill: parent
                propagateComposedEvents: true
                onClicked: {
                    mouse.accepted = false
                    extraAreaViewToggle.currentState = (extraAreaViewToggle.currentState === extraAreaViewToggle.option1 ? extraAreaViewToggle.option2 : extraAreaViewToggle.option1);
                    saveSettings()
                }
            }
        }
    }

    Text {
        id: copyright
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 10
        anchors.rightMargin: 10
        font.pixelSize: 13
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignLeft
        text: "RSdash " + version + "JC developed by Au{R}oN - FMods.net\nTuned up by Jordan!"
        color: "#FFFFFF"
    }

    function saveSettings() {
        var xhr = new XMLHttpRequest();
        xhr.open("PUT", iniFilePath, true);
        var content = "[Settings]\n";
        content += "TemperatureUnit=" + temperatureToggle.currentState + "\n";
        content += "PressureUnit=" + pressureToggle.currentState + "\n";
        content += "TorqueUnit=" + torqueToggle.currentState + "\n";
        content += "ExtraAreaView=" + extraAreaViewToggle.currentState + "\n";
        temperatureUnit = temperatureToggle.currentState
        pressureUnit = pressureToggle.currentState
        torqueUnit = torqueToggle.currentState
        extraAreaView = extraAreaViewToggle.currentState
        xhr.send(content);
    }
}
