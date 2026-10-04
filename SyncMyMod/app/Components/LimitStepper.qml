import QtQuick 2.6

// A value changed in steps: a minus button at the left end of the pill, a plus
// at the right, and between them a label and the value. Tapping a button emits
// stepped(-1) or stepped(1); holding it steps again, after a short wait and
// then quickly. It's up to the page to change what valueText shows.
Rectangle {
    id: stepper
    width: 260
    height: 46
    color: "#1e1e1e"
    radius: height / 2

    property string label
    property string valueText

    signal stepped(int direction)

    // The buttons, e.g. for the dev harness to tap
    readonly property alias minusButton: minusArea
    readonly property alias plusButton: plusArea

    Timer {
        id: repeatTimer
        property int direction: 1
        interval: 450
        repeat: true
        onTriggered: {
            interval = 90
            stepper.stepped(direction)
        }
    }

    function press(direction) {
        stepped(direction)
        repeatTimer.direction = direction
        repeatTimer.interval = 450
        repeatTimer.restart()
    }

    function release() {
        repeatTimer.stop()
    }

    Rectangle {
        anchors.left: parent.left
        width: parent.height
        height: parent.height
        radius: height / 2
        color: "#0c32ff"

        Rectangle {
            anchors.centerIn: parent
            width: 18
            height: 4
            radius: 2
            color: "white"
        }

        MouseArea {
            id: minusArea
            anchors.fill: parent
            onPressed: stepper.press(-1)
            onReleased: stepper.release()
            onCanceled: stepper.release()
        }
    }

    Rectangle {
        anchors.right: parent.right
        width: parent.height
        height: parent.height
        radius: height / 2
        color: "#0c32ff"

        Rectangle {
            anchors.centerIn: parent
            width: 18
            height: 4
            radius: 2
            color: "white"
        }

        Rectangle {
            anchors.centerIn: parent
            width: 4
            height: 18
            radius: 2
            color: "white"
        }

        MouseArea {
            id: plusArea
            anchors.fill: parent
            onPressed: stepper.press(1)
            onReleased: stepper.release()
            onCanceled: stepper.release()
        }
    }

    // The label and the value, side by side and centred between the buttons
    Item {
        anchors.centerIn: parent
        width: labelText.width + 8 + valueLabel.width
        height: valueLabel.height

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.baseline: valueLabel.baseline
            font.pixelSize: 14
            color: "#F8E63C"
            text: stepper.label
        }

        Text {
            id: valueLabel
            anchors.right: parent.right
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "white"
            text: stepper.valueText
        }
    }
}
