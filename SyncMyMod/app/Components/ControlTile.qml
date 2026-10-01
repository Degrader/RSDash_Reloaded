import QtQuick 2.6

// One control on the Controls page: a round icon button, its ring lit in
// the control's colour while it's on, with its name and current setting
// underneath. The whole tile is the touch target.
Item {
    id: controlTile

    property string label
    property string status
    property string icon
    property color colour: "#0c32ff"
    property bool lit: false
    property int buttonSize: 88

    // The round button itself, e.g. for the dev harness to check its ring
    readonly property alias button: tileButton

    signal tapped()

    width: 180
    height: 136

    ButtonGauge {
        id: tileButton
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: size
        height: size
        size: controlTile.buttonSize
        thick: 11

        icon: controlTile.icon
        iconSize: Math.round(controlTile.buttonSize * 0.48)

        primaryColor: controlTile.colour
        currentValue: controlTile.lit ? 1 : 0
        minValue: 0
        maxValue: 1
        startAngleDegrees: 0
        endAngleDegrees: 360
    }

    Text {
        id: tileLabel
        anchors.top: tileButton.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        font.pixelSize: 17
        font.weight: Font.Bold
        color: "#F8E63C"
        text: controlTile.label
    }

    Text {
        id: tileStatus
        anchors.top: tileLabel.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        font.pixelSize: 14
        color: "#FFFFFF"
        text: controlTile.status
    }

    MouseArea {
        anchors.fill: parent
        onClicked: controlTile.tapped()
    }
}
