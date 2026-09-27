/***************************************************************************
 *                                                                         *
 *   Copyright (C) 2024 by Fmods.net. All rights reserved.                 *
 *   Author: Au{R}oN                                                       *
 *   Developed in collaboration with Nutron - https://promoto.nutron.pl    *
 *   Any form of resale is prohibited.                                     *
 *                                                                         *
 ***************************************************************************/

// Guards against firing a new request for an endpoint while a previous
// one is still in flight (the ESP32's HTTP server is not built for
// concurrent connections, so overlapping requests just build up latency).
// Qt's XMLHttpRequest has no timeout of its own, so a request that never
// completes (e.g. the ESP32 rebooting mid-response) is abandoned after
// REQUEST_TIMEOUT_MS instead of blocking that endpoint forever.
var REQUEST_TIMEOUT_MS = 3000;
var requestsInFlight = {};
var notAloneCheckInFlight = null;

// Returns true if a new request may start: nothing is pending, or the
// pending request has outlived REQUEST_TIMEOUT_MS (it is aborted here).
function canStartRequest(pending) {
    if (!pending) return true;
    if (Date.now() - pending.started < REQUEST_TIMEOUT_MS) return false;
    pending.xhr.abort();
    return true;
}

function loadSettings() {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                var lines = xhr.responseText.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("TemperatureUnit=") === 0) {
                        temperatureUnit = line.split("=")[1];
                    } else if (line.indexOf("PressureUnit=") === 0) {
                        pressureUnit = line.split("=")[1];
                    } else if (line.indexOf("TorqueUnit=") === 0) {
                        torqueUnit = line.split("=")[1];
                    }
                }
            } else {
            }
        }
    };
    xhr.open("GET", iniFilePath, true);
    xhr.send();
}

function fetchData(endpoint, data, dummy) {
    if (!canStartRequest(requestsInFlight[endpoint])) {
        // Previous poll for this endpoint hasn't finished yet - skip this
        // tick instead of stacking another request behind it.
        return;
    }

    var xhr = new XMLHttpRequest();
    var request = { xhr: xhr, started: Date.now() };
    requestsInFlight[endpoint] = request;

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            // Only free the slot if it's still ours - an abandoned request
            // finishing late must not free the slot of its replacement.
            if (requestsInFlight[endpoint] === request) {
                requestsInFlight[endpoint] = null;
            }

            if (xhr.status !== 200) {
                return;
            }

            var jsonData;
            try {
                jsonData = JSON.parse(xhr.responseText);
            } catch (e) {
                console.log("fetchData(" + endpoint + "): failed to parse response: " + e);
                return;
            }

            for (var i = 0; i < data.length; ++i) {
                var gaugeItem = data[i];
                gaugeItem.gaugeId.currentValue = jsonData[gaugeItem.param];
                if (dummy) checkDummyGauges();
            }
        }
    }
    xhr.open("GET", mainUrl + endpoint);
    xhr.setRequestHeader("accept", "application/json");
    xhr.send();
}

// Reads the OBD Alone / Not Alone mode (cobbFriendly) from the ESP32.
// force: replace any check already in flight - it may have been sent
// before a change was applied and would report the old state.
function checkNotAlone(force) {
    if (force && notAloneCheckInFlight) {
        notAloneCheckInFlight.xhr.abort();
    } else if (!canStartRequest(notAloneCheckInFlight)) {
        return;
    }

    var xhr = new XMLHttpRequest();
    var request = { xhr: xhr, started: Date.now() };
    notAloneCheckInFlight = request;

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (notAloneCheckInFlight === request) {
                notAloneCheckInFlight = null;
            }

            if (xhr.status !== 200) {
                return;
            }

            try {
                var jsonData = JSON.parse(xhr.responseText);
                if (jsonData.hasOwnProperty("cobbFriendly")) {
                    notAlone = (jsonData.cobbFriendly === 1);
                }
            } catch (e) {
                console.log("checkNotAlone: failed to parse response: " + e);
            }
        }
    }
    xhr.open("GET", mainUrl + "settings");
    xhr.setRequestHeader("accept", "application/json");
    xhr.send();
}

// onDone (optional): called with true/false for whether the POST succeeded.
function sendData(endpoint, gauge, value, control, dummy, onDone) {
    var xhr = new XMLHttpRequest();
    xhr.open("POST", mainUrl + endpoint, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("accept", "application/json");

    var data = {};
    data[gauge] = value;

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                if (control){
                    control.currentValue = value;
                    if (dummy) checkDummyGauges();
                }
            } else {
            }
            if (onDone) onDone(xhr.status === 200);
        }
    };
    xhr.send(JSON.stringify(data));
}


function getValueREADABLE() {
    if (measureType == "pressure") {
        if (pressureUnit === "Bar" && !ignoreUnit) {
            return currentValue.toFixed(1)
        } else if (pressureUnit === "PSI" && !ignoreUnit) {
            return (currentValue*14.5038).toFixed(1)
        } else {
            return currentValue.toFixed(1)
        }
    } else if (measureType == "temperature") {
        if (temperatureUnit === "Celsius" && !ignoreUnit) {
            return currentValue.toFixed(decimal)
        } else if (temperatureUnit === "Fahrenheit" && !ignoreUnit) {
            return ((currentValue * 9/5) + 32).toFixed(decimal)
        } else {
            return currentValue.toFixed(decimal)
        }
    } else if (measureType == "torque") {
        if (torqueUnit === "Nm" && !ignoreUnit) {
            return currentValue.toFixed(decimal)
        } else if (torqueUnit === "Lb-Ft" && !ignoreUnit) {
            return (currentValue * 0.7376).toFixed(decimal)
        } else {
            return currentValue.toFixed(decimal)
        }
    } else if (measureType == "raw") {
        return currentValue.toFixed(decimal)
    }
}

// value (optional): format this number instead of currentValue, for
// gauges that show more than one reading.
function getValue(value) {
    if (value === undefined) value = currentValue;
    if (measureType === "raw") return value.toFixed(decimal);
    if (ignoreUnit) return value.toFixed(decimal);

    var conversion = {
        pressure: { "Bar": 1, "PSI": 14.5038 },
        temperature: { "Celsius": 1, "Fahrenheit": function(value) { return (value * 9/5) + 32; } },
        torque: { "Nm": 1, "Lb-Ft": 0.7376 }
    };

    var unitMap = {
        pressure: pressureUnit,
        temperature: temperatureUnit,
        torque: torqueUnit
    };

    var unit = unitMap[measureType];

    if (!conversion[measureType] || !unit) return value.toFixed(decimal);

    var factor = conversion[measureType][unit];

    return (typeof factor === "function" ? factor(value) : value * factor).toFixed(decimal);
}

var COLD_MARK_COLOUR = "#329BFD";
var HOT_MARK_COLOUR = "#FF3B3B";

// Draws short lines across a gauge's ring where the value turns "cold"
// (lowTreshold, blue) and "hot" (highTreshold, red). angleFor(value) maps a
// value to its canvas angle in degrees. A threshold at or past either end of
// the scale is skipped, since it would only mark the end of the arc.
function drawThresholdMarks(ctx, centerX, centerY, ringRadius, thick, angleFor) {
    var marks = [[lowTreshold, COLD_MARK_COLOUR], [highTreshold, HOT_MARK_COLOUR]];
    for (var i = 0; i < marks.length; ++i) {
        var value = marks[i][0];
        if (value <= minValue || value >= maxValue) continue;

        var angle = angleFor(value) * Math.PI / 180;
        var inner = ringRadius - thick / 2 - 3;
        var outer = ringRadius + thick / 2 + 3;
        // Dark outline first, so the mark shows over an arc of any colour
        var strokes = [["#000000", 7], [marks[i][1], 4]];
        for (var j = 0; j < strokes.length; ++j) {
            ctx.strokeStyle = strokes[j][0];
            ctx.lineWidth = strokes[j][1];
            ctx.lineCap = "butt";
            ctx.beginPath();
            ctx.moveTo(centerX + inner * Math.cos(angle), centerY + inner * Math.sin(angle));
            ctx.lineTo(centerX + outer * Math.cos(angle), centerY + outer * Math.sin(angle));
            ctx.stroke();
        }
    }
}

// Lights the drive mode button matching the startup drive mode. (The Drift
// In toggle reads dummyDriftInGauge itself, so it isn't handled here.)
function checkDummyGauges() {
    var sdm = dummySDMGauge.currentValue;
    var sdmGauges = [
        normalModeGauge,
        sportModeGauge,
        trackModeGauge,
        driftModeGauge,
        'dummy',
        lastModeGauge
    ];

    sdmGauges.forEach(function(gauge) { gauge.currentValue = 0; });

    if (sdm >= 0 && sdm < sdmGauges.length) {
        sdmGauges[sdm].currentValue = 1;
    }
}

function getVersion() {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            version = xhr.responseText;
        }
    }
    xhr.open("GET", "../version.txt");
    xhr.setRequestHeader("accept", "application/json");
    xhr.send();
}
