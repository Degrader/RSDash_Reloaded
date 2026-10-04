/***************************************************************************
 *                                                                         *
 *   Copyright (C) 2024 by Fmods.net. All rights reserved.                 *
 *   Author: Au{R}oN                                                       *
 *   Developed in collaboration with Nutron - https://promoto.nutron.pl    *
 *   Any form of resale is prohibited.                                     *
 *                                                                         *
 ***************************************************************************/

import QtQuick.Window 2.1
import QtQuick 2.6

import "Components/Controller.js" as Controller

Rectangle {
    anchors.fill: parent

    property string version: ""

    property string mainUrl: "http://192.168.80.1/";
    property string iniFilePath: "file:///fs/rwdata/fmods/NutronConfig.ini"

    property int refresh: 250

    // The units to show, from NutronConfig.ini once it's read. These are what
    // a fresh install starts with, and what's used if the ini can't be read.
    property string temperatureUnit: "Fahrenheit"
    property string pressureUnit: "PSI"
    property string torqueUnit: "Lb-Ft"
    property string speedUnit: "mph"

    // The tire pressure, in psi, outside which the AWD page's tire rings and
    // tires go red. Set on the settings page and saved in NutronConfig.ini (the
    // ESP32 sends bar, but a limit is easier to think of in psi).
    property real tirePressureMin: Controller.TIRE_LIMIT_MIN_DEFAULT
    property real tirePressureMax: Controller.TIRE_LIMIT_MAX_DEFAULT

    // The gauge page the Controls and Settings pages go back to: the engine
    // page (PrimaryView.qml) or the AWD page (AwdView.qml). Each sets it as it opens.
    property string mainPageSource: "PrimaryView.qml"

    // OBD "Not Alone" mode: the ESP32 stops requesting lambda from the PCM
    // so another OBD device (COBB AP, scan tool) can use it. Stored on the
    // ESP32 as cobbFriendly, not in the ini; set on the settings page.
    property bool notAlone: false

    property bool rtrDisplayed: false

    // Ring colour of each main view button when it's lit (off is grey), so
    // each is easy to tell apart at a glance. Same brightness and saturation
    // as the theme blue; red and yellow are left out, as they mean "warning"
    // on the gauges and are the text colour. Also used by the fans and the
    // controls help page.
    readonly property color lcColour: "#FF7E0D"          // orange
    readonly property color espColour: "#0DC2FF"         // cyan
    readonly property color driveModeColour: "#0C32FF"   // theme blue
    readonly property color startStopColour: "#0DFF5E"   // green
    readonly property color driftStickColour: "#0DFFD7"  // aqua
    // The Controls button on the left edge of the gauge pages
    readonly property color controlsColour: "#0DFF5E"    // green

    Component.onCompleted: {
        backMouseArea.enabled = false
        Controller.loadSettings();
    }

    Rectangle {
        id: primaryView
        anchors.fill: parent
        color: "black"

        Loader {
            id: loader
            anchors.fill: parent
            source: "PrimaryView.qml"
        }
    }
}


