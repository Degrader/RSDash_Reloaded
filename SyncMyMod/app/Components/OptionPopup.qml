import QtQuick 2.6

// A pop-up for picking one of a few options (e.g. the drive mode). Setting
// open = true dims the page and shows a panel with a heading, a line of
// explanation and a row of option buttons, the current one lit. Picking one
// emits picked(value) and closes; the close button, tapping outside the
// panel, or waiting closeAfterMs closes it without a change.
//
// Fill the page with it and declare it last so it sits above everything.
Item {
    id: popupRoot

    property bool open: false
    property string title
    property string subtitle
    property int currentValue: 0
    property color accentColour: "#0c32ff"
    property int closeAfterMs: 10000

    // [{ name, value, icon (optional, from Icons.js) }], left to right
    property var options: []

    signal picked(int value)

    function nameFor(value) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].value === value) return options[i].name;
        }
        return "?";
    }

    function iconFor(value) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].value === value) return options[i].icon ? options[i].icon : "";
        }
        return "";
    }

    // The option button at index i, e.g. for the dev harness to tap
    function optionButton(i) {
        return optionRepeater.itemAt(i);
    }

    readonly property alias panel: popupPanel
    readonly property alias closeButton: popupClose

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.8
    }

    // Swallows taps so nothing underneath reacts; a tap outside the panel
    // closes without a change
    MouseArea {
        anchors.fill: parent
        enabled: popupRoot.open
        onClicked: popupRoot.open = false
    }

    Rectangle {
        id: popupPanel
        anchors.centerIn: parent
        width: Math.max(optionRow.width, 420) + 48
        height: popupContent.height + 44
        radius: 18
        color: "#101010"
        border.width: 2
        border.color: popupRoot.accentColour

        // Taps on the panel itself don't close it
        MouseArea {
            anchors.fill: parent
            enabled: popupRoot.open
        }

        Image {
            id: popupClose
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            width: 30
            fillMode: Image.PreserveAspectFit
            source: "../res/close.png"
            mipmap: true

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                enabled: popupRoot.open
                onClicked: popupRoot.open = false
            }
        }

        Column {
            id: popupContent
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 48
            spacing: 6

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 26
                font.weight: Font.Bold
                color: "#329BFD"
                text: popupRoot.title
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 15
                color: "#FFFFFF"
                wrapMode: Text.WordWrap
                visible: text !== ""
                text: popupRoot.subtitle
            }

            Item { width: 1; height: 8 }

            Row {
                id: optionRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Repeater {
                    id: optionRepeater
                    model: popupRoot.options

                    ButtonGauge {
                        readonly property bool hasIcon: modelData.icon ? true : false
                        width: size
                        height: size
                        size: 96
                        thick: 10

                        icon: hasIcon ? modelData.icon : ""
                        iconSize: 42
                        iconOffset: -8
                        name: modelData.name
                        nameSize: hasIcon ? 13 : 16
                        nameOffset: hasIcon ? 24 : 0

                        primaryColor: popupRoot.accentColour
                        currentValue: popupRoot.currentValue === modelData.value ? 1 : 0
                        minValue: 0
                        maxValue: 1
                        startAngleDegrees: 0
                        endAngleDegrees: 360

                        MouseArea {
                            anchors.fill: parent
                            enabled: popupRoot.open
                            onClicked: {
                                popupRoot.open = false
                                popupRoot.picked(modelData.value)
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: popupRoot.closeAfterMs
        running: popupRoot.open
        onTriggered: popupRoot.open = false
    }
}
