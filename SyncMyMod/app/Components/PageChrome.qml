import QtQuick 2.6

// The buttons down the left edge of the two gauge pages (the engine page and
// the AWD page): close the app (top), the Controls page (middle, like an app
// drawer, a big green icon) and settings (bottom). Fill the page
// with it.
Item {
    id: pageChrome

    // For the dev harness to tap
    readonly property alias closeButton: closeImage
    readonly property alias controlsButton: controlsTouch
    readonly property alias controlsIcon: controlsGlyph
    readonly property alias settingsButton: settingsImage

    Image {
        id: closeImage
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 5
        width: 34
        fillMode: Image.PreserveAspectFit
        source: "../res/close.png"
        mipmap: true

        MouseArea {
            anchors.fill: parent
            onClicked: {
                backMouseArea.enabled = true
                back();
            }
        }
    }

    // Opens the Controls page
    Item {
        id: controlsTouch
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        width: 60
        height: 60

        SvgIcon {
            id: controlsGlyph
            anchors.fill: parent
            anchors.margins: 2
            icon: "controlsGridRight"
            color: controlsColour
        }

        MouseArea {
            anchors.fill: parent
            onClicked: loader.source = "../ControlsView.qml"
        }
    }

    Image {
        id: settingsImage
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 5
        width: 34
        fillMode: Image.PreserveAspectFit
        source: "../res/settings.png"
        mipmap: true

        MouseArea {
            anchors.fill: parent
            onClicked: loader.source = "../SettingsView.qml"
        }
    }
}
