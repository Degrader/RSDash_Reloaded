import QtQuick 2.6

// The "Ready To Race" logo that pulses once, the first time PTU, RDU and oil
// are all warm. Give it the three temperatures; it centres itself on its
// parent. Whether it has been shown is rtrDisplayed on the app (Nutron.qml),
// so it shows once however many times a gauge page is opened.
Image {
    id: readyToRaceLogo
    anchors.centerIn: parent
    height: 400
    z: 999
    fillMode: Image.PreserveAspectFit
    source: "../res/rtr.png"
    smooth: true
    mipmap: true
    scale: 1.0
    opacity: 0.0

    property real oil: 0
    property real ptu: 0
    property real rdu: 0

    // Temperatures (degrees C) from which each counts as warm
    property real oilWarm: 65
    property real ptuWarm: 50
    property real rduWarm: 20

    // rtrDisplayed is checked in onConditionOkChanged rather than here:
    // fadeInAnim sets it while conditionOk is still changing, which made
    // this a binding loop.
    property bool conditionOk: oil >= oilWarm && rdu >= rduWarm && ptu >= ptuWarm

    Timer {
        id: mainTimer
        interval: 3000
        repeat: false
        onTriggered: {
            fadeOutAnim.start()
            scaleAnim.running = false
        }
    }

    SequentialAnimation {
        id: fadeInAnim
        running: false
        onStarted: {
            readyToRaceLogo.opacity = 0
            readyToRaceLogo.scale = 1.0
            scaleAnim.running = true
            rtrDisplayed = true
        }
        PropertyAnimation { target: readyToRaceLogo; property: "opacity"; from: 0; to: 1; duration: 500 }
        ScriptAction { script: mainTimer.start() }
    }

    PropertyAnimation {
        id: fadeOutAnim
        target: readyToRaceLogo
        property: "opacity"
        from: 1
        to: 0
        duration: 500
    }

    SequentialAnimation {
        id: scaleAnim
        loops: Animation.Infinite
        running: false
        PropertyAnimation { target: readyToRaceLogo; property: "scale"; to: 1.3; duration: 400; easing.type: Easing.InOutQuad }
        PropertyAnimation { target: readyToRaceLogo; property: "scale"; to: 0.8; duration: 400; easing.type: Easing.InOutQuad }
    }

    onConditionOkChanged: {
        if (conditionOk && !rtrDisplayed) {
            fadeInAnim.start()
        }
    }
}
