/***************************************************************************
 *                                                                         *
 *   Copyright (C) 2024 by Fmods.net. All rights reserved.                 *
 *   Author: Au{R}oN                                                       *
 *   Developed in collaboration with Nutron - https://promoto.nutron.pl    *
 *   Any form of resale is prohibited.                                     *
 *                                                                         *
 ***************************************************************************/

import QtQuick 2.6

// One row of the controls help page: a picture of the control on the left
// (whatever is declared inside the row), its name and what it does on the
// right.
Item {
    id: helpRow

    property string label
    property string description
    property int iconSize: 58

    default property alias icon: iconSlot.data

    height: Math.max(iconSize, textColumn.height)

    Item {
        id: iconSlot
        width: helpRow.iconSize
        height: helpRow.iconSize
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    Column {
        id: textColumn
        anchors.left: iconSlot.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            id: labelText
            width: parent.width
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#F8E63C"
            text: helpRow.label
        }

        Text {
            id: descriptionText
            width: parent.width
            font.pixelSize: 14
            color: "#FFFFFF"
            wrapMode: Text.WordWrap
            text: helpRow.description
        }
    }
}
