import QtQuick 2.6

// Stand-in for the Sync 3 Custom Apps Loader that hosts Nutron.qml.
// harness.py creates the app as a child of this, so the app can reach the
// two names it expects its host to provide.
Rectangle {
    width: 800
    height: 480
    color: "black"

    // The app enables this just before calling back() to close itself.
    MouseArea {
        id: backMouseArea
        enabled: false
    }

    function back() {
        console.log("HOST: back() called - the app asked to close")
    }
}
