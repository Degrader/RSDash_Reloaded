import QtQuick 2.6

// A temperature ring gauge, with a blue mark where "cold" ends and a red mark
// where "hot" starts. Give it a name, maxValue and the two limits (and a size
// and minValue if the usual ones don't fit).
PlasmaGauge {
    size: 136
    thick: 15
    nameSize: 15
    valueSize: 30
    minValue: 0
    measureType: "temperature"
}
