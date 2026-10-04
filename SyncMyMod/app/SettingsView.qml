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
                loader.source = mainPageSource
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


    // --- The units, on the left

    Column {
        id: unitToggles
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -165
        spacing: 14

        CustomToggle {
            id: temperatureToggle
            label: "Temperature"
            option1: "Celsius"
            option2: "Fahrenheit"
            currentState: temperatureUnit
            onToggled: { temperatureUnit = value; saveSettings() }
        }

        CustomToggle {
            id: pressureToggle
            label: "Pressure"
            option1: "Bar"
            option2: "PSI"
            currentState: pressureUnit
            onToggled: { pressureUnit = value; saveSettings() }
        }

        CustomToggle {
            id: speedToggle
            label: "Speed"
            option1: "km/h"
            option2: "mph"
            currentState: speedUnit
            onToggled: { speedUnit = value; saveSettings() }
        }

        CustomToggle {
            id: torqueToggle
            label: "Torque"
            option1: "Nm"
            option2: "Lb-Ft"
            currentState: torqueUnit
            onToggled: { torqueUnit = value; saveSettings() }
        }

        // Not Alone: the ESP32 stops requesting lambda from the PCM so another
        // OBD device (COBB AP, scan tool) can use it. The gauge pages look the
        // same either way.
        CustomToggle {
            id: obdToggle
            label: "OBD"
            option1: "Alone"
            option2: "Not Alone"
            currentState: notAlone ? option2 : option1
            // Dimmed while the change is being sent to the ESP32
            opacity: obdRequestPending ? 0.5 : 1.0
            onToggled: setNotAlone(!notAlone)
        }
    }

    // --- The tire pressures the AWD page goes red outside of, on the right. Each
    // step is 1 psi (or 0.1 bar, when the units are bar); the page keeps them in psi.

    function setTireLimits(limits) {
        tirePressureMin = limits[0]
        tirePressureMax = limits[1]
        saveSettings()
    }

    Column {
        id: tireLimits
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 175
        width: 260
        spacing: 12

        Text {
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#329BFD"
            text: "TIRE PRESSURE LIMITS"
        }

        Text {
            width: parent.width
            font.pixelSize: 14
            color: "#FFFFFF"
            wrapMode: Text.WordWrap
            text: "The AWD page's tires turn red outside these. Change them for other tires, like drag radials."
        }

        LimitStepper {
            id: tireMinStepper
            label: "Min"
            valueText: Controller.tireLimitText(tirePressureMin)
            onStepped: setTireLimits(Controller.steppedTireLimits(false, direction))
        }

        LimitStepper {
            id: tireMaxStepper
            label: "Max"
            valueText: Controller.tireLimitText(tirePressureMax)
            onStepped: setTireLimits(Controller.steppedTireLimits(true, direction))
        }

        Rectangle {
            id: tireResetButton
            width: parent.width
            height: 38
            radius: height / 2
            color: "#1e1e1e"
            border.color: "#0c32ff"
            border.width: 2

            Text {
                anchors.centerIn: parent
                font.pixelSize: 16
                font.weight: Font.Bold
                color: "#F8E63C"
                text: "Reset to default"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: setTireLimits([Controller.TIRE_LIMIT_MIN_DEFAULT, Controller.TIRE_LIMIT_MAX_DEFAULT])
            }
        }
    }

    // Opens a page explaining each control on the main view
    Rectangle {
        id: controlsHelpButton
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.bottomMargin: 10
        width: 170
        height: 40
        radius: height / 2
        color: "#1e1e1e"
        border.color: "#0c32ff"
        border.width: 2

        Text {
            anchors.centerIn: parent
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#F8E63C"
            text: "Controls Help"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: loader.source = "ControlsHelpView.qml"
        }
    }

    // Credit for the ESP32 device and its firmware, above the app's own
    // credit line in the bottom right
    Text {
        id: nutronCredit
        anchors.right: copyright.right
        anchors.bottom: copyright.top
        anchors.bottomMargin: 8
        font.pixelSize: 13
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignRight
        text: "ESP32 device and firmware by Nutron Pro Moto"
        color: "#FFFFFF"
    }

    Image {
        id: nutronLogo
        anchors.right: copyright.right
        anchors.bottom: nutronCredit.top
        anchors.bottomMargin: 4
        height: 34
        fillMode: Image.PreserveAspectFit
        source: "res/nutron.png"
        smooth: true
        mipmap: true
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
        xhr.send("[Settings]\n"
                 + "TemperatureUnit=" + temperatureUnit + "\n"
                 + "PressureUnit=" + pressureUnit + "\n"
                 + "TorqueUnit=" + torqueUnit + "\n"
                 + "SpeedUnit=" + speedUnit + "\n"
                 + "TirePressureMinPsi=" + tirePressureMin + "\n"
                 + "TirePressureMaxPsi=" + tirePressureMax + "\n");
    }
}
