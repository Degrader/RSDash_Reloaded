import QtQuick 2.6

import "Controller.js" as Controller

// A tire pressure ring, an arc that opens towards its tire. The bar turns red
// outside the tire pressure limits from the settings page, 35 to 50 psi unless
// they've been changed (outOfRange), and marks show both limits. Set the arc
// with startAngleDegrees and endAngleDegrees, and reverse it for a tire on the
// right.
PlasmaGauge {
    size: 104
    thick: 11
    valueSize: 24
    // Bar, as the ESP32 sends it; the scale leaves room above the high limit
    minValue: 0
    maxValue: Math.max(4, highTreshold * 1.15)
    decimal: 1
    measureType: "pressure"
    // The limits are in psi on the app (tirePressureMin and tirePressureMax)
    lowTreshold: Controller.psiToBar(tirePressureMin)
    highTreshold: Controller.psiToBar(tirePressureMax)
    showThresholdMarks: true
}
