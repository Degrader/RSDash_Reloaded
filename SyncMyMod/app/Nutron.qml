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

    property int currentView: 1
    property int refresh: 250
    //property bool settingsLoaded: false

    property string temperatureUnit
    property string pressureUnit
    property string torqueUnit
    property string extraAreaView

    property bool rtrDisplayed: false

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


