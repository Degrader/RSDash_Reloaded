import QtQuick 2.6

// A horizontal bar with its name on the left and its reading on the right.
// Either fills from the left, or (centered) from the middle outwards for
// readings that go both ways, like steering or yaw. The bar turns red when
// the reading's size passes alertAbove.
Item {
    id: barGauge

    property string name
    property string valueText

    property real currentValue: 0
    property real minValue: 0
    property real maxValue: 100
    property bool centered: false
    property real alertAbove: 1e9

    property color barColour: "#0c32ff"
    property color alertColour: "#ce1845"

    // The reading's text, e.g. for the dev harness to check it fits
    readonly property alias valueLabel: barValue

    property int labelWidth: 84
    property int valueWidth: 96
    property int barHeight: 14
    // Size of the name and the reading
    property int textSize: 17

    height: 30

    // Where the bar starts and ends, as 0..1 along its length
    readonly property real fraction: Math.min(Math.max((currentValue - minValue) / (maxValue - minValue), 0), 1)

    onFractionChanged: if (visible) barCanvas.requestPaint()
    onVisibleChanged: if (visible) barCanvas.requestPaint()
    onWidthChanged: barCanvas.requestPaint()
    Component.onCompleted: barCanvas.requestPaint()

    Text {
        id: barName
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: barGauge.labelWidth
        font.pixelSize: barGauge.textSize
        font.weight: Font.Bold
        color: "#F8E63C"
        text: barGauge.name
    }

    Canvas {
        id: barCanvas
        anchors.left: barName.right
        anchors.right: barValue.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 4
        anchors.rightMargin: 6
        height: barGauge.height

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var h = barGauge.barHeight, y = (height - h) / 2;

            ctx.fillStyle = "#1e1e1e";
            ctx.beginPath();
            ctx.roundedRect(0, y, width, h, h / 2, h / 2);
            ctx.fill();

            var from = barGauge.centered ? width / 2 : 0;
            var to = barGauge.fraction * width;
            var left = Math.min(from, to), size = Math.abs(to - from);
            if (size > 0.5) {
                var r = Math.min(h / 2, size / 2);
                ctx.fillStyle = Math.abs(barGauge.currentValue) > barGauge.alertAbove ? barGauge.alertColour : barGauge.barColour;
                ctx.beginPath();
                ctx.roundedRect(left, y, size, h, r, r);
                ctx.fill();
            }

            if (barGauge.centered) {
                ctx.fillStyle = "#ffffff";
                ctx.fillRect(width / 2 - 1, y - 3, 2, h + 6);
            }
        }
    }

    Text {
        id: barValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: barGauge.valueWidth
        horizontalAlignment: Text.AlignRight
        font.pixelSize: barGauge.textSize + 2
        font.weight: Font.Bold
        color: "white"
        text: barGauge.valueText
    }
}
