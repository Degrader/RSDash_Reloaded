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

Rectangle {
    id: customToggle
    width: 230
    height: 46
    color: "#1e1e1e"
    radius: height / 2

    property string label
    property string option1
    property string option2
    property string currentState: option1

    Text {
        id: labelText
        text: label
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: currentState == option1 ? 50 : -50
        font.pixelSize: 14
        color: "#F8E63C"
    }

    Rectangle {
        id: slider
        width: parent.width / 2
        height: parent.height
        color: "#0c32ff"
        radius: height / 2
        x: currentState == option1 ? 0 : parent.width / 2
        Behavior on x {
            NumberAnimation { duration: 200 }
        }
    }

    Text {
        id: optionText
        text: currentState
        anchors.centerIn: slider
        font.bold: true
        font.pixelSize: 16
        color: "white"
    }
}
