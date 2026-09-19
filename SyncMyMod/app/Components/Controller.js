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
var requestsInFlight = {};
var cobbCheckInFlight = false;

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
                    } else if (line.indexOf("ExtraAreaView=") === 0) {
                        extraAreaView = line.split("=")[1];
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
    if (requestsInFlight[endpoint]) {
        // Previous poll for this endpoint hasn't finished yet - skip this
        // tick instead of stacking another request behind it.
        return;
    }
    requestsInFlight[endpoint] = true;

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            requestsInFlight[endpoint] = false;

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

function checkCOBB() {
    if (cobbCheckInFlight) {
        return;
    }
    cobbCheckInFlight = true;

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            cobbCheckInFlight = false;

            if (xhr.status !== 200) {
                return;
            }

            try {
                var jsonData = JSON.parse(xhr.responseText);
                if (jsonData.hasOwnProperty("cobbFriendly")) {
                    lambdaGauge.cobb = (jsonData.cobbFriendly === 1);
                }
            } catch (e) {
                console.log("checkCOBB: failed to parse response: " + e);
            }
        }
    }
    xhr.open("GET", mainUrl + "settings");
    xhr.setRequestHeader("accept", "application/json");
    xhr.send();
}

function sendData(endpoint, gauge, value, control, dummy) {
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

function getValue() {
    if (measureType === "raw") return currentValue.toFixed(decimal);
    if (ignoreUnit) return currentValue.toFixed(decimal);

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

    if (!conversion[measureType] || !unit) return currentValue.toFixed(decimal);

    var factor = conversion[measureType][unit];

    return (typeof factor === "function" ? factor(currentValue) : currentValue * factor).toFixed(decimal);
}

function checkDummyGauges() {
    var sdm = dummySDMGauge.currentValue;
    var diam = dummyDriftInGauge.currentValue;
    var sdmGauges = [
        normalModeGauge,
        sportModeGauge,
        trackModeGauge,
        driftModeGauge,
        'dummy',
        lastModeGauge
    ];

    var diamGauges = [
        driftInDriftModeOnlyGauge,
        driftInAllModesGauge
    ];

    diamGauges.forEach(function(gauge) { gauge.currentValue = 0; });
    sdmGauges.forEach(function(gauge) { gauge.currentValue = 0; });

    if (sdm >= 0 && sdm < sdmGauges.length) {
        sdmGauges[sdm].currentValue = 1;
    }

    if (diam >= 0 && diam < diamGauges.length) {
        diamGauges[diam].currentValue = 1;
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
