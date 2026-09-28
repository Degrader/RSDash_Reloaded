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

    Component.onCompleted: {
        // Sets version itself once version.txt loads (it returns nothing)
        Controller.getVersion()
        // Refresh the OBD mode in case it was changed from the RSapp phone app
        Controller.checkNotAlone()
        Controller.fetchData("settings", driftSettingsData)
    }

    // Drift Stick itself is switched on the main page; this page only sets
    // which drive modes it works in, which can't change while it's off.
    property var driftSettingsData: [
        { gaugeId: driftStickState,     param: "enableDriftMode" },
        { gaugeId: driftInState,        param: "driftInAllModes" }
    ]

    Item {
        id: driftStickState
        property real currentValue: 0
    }

    Item {
        id: driftInState
        property real currentValue: 0
    }

    // Set while a new OBD mode is being sent to the ESP32, so a second
    // tap can't race the first.
    property bool obdRequestPending: false

    // The OBD mode lives on the ESP32 (shared with the RSapp phone app),
    // not in the ini, so it isn't part of saveSettings().
    function setNotAlone(value) {
        if (obdRequestPending) return
        obdRequestPending = true
        obdPendingTimeout.restart()
        Controller.sendData("settings", "cobbFriendly", value ? 1 : 0, null, function(ok) {
            obdRequestPending = false
            obdPendingTimeout.stop()
            if (ok) {
                notAlone = value
                // Confirm the ESP32 actually applied it
                Controller.checkNotAlone(true)
            }
        })
    }

    // Qt's XMLHttpRequest has no timeout of its own, so don't lock the
    // toggle forever if the ESP32 never answers.
    Timer {
        id: obdPendingTimeout
        interval: 5000
        onTriggered: obdRequestPending = false
    }


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
                loader.source = "PrimaryView.qml"
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
        anchors.verticalCenterOffset: 20
        spacing: 16

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

        // Alone: lambda on the gauge page. Not Alone: the ESP32 stops
        // requesting lambda from the PCM so another OBD device can use it,
        // and the gauge page shows the RDU clutch temps instead.
        CustomToggle {
            id: obdToggle
            label: "OBD"
            option1: "Alone"
            option2: "Not Alone"
            currentState: notAlone ? option2 : option1
            // Dimmed while the change is being sent to the ESP32
            opacity: obdRequestPending ? 0.5 : 1.0

            MouseArea {
                id: obdToggleMouseArea
                anchors.fill: parent
                propagateComposedEvents: true
                onClicked: {
                    mouse.accepted = false
                    setNotAlone(!notAlone)
                }
            }
        }

        // Which drive modes Drift Stick works in. Dimmed and locked while
        // Drift Stick is off.
        CustomToggle {
            id: driftInToggle
            label: "Drift Stick"
            option1: "All Modes"
            option2: "Drift Only"
            currentState: driftInState.currentValue === 1 ? option1 : option2
            opacity: driftStickState.currentValue === 1 ? 1.0 : 0.4

            MouseArea {
                id: driftInToggleMouseArea
                anchors.fill: parent
                enabled: driftStickState.currentValue === 1
                onClicked: {
                    var newValue = driftInState.currentValue === 1 ? 0 : 1
                    Controller.sendData("settings", "driftInAllModes", newValue, driftInState)
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
        temperatureUnit = temperatureToggle.currentState
        pressureUnit = pressureToggle.currentState
        torqueUnit = torqueToggle.currentState
        xhr.send(content);
    }
}
