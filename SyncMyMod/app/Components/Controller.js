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
                var minPsi = NaN, maxPsi = NaN;
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("TemperatureUnit=") === 0) {
                        temperatureUnit = line.split("=")[1];
                    } else if (line.indexOf("PressureUnit=") === 0) {
                        pressureUnit = line.split("=")[1];
                    } else if (line.indexOf("TorqueUnit=") === 0) {
                        torqueUnit = line.split("=")[1];
                    } else if (line.indexOf("SpeedUnit=") === 0) {
                        speedUnit = line.split("=")[1];
                    } else if (line.indexOf("TirePressureMinPsi=") === 0) {
                        minPsi = parseFloat(line.split("=")[1]);
                    } else if (line.indexOf("TirePressureMaxPsi=") === 0) {
                        maxPsi = parseFloat(line.split("=")[1]);
                    }
                }
                // Both limits or neither: one on its own, or a pair that makes no sense, is ignored
                if (validTireLimits(minPsi, maxPsi)) {
                    tirePressureMin = minPsi;
                    tirePressureMax = maxPsi;
                }
            }
        }
    };
    xhr.open("GET", iniFilePath, true);
    xhr.send();
}

function fetchData(endpoint, data) {
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
                // Skip a value this firmware doesn't send
                if (jsonData[gaugeItem.param] === undefined) continue;
                gaugeItem.gaugeId.currentValue = jsonData[gaugeItem.param];
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

// onDone (optional): called with true/false for whether the POST succeeded,
// and the HTTP status (0 if the ESP32 didn't answer).
function sendData(endpoint, gauge, value, control, onDone) {
    var xhr = new XMLHttpRequest();
    xhr.open("POST", mainUrl + endpoint, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("accept", "application/json");

    var data = {};
    data[gauge] = value;

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 && control) {
                control.currentValue = value;
            }
            if (onDone) onDone(xhr.status === 200, xhr.status);
        }
    };
    xhr.send(JSON.stringify(data));
}


// Psi in one bar. The ESP32 sends bar, but limits are easier to read in psi.
var PSI_PER_BAR = 14.5038;

// A pressure limit given in psi, in bar
function psiToBar(psi) {
    return psi / PSI_PER_BAR;
}

// The tire pressure limits, in psi: the AWD page's tire rings and tires go
// red below the first and above the second. These are what they start at;
// the settings page changes them (tirePressureMin and tirePressureMax on the
// app) anywhere from FLOOR to CEILING.
var TIRE_LIMIT_MIN_DEFAULT = 35;
var TIRE_LIMIT_MAX_DEFAULT = 50;
var TIRE_LIMIT_FLOOR = 0;
var TIRE_LIMIT_CEILING = 100;

function validTireLimits(minPsi, maxPsi) {
    return isFinite(minPsi) && isFinite(maxPsi) && minPsi >= TIRE_LIMIT_FLOOR
           && maxPsi <= TIRE_LIMIT_CEILING && minPsi < maxPsi;
}

// One step of a limit on the settings page, in psi: 1 psi, or 0.1 bar when the
// page shows bar
function tireLimitStep() {
    return pressureUnit === "Bar" ? 0.1 * PSI_PER_BAR : 1;
}

// The tire limits [min, max], in psi, after moving one of them (the maximum
// if max is true) a step up (direction 1) or down (-1), in whole steps of the
// unit shown. A limit stops a step short of the other, and at the ends of its range.
function steppedTireLimits(max, direction) {
    var step = tireLimitStep();
    var moving = max ? tirePressureMax : tirePressureMin;
    var next = Math.round((Math.round(moving / step) + direction) * step * 100) / 100;
    var limit;
    if (max) {
        limit = Math.min(Math.max(next, tirePressureMin + step), TIRE_LIMIT_CEILING);
    } else {
        limit = Math.max(Math.min(next, tirePressureMax - step), TIRE_LIMIT_FLOOR);
    }
    // Never the wrong way, e.g. a limit already closer than a step to the other
    if ((limit - moving) * direction < 0) limit = moving;
    return max ? [tirePressureMin, limit] : [limit, tirePressureMax];
}

// A limit (psi) as text in the unit the settings page shows, e.g. "35 PSI" or "2.4 BAR"
function tireLimitText(psi) {
    return formatValue("pressure", psiToBar(psi), pressureUnit === "Bar" ? 1 : 0) + " " + unitLabel("pressure");
}

// How to turn a value from the ESP32 (degrees C, bar, Nm and km/h) into each
// unit: a number to multiply by, or a function
var CONVERSIONS = {
    pressure: { "Bar": 1, "PSI": PSI_PER_BAR },
    temperature: { "Celsius": 1, "Fahrenheit": function(value) { return (value * 9/5) + 32; } },
    torque: { "Nm": 1, "Lb-Ft": 0.7376 },
    speed: { "km/h": 1, "mph": 0.621371 }
};

// The gauge's reading as text, in the unit chosen on the settings page
function getValue() {
    return formatValue(measureType, currentValue, decimal);
}

// A value from the ESP32 as text in the unit chosen on the settings page.
// kind: "temperature", "pressure", "torque" or "speed" (anything else is
// shown as it is).
function formatValue(kind, value, decimals) {
    var unitMap = {
        pressure: pressureUnit,
        temperature: temperatureUnit,
        torque: torqueUnit,
        speed: speedUnit
    };

    var unit = unitMap[kind];

    if (!CONVERSIONS[kind] || !unit) return value.toFixed(decimals);

    var factor = CONVERSIONS[kind][unit];

    var text = (typeof factor === "function" ? factor(value) : value * factor).toFixed(decimals);

    // A small negative reading rounds to "-0" (e.g. -0.3 mph); show it as "0"
    return /^-0(\.0*)?$/.test(text) ? text.substring(1) : text;
}

// The unit's short label for formatValue's kind, e.g. "°C" or "mph"
function unitLabel(kind) {
    if (kind === "temperature") return temperatureUnit === "Fahrenheit" ? "°F" : "°C";
    if (kind === "pressure") return pressureUnit === "PSI" ? "PSI" : "BAR";
    if (kind === "torque") return torqueUnit === "Lb-Ft" ? "lb-ft" : "Nm";
    if (kind === "speed") return speedUnit === "mph" ? "mph" : "km/h";
    return "";
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

// Draws the coloured bar showing a gauge's value along its ring, from
// startDegrees to valueDegrees (canvas angles; anticlockwise as for arc()).
// The value end is cut flat, straight across the ring, so it shows exactly
// where the value sits. The start keeps a rounded end to match the grey
// track underneath. A value at the very start of the scale draws nothing.
function drawValueArc(ctx, centerX, centerY, ringRadius, thick, startDegrees, valueDegrees, anticlockwise, colour) {
    if (valueDegrees === startDegrees) return;
    var start = startDegrees * Math.PI / 180;

    ctx.strokeStyle = colour;
    ctx.lineWidth = thick;
    ctx.lineCap = "butt";
    ctx.beginPath();
    ctx.arc(centerX, centerY, ringRadius, start, valueDegrees * Math.PI / 180, anticlockwise);
    ctx.stroke();

    ctx.fillStyle = colour;
    ctx.beginPath();
    ctx.arc(centerX + ringRadius * Math.cos(start), centerY + ringRadius * Math.sin(start), thick / 2, 0, 2 * Math.PI);
    ctx.fill();
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
