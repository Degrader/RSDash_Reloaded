"""Runs RSdash on a PC against a fake ESP32 (mock_esp32.py).

    python dev/harness.py                  run every scenario; screenshots go to dev/out/
    python dev/harness.py obd              run only scenarios whose name contains "obd"
    python dev/harness.py --list           list the scenarios
    python dev/harness.py --interactive    open a clickable 800x480 window
                          [--not-alone] [--animate]
    python dev/harness.py --readme-shots   re-render the README screenshots (docs/screenshots/)

Scenarios drive the real UI (clicks land on the app's own MouseAreas), check
app state, and save screenshots. Any QML warning or error fails the run, as
does any failed check. Exit code is 0 only when everything passed.

This runs Qt 5.15, but the Sync 3 runs an older Qt (the app targets QtQuick
2.6), so a static check also fails on JavaScript newer than ES5 and on QML
imports newer than the ones the original app uses.

Needs PyQt5:  python -m pip install PyQt5
"""

import argparse
import os
import re
import shutil
import sys
import tempfile
import time
from pathlib import Path

# Read by Qt at startup, so set before QGuiApplication exists. The app reads
# and writes its settings ini through XMLHttpRequest on a file:// URL.
os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"
os.environ["QML_XHR_ALLOW_FILE_WRITE"] = "1"
# The software renderer can screenshot a window that isn't on screen.
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PyQt5 import sip
from PyQt5.QtCore import (QPoint, Qt, QTimer, QUrl, QtCriticalMsg, QtDebugMsg,
                          QtFatalMsg, QtInfoMsg, QtWarningMsg, qInstallMessageHandler)
from PyQt5.QtGui import QGuiApplication, QImage
from PyQt5.QtQml import QJSValue, QQmlComponent, QQmlExpression
from PyQt5.QtQuick import QQuickItem, QQuickView
from PyQt5.QtTest import QTest

from mock_esp32 import MockEsp32

DEV = Path(__file__).resolve().parent
APP = DEV.parent / "SyncMyMod" / "app"
OUT = DEV / "out"
README_SHOTS = DEV.parent / "docs" / "screenshots"

# Imports the original app uses, i.e. known to exist on the Sync 3.
IMPORT_BASELINE = {"QtQuick": (2, 6), "QtQuick.Controls": (1, 3), "QtQuick.Window": (2, 1)}

ES6_SYNTAX = [
    (r"=>", "arrow function"), (r"\blet\s", "let"), (r"\bconst\s", "const"),
    (r"`", "template literal"), (r"\bclass\s+\w", "class"), (r"\.\.\.[\w\[]", "spread"),
    (r"\?\.", "optional chaining"), (r"\?\?", "nullish coalescing"),
]

# Qt platform chatter that isn't about the app.
IGNORED_MESSAGES = ["propagateSizeHints"]


class HarnessError(Exception):
    pass


# ---------------------------------------------------------------- messages

class MessageLog:
    """Collects Qt/QML output. console.log from the app arrives as debug."""

    LEVELS = {QtDebugMsg: "debug", QtInfoMsg: "info", QtWarningMsg: "warning",
              QtCriticalMsg: "critical", QtFatalMsg: "fatal"}

    def __init__(self, verbose):
        self.verbose = verbose
        self.entries = []
        qInstallMessageHandler(self._handle)

    def _handle(self, mode, context, text):
        if any(noise in text for noise in IGNORED_MESSAGES):
            return
        level = self.LEVELS.get(mode, "?")
        self.entries.append((level, text))
        if self.verbose or level != "debug":
            print("    [qml %s] %s" % (level, text))

    def mark(self):
        return len(self.entries)

    def problems_since(self, mark):
        return [text for level, text in self.entries[mark:] if level in ("warning", "critical", "fatal")]


# ------------------------------------------------------------ static checks

def strip_comments_and_strings(source):
    source = re.sub(r'"(\\.|[^"\\\n])*"', '""', source)
    source = re.sub(r"'(\\.|[^'\\\n])*'", "''", source)
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def opaque_bounds(path):
    """(left, top, right, bottom) of an image's visible pixels, in image pixels."""
    image = QImage(str(path))
    xs, ys = [], []
    for y in range(image.height()):
        for x in range(image.width()):
            if image.pixel(x, y) >> 24 > 16:
                xs.append(x)
                ys.append(y)
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def static_checks():
    """Returns problems that would break on the Sync 3's older Qt."""
    problems = []
    for path in sorted(APP.rglob("*")):
        if path.suffix not in (".qml", ".js"):
            continue
        rel = path.relative_to(APP.parent)
        text = path.read_text(encoding="utf-8")
        code = strip_comments_and_strings(text)
        for pattern, name in ES6_SYNTAX:
            for match in re.finditer(pattern, code):
                line = code.count("\n", 0, match.start()) + 1
                problems.append("%s:%d: %s is ES6+, not supported by the Sync 3's JS engine" % (rel, line, name))
        for match in re.finditer(r"^\s*import\s+([\w.]+)\s+(\d+)\.(\d+)", text, flags=re.M):
            module, version = match.group(1), (int(match.group(2)), int(match.group(3)))
            line = text.count("\n", 0, match.start()) + 1
            if module not in IMPORT_BASELINE:
                problems.append("%s:%d: import %s isn't used by the original app - may not exist on the Sync 3" % (rel, line, module))
            elif version > IMPORT_BASELINE[module]:
                problems.append("%s:%d: import %s %d.%d is newer than the original app's %d.%d" % ((rel, line, module) + version + IMPORT_BASELINE[module]))
    return problems


# ------------------------------------------------------------------ harness

class Harness:
    def __init__(self, qt_app, log, interactive):
        self.qt_app = qt_app
        self.log = log
        self.mock = MockEsp32().start()
        self.view = QQuickView()
        self.view.setTitle("RSdash (dev harness)")
        self.view.setResizeMode(QQuickView.SizeViewToRootObject)
        self.view.setSource(QUrl.fromLocalFile(str(DEV / "Host.qml")))
        if self.view.status() != QQuickView.Ready:
            raise HarnessError("Host.qml failed: %s" % [e.toString() for e in self.view.errors()])
        self.engine = self.view.engine()
        self.host = self.view.rootObject()
        self.host_context = self.engine.contextForObject(self.host)
        self.app = None
        self.tmp = None
        self.ini_path = None
        self.failures = []
        if not interactive:
            # Qt's offscreen platform can't screenshot, so use a real window
            # parked off-screen: no taskbar entry, never takes focus.
            self.view.setFlags(Qt.Tool | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus)
            self.view.setPosition(-5000, -5000)
        self.view.show()

    # -- app lifecycle

    def start_app(self, ini=None, pids=None, settings=None, esp32_online=True, suppress_rtr=True):
        """Fresh app instance against a reset fake ESP32 and a temp copy of the ini.

        suppress_rtr: mark the Ready To Race popup as already shown, so it
        doesn't cover the screenshots (the default values are all warm).
        """
        self.stop_app()
        self.mock.reset(pids, settings)
        self.mock.online = esp32_online

        self.tmp = Path(tempfile.mkdtemp(prefix="rsdash-harness-"))
        self.ini_path = self.tmp / "NutronConfig.ini"
        ini_text = (APP / "NutronConfig.ini").read_text(encoding="utf-8")
        for key, value in (ini or {}).items():
            ini_text = re.sub(r"^%s=.*$" % key, "%s=%s" % (key, value), ini_text, flags=re.M)
        self.ini_path.write_text(ini_text, encoding="utf-8")

        component = QQmlComponent(self.engine, QUrl.fromLocalFile(str(APP / "Nutron.qml")))
        if component.isError():
            raise HarnessError("Nutron.qml failed to load:\n  " + "\n  ".join(e.toString() for e in component.errors()))
        # Created inside Host.qml's context so it can see backMouseArea and
        # back(); the URL and ini path are swapped before onCompleted runs.
        app = component.beginCreate(self.host_context)
        if not isinstance(app, QQuickItem):
            app = sip.cast(app, QQuickItem)
        app.setProperty("mainUrl", self.mock.url)
        app.setProperty("iniFilePath", QUrl.fromLocalFile(str(self.ini_path)).toString())
        if suppress_rtr:
            app.setProperty("rtrDisplayed", True)
        app.setParent(self.host)
        app.setParentItem(self.host)
        component.completeCreate()
        self.app = app
        self._component = component
        self.wait(700)  # first polls of /pids and /settings

    def stop_app(self):
        if self.app is not None:
            self.app.setParentItem(None)
            self.app.deleteLater()
            self.app = None
            self.wait(300)  # let in-flight requests land on nothing
        if self.tmp is not None:
            shutil.rmtree(self.tmp, ignore_errors=True)
            self.tmp = None

    # -- driving the app

    def wait(self, ms):
        QTest.qWait(ms)

    def eval(self, expr, on="page"):
        """Evaluates JS in the current page's context ("page"), or Nutron.qml's ("app")."""
        target = self.page() if on == "page" else self.app
        expression = QQmlExpression(self.engine.contextForObject(target), target, expr)
        result = expression.evaluate()
        if expression.hasError():
            raise HarnessError("eval %r: %s" % (expr, expression.error().toString()))
        value = result[0] if isinstance(result, tuple) else result
        return value.toVariant() if isinstance(value, QJSValue) else value  # e.g. JS arrays

    def page(self):
        item = self.eval("loader.item", on="app")
        if item is None:
            raise HarnessError("no page loaded")
        return item

    def current_page(self):
        return str(self.eval("String(loader.source)", on="app")).rsplit("/", 1)[-1]

    def wait_until(self, expr, timeout_ms=3000, on="page"):
        deadline = time.time() + timeout_ms / 1000
        while time.time() < deadline:
            if self.eval(expr, on):
                return True
            self.wait(50)
        return False

    def click(self, item_id):
        """Clicks the centre of a QML item on the current page, by its id."""
        x, y, visible = self.eval(
            "(function(){ var p = %s.mapToItem(null, %s.width / 2, %s.height / 2);"
            " return [p.x, p.y, %s.visible]; })()" % ((item_id,) * 4))
        if not visible:
            raise HarnessError("can't click %s: it isn't visible" % item_id)
        QTest.mouseClick(self.view, Qt.LeftButton, Qt.NoModifier, QPoint(int(x), int(y)))
        self.wait(150)

    def goto_page(self, name):
        if not self.wait_until("String(loader.source).indexOf(%r) >= 0" % name, 2000, on="app"):
            raise HarnessError("expected %s, still on %s" % (name, self.current_page()))
        self.wait(400)  # its first fetches

    def goto_controls(self):
        self.click("chrome.controlsButton")
        self.goto_page("ControlsView.qml")

    def goto_settings(self):
        self.click("chrome.settingsButton")
        self.goto_page("SettingsView.qml")

    def goto_gauges(self):
        self.click("backButton")
        self.goto_page("PrimaryView.qml")

    # -- results

    def check(self, ok, what):
        print("    %s %s" % ("ok  " if ok else "FAIL", what))
        if not ok:
            self.failures.append(what)

    def shot(self, name, folder=OUT):
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / (name + ".png")
        image = self.view.grabWindow()
        if image.isNull() or not image.save(str(path)):
            raise HarnessError("screenshot %s failed" % name)
        print("    shot %s" % path.relative_to(DEV.parent))

    def close(self):
        self.stop_app()
        self.mock.stop()


# ---------------------------------------------------------------- scenarios

SCENARIOS = []


def scenario(fn):
    SCENARIOS.append(fn)
    return fn


def boxes_clear(h, items):
    """True if the items' boxes are on the 800x480 screen, right of the left-edge buttons, and don't overlap."""
    return h.eval("(function(items) { var b = items.map(function(g) { var p = g.mapToItem(null, 0, 0);"
                  " return [p.x, p.y, p.x + g.width, p.y + g.height]; });"
                  " return b.every(function(r, i) { return r[0] >= 62 && r[1] >= 0 && r[2] <= 800 && r[3] <= 480"
                  " && b.every(function(o, j) { return i === j || r[2] <= o[0] || o[2] <= r[0] || r[3] <= o[1] || o[3] <= r[1]; }); }); })"
                  "([%s])" % ", ".join(items))


def check_chrome(h):
    """The close, Controls and settings buttons down the left edge of a gauge page."""
    h.check(h.eval("(function() { var c = chrome.closeButton, k = chrome.controlsButton, s = chrome.settingsButton;"
                   " var kp = k.mapToItem(null, 0, 0);"
                   " return c.x < 10 && c.y < 10 && s.x < 10 && s.y + s.height > 470"
                   " && kp.x < 10 && Math.abs(kp.y + k.height / 2 - 240) < 1 && kp.x + k.width <= 62"
                   " && kp.y > c.y + c.height && kp.y + k.height < s.y; })()"),
            "close at the top, Controls button centred on the far left, settings at the bottom, none overlapping")
    h.check(h.eval("chrome.controlsIcon.icon") == "controlsGridRight" and h.eval("chrome.controlsButton.width") >= 56,
            "the Controls button is the controls grid icon, no ring, at least 56 px")
    image = h.view.grabWindow()
    x, y = h.eval("(function(){ var p = chrome.controlsIcon.mapToItem(null, 0, 0); return [p.x, p.y, chrome.controlsIcon.width]; })()")[:2]
    size = h.eval("chrome.controlsIcon.width")
    green = sum(1 for dx in range(int(size)) for dy in range(int(size)) if image.pixelColor(int(x) + dx, int(y) + dy).name() == "#0dff5e")
    h.check(green > 400, "drawn in green (%d green pixels)" % green)


@scenario
def engine_page(h):
    """The engine page shows boost, gear, G-force, coolant/oil/intake/PTU/RDU temps, brake, steering and yaw."""
    h.start_app()
    h.check(h.current_page() == "PrimaryView.qml", "the app opens on the engine page")
    h.check(h.eval("[boostGauge, coolantGauge, oilGauge, iatGauge, ptuGauge, rduGauge].map(function(g) { return g.currentValue; })")
            == [0.9, 91, 92, 28, 62, 58], "boost and the five temps received from the ESP32")
    h.check(h.eval("gearText.text") == "3", "gear 3 shown")
    h.check(h.eval("[brakeBar, steeringBar, yawBar].map(function(b) { return b.currentValue; })") == [20, -40, 6],
            "brake, steering and yaw received")
    h.check(h.eval("[brakeBar, steeringBar, yawBar].map(function(b) { return b.valueText; })") == ["20 %", "40° L", "6 °/s"],
            "read as 20 %, 40° L, 6 °/s")
    h.check(h.eval("[gForceGauge.latG, gForceGauge.longG, vertGState.currentValue]") == [0.35, 0.2, 1.0],
            "lateral, longitudinal and vertical G received")
    h.check(h.eval("typeof speedGauge === 'undefined' && typeof lambdaGauge === 'undefined'"
                   " && typeof torqueSplitGauge === 'undefined' && typeof lcGauge === 'undefined'"),
            "no speed, lambda, torque split or control buttons on this page")
    check_chrome(h)
    h.check(boxes_clear(h, ["boostGauge", "gearArea", "gForceGauge", "gReadouts", "coolantGauge", "oilGauge", "iatGauge",
                            "ptuGauge", "rduGauge", "driverBars", "batteryArea", "clockArea"]),
            "every gauge is on the screen and none overlap")
    h.check(h.eval("batteryText.text") == "13.8 V" and h.eval("driverBars.x + driverBars.width <= batteryArea.x"
                   " && batteryArea.x + batteryArea.width <= clockArea.x"
                   " && Math.abs(batteryArea.y - clockArea.y) < 1 && batteryText.paintedWidth <= batteryArea.width"),
            "the battery voltage (13.8 V) sits between the bars and the clock")
    h.check(h.eval("String(batteryText.color)") == "#ffffff", "white when charging normally")
    h.check(h.eval("(function() { var row = [coolantGauge, oilGauge, iatGauge, ptuGauge, rduGauge];"
                   " return row.every(function(g, i) { return g.y === row[0].y && g.width === row[0].width"
                   " && (i === 0 || (g.x > row[i - 1].x + row[i - 1].width && g.x - row[i - 1].x === row[1].x - row[0].x)); })"
                   " && row[4].x + row[4].width <= 800 && row[0].y >= boostGauge.y + boostGauge.height; })()"),
            "the five temps in an evenly spaced row under the top row")
    h.check(h.eval("boostGauge.x + boostGauge.width <= gearArea.x && gearArea.x + gearArea.width <= gForceGauge.x"
                   " && Math.abs(gearText.x + gearText.width / 2 - gearArea.width / 2) < 1"
                   " && Math.abs(nutronLogo.x + nutronLogo.width / 2 - (gearArea.x + gearArea.width / 2)) < 1"
                   " && nutronLogo.x >= gearArea.x && nutronLogo.x + nutronLogo.width <= gearArea.x + gearArea.width"
                   " && nutronLogo.y >= gearArea.y + gearText.y + gearText.height - 20"),
            "gear and the logo centred between boost and the G-force plot, the logo under the gear")
    h.check(h.eval("nutronLogo.y + nutronLogo.height * 1.1 <= coolantGauge.y + 8 && gearText.height > 100"),
            "the logo clears the row below, even at the top of its pulse")
    h.check(h.eval("pulseTimer.running && pulseTimer.repeat && nutronLogo.scale !== 1"), "logo is pulsing")
    h.check(h.eval("[coolantGauge, oilGauge, iatGauge, ptuGauge, rduGauge].every(function(g) { return g.showThresholdMarks; })"
                   " && !boostGauge.showThresholdMarks"),
            "low/high marks on the temperature gauges, not boost")
    h.check(h.eval("[ptuGauge.lowTreshold, ptuGauge.highTreshold, rduGauge.lowTreshold, rduGauge.highTreshold]")
            == [50, 110, 20, 110], "PTU limits 50 and 110 C, RDU 20 and 110 C")
    h.check(h.eval("boostGauge.name") == "Boost BAR", "labelled Boost BAR")
    h.check(abs(h.eval("boostGauge.maxValue * 14.5038") - 35) < 1e-9, "boost scale tops out at 35 psi")
    # The bars are small, with the date and time to their right
    h.check(h.eval("driverBars.height < 80 && [brakeBar, steeringBar, yawBar].every(function(b) { return b.height <= 22; })"
                   " && driverBars.x + driverBars.width <= clockArea.x && clockArea.x + clockArea.width <= 800"
                   " && clockArea.y + clockArea.height <= 480 && clockArea.y >= coolantGauge.y + coolantGauge.height"),
            "brake, steering and yaw are small bars, with room to their right for the clock")
    h.eval("primaryViewRect.now = new Date(2026, 9, 1, 14, 5)")
    h.check(h.wait_until("/^(2:05|14:05)/.test(timeText.text)", 1000) and h.eval("dateText.text") == "Thursday, Oct 1",
            "the clock shows the system time and date (%s, %s)" % (h.eval("timeText.text"), h.eval("dateText.text")))
    h.check(h.eval("timeText.paintedWidth <= clockArea.width && dateText.paintedWidth <= clockArea.width"), "and they fit")
    h.eval("primaryViewRect.now = new Date()")
    h.shot("engine_page")


@scenario
def battery_voltage(h):
    """Battery voltage on the engine page: a dash before the first reading, red when low or too high."""
    h.start_app(pids={"battery": -1})
    h.check(h.eval("batteryText.text") == "--" and h.eval("String(batteryText.color)") == "#ffffff",
            "a dash, not red, before the ESP32 has a reading")
    for volts, text, colour in ((12.4, "12.4 V", "#ffffff"), (11.6, "11.6 V", "#ce1845"), (14.4, "14.4 V", "#ffffff"),
                                (15.4, "15.4 V", "#ce1845")):
        with h.mock.lock:
            h.mock.pids["battery"] = volts
        h.check(h.wait_until("batteryText.text === %r" % text, 2000) and h.eval("String(batteryText.color)") == colour,
                "%s reads %s, %s" % (volts, text, "red" if colour != "#ffffff" else "white"))


@scenario
def gear_display(h):
    """The gear reads N, 1-6 or R, and a dash while the car isn't saying."""
    h.start_app(pids={"gear": 0})
    for gear, expected in ((0, "N"), (1, "1"), (6, "6"), (7, "R"), (-1, "-")):
        with h.mock.lock:
            h.mock.pids["gear"] = gear
        h.check(h.wait_until("gearText.text === %r" % expected, 2000), "gear %d reads %s" % (gear, expected))


@scenario
def speed_units(h):
    """Wheel speeds follow the km/h / mph setting, and the other readings follow their own units."""
    h.start_app(ini={"SpeedUnit": "mph"}, pids={"wheelFL": 100, "speed": 100})
    h.check(h.eval("speedUnit", on="app") == "mph", "mph loaded from the ini")
    h.check(h.eval("Controller.formatValue('speed', 100, 0)") == "62", "100 km/h reads 62 mph")
    h.click("nutronLogo")
    h.goto_page("AwdView.qml")
    h.check(h.eval("speedText(wheelFL.currentValue)") == "62 mph", "the wheel speeds follow it")
    h.check(h.eval("Controller.unitLabel('speed')") == "mph", "labelled mph")
    h.check(h.eval("vehicleSpeedText.text") == "62 mph", "and so does the car's speed")
    h.start_app(ini={"TemperatureUnit": "Fahrenheit", "PressureUnit": "PSI", "TorqueUnit": "Lb-Ft"})
    h.check(h.eval("boostGauge.name") == "Boost PSI", "boost is labelled PSI in PSI")
    h.click("nutronLogo")
    h.goto_page("AwdView.qml")
    h.check(h.eval("[leftTqBar.valueText, rightTqBar.valueText, totalBar.valueText]") == ["89 lb-ft", "100 lb-ft", "188 lb-ft"],
            "clutch torque in lb-ft")
    h.check(h.eval("Controller.unitLabel('pressure')") == "PSI", "tyre pressure unit label follows the setting")


@scenario
def awd_page(h):
    """The logo opens the AWD page: AWD temps and torque on the left, the car with tyre pressures and wheel speeds on the right."""
    h.start_app(pids={"rdutl": 108, "rdutr": 98, "wheelFL": 80, "wheelFR": 80, "wheelRL": 90, "wheelRR": 92})
    h.click("nutronLogo")
    h.goto_page("AwdView.qml")
    check_chrome(h)
    h.check(h.eval("[ptuGauge, rduGauge, leftClutchGauge, rightClutchGauge].map(function(g) { return g.currentValue; })")
            == [62, 58, 108, 98], "PTU, RDU and the two clutch temps received")
    h.check(h.eval("[leftTqBar.currentValue, rightTqBar.currentValue]") == [120, 135], "clutch torque received")
    h.check(h.eval("[wheelFL, wheelFR, wheelRL, wheelRR].map(function(w) { return w.currentValue; })") == [80, 80, 90, 92],
            "wheel speeds received")
    h.check(h.eval("[frontLeftTireGauge, frontRightTireGauge, rearLeftTireGauge, rearRightTireGauge]"
                   ".map(function(g) { return g.currentValue; })") == [3.0, 3.0, 2.95, 2.95], "tyre pressures received")
    h.check(h.eval("[leftTqBar.valueText, rightTqBar.valueText, totalBar.valueText]") == ["120 Nm", "135 Nm", "255 Nm"],
            "left, right and total torque read in Nm")
    h.check(h.eval("splitBar.valueText") == "47 / 53" and abs(h.eval("splitBar.currentValue") - 100 * 120 / 255) < 1e-9,
            "the split reads 47 / 53 (left / right)")
    h.check(h.eval("slipBar.valueText") == "+11 km/h" and h.eval("slipBar.currentValue") == 11,
            "the rear wheels 11 km/h faster than the front read +11 km/h")
    h.check(h.eval("typeof carView.ptuColour === 'undefined' && typeof ptuText === 'undefined'"),
            "the PTU and RDU are gauges on the left now, not drawn on the car")

    h.check(boxes_clear(h, ["nutronLogo", "ptuGauge", "rduGauge", "leftClutchGauge", "rightClutchGauge", "torqueBars",
                            "carView", "frontLeftTireGauge", "frontRightTireGauge", "rearLeftTireGauge",
                            "rearRightTireGauge", "vehicleSpeedText"]),
            "logo, AWD gauges and bars, car, tyre rings and the speed are on the screen and don't overlap")
    h.check(h.eval("speedState.currentValue") == 87 and h.eval("vehicleSpeedText.text") == "87 km/h"
            and h.eval("typeof tireCaption === 'undefined'"), "the car's speed is shown as text under the car, with no caption")
    h.check(h.eval("Math.abs(vehicleSpeedText.x + vehicleSpeedText.width / 2 - (carView.x + carView.width / 2)) < 1"
                   " && vehicleSpeedText.y >= carView.y + carView.height"),
            "centred under the car")
    h.check(h.eval("rduGauge.x + rduGauge.width <= frontLeftTireGauge.x && torqueBars.x + torqueBars.width <= frontLeftTireGauge.x"
                   " && frontRightTireGauge.x + frontRightTireGauge.width <= 800"),
            "AWD data on the left of the page, tyres on the right")
    h.check(h.eval("(function() { var cx = carView.x + carView.centreX;"
                   " var half = carView.tireOffset + carView.tireWidth / 2;"
                   " return Math.abs((cx - half) - (frontLeftTireGauge.x + frontLeftTireGauge.width) - 8) < 1"
                   " && Math.abs(frontRightTireGauge.x - (cx + half) - 8) < 1"
                   " && rearLeftTireGauge.x === frontLeftTireGauge.x && rearRightTireGauge.x === frontRightTireGauge.x"
                   " && Math.abs(frontLeftTireGauge.y + frontLeftTireGauge.height / 2 - (carView.y + carView.frontAxleY)) < 1"
                   " && Math.abs(rearRightTireGauge.y + rearRightTireGauge.height / 2 - (carView.y + carView.rearAxleY)) < 1; })()"),
            "each tyre ring sits beside its tyre, at its axle")
    h.check(h.eval("frontLeftTireGauge.startAngleDegrees === 70 && rearLeftTireGauge.startAngleDegrees === 70"
                   " && frontRightTireGauge.reverse && rearRightTireGauge.reverse"),
            "rings open towards the tyres")
    h.check(h.eval("nutronLogo.y + nutronLogo.height <= ptuGauge.y && nutronLogo.x < carView.x"),
            "logo in the top left, above the AWD gauges")
    h.shot("awd_page")  # rendering also sets each gauge's colour
    h.check(h.eval("[leftClutchGauge, rightClutchGauge].map(function(g) { return String(g.colour); })") == ["#ce1845", "#0c32ff"],
            "the left clutch (108 C) is over its 105 C line and red; the right isn't")

    h.click("nutronLogo")
    h.goto_page("PrimaryView.qml")
    h.check(h.current_page() == "PrimaryView.qml", "the logo goes back to the engine page")


@scenario
def tire_pressure_limits(h):
    """Tyre pressures go red below 35 psi and above 50 psi, in the ring and on the car; 41-46 psi is normal."""
    # The ESP32 sends bar: 2.30 = 33.4 psi (low), 3.03 = 43.9 psi, 3.52 = 51.1 psi (high), 3.38 = 49.0 psi
    h.start_app(ini={"PressureUnit": "PSI"}, pids={"flw": 2.30, "frw": 3.03, "rlw": 3.52, "rrw": 3.38})
    h.click("nutronLogo")
    h.goto_page("AwdView.qml")
    limits = h.eval("[frontLeftTireGauge.lowTreshold * 14.5038, frontLeftTireGauge.highTreshold * 14.5038]")
    h.check(abs(limits[0] - 35) < 1e-9 and abs(limits[1] - 50) < 1e-9, "limits are 35 and 50 psi")
    h.shot("tire_pressure_limits")  # rendering also sets each gauge's colour
    colours = h.eval("[frontLeftTireGauge, frontRightTireGauge, rearLeftTireGauge, rearRightTireGauge]"
                     ".map(function(g) { return String(g.colour); })")
    red, blue = "#ce1845", "#0c32ff"
    h.check(colours == [red, blue, red, blue], "33.4 psi red, 43.9 blue, 51.1 red, 49.0 blue")
    h.check(h.eval("[carView.tireFLColour, carView.tireFRColour, carView.tireRLColour, carView.tireRRColour].map(String)")
            == [red, "#38d3ee", red, "#38d3ee"], "the tyres on the car are drawn red where the pressure is")


@scenario
def hot_awd_parts(h):
    """The PTU and RDU gauges go red past 110 C, on both pages."""
    h.start_app(pids={"ptu": 115, "rdu": 100})
    h.shot("hot_ptu_engine")
    h.check(h.eval("[ptuGauge, rduGauge].map(function(g) { return String(g.colour); })") == ["#ce1845", "#0c32ff"],
            "engine page: PTU red, RDU blue")
    h.click("nutronLogo")
    h.goto_page("AwdView.qml")
    h.shot("hot_ptu")
    h.check(h.eval("[ptuGauge, rduGauge].map(function(g) { return String(g.colour); })") == ["#ce1845", "#0c32ff"],
            "AWD page: PTU red, RDU blue")


@scenario
def torque_split(h):
    """The split reads left / right in %, all on one side reads 0 / 100, and under 10 Nm total there's no split."""
    h.start_app(pids={"rdutql": 0, "rdutqr": 400})
    h.click("nutronLogo")
    h.goto_page("AwdView.qml")
    h.check(h.wait_until("splitBar.valueText === '0 / 100'", 2000) and h.eval("splitBar.currentValue") == 0,
            "all on the right: 0 / 100, the bar full to the left edge")
    h.shot("torque_split_right")
    with h.mock.lock:
        h.mock.pids.update({"rdutql": 4, "rdutqr": 5})
    h.check(h.wait_until("splitBar.valueText === '- / -' && splitBar.currentValue === 50", 2000),
            "9 Nm total: no split, instead of 44 / 56")
    with h.mock.lock:
        h.mock.pids.update({"rdutql": 300, "rdutqr": 100})
    h.check(h.wait_until("splitBar.valueText === '75 / 25' && totalBar.valueText === '400 Nm'", 2000), "300 / 100 Nm reads 75 / 25")


@scenario
def pages_navigation(h):
    """The logo switches between the two gauge pages; Controls and settings go back to the page you left."""
    h.start_app()
    for page in ("PrimaryView.qml", "AwdView.qml"):
        if page == "AwdView.qml":
            h.click("nutronLogo")
            h.goto_page(page)
        h.check(h.eval("mainPageSource", on="app") == page, "%s is the page Controls will go back to" % page)
        h.click("chrome.controlsButton")
        h.goto_page("ControlsView.qml")
        h.click("backButton")
        h.goto_page(page)
        h.check(h.current_page() == page, "Controls' back arrow returns to %s" % page)
        h.click("chrome.settingsButton")
        h.goto_page("SettingsView.qml")
        h.click("backButton")
        h.goto_page(page)
        h.check(h.current_page() == page, "so does settings' back arrow")
    h.click("nutronLogo")
    h.goto_page("PrimaryView.qml")
    h.check(h.current_page() == "PrimaryView.qml", "and the logo goes back to the engine page")


@scenario
def value_cutoff(h):
    """A gauge's coloured bar is cut flat, straight across the ring, exactly at its value; no indicator circle."""
    h.start_app(pids={"engine": 80})  # not at 65 C, where the low mark is
    h.wait(300)
    # Points on PTU's ring, d px along the ring from angle `at` (positive is
    # towards higher values) and `across` px out from the ring's centre line
    probe = ("(function(at, d, across) { var g = oilGauge;"
             "  var a = at * Math.PI / 180, r = Math.min(g.width, g.height) / 2 - g.thick + across;"
             "  var p = g.mapToItem(null, g.width / 2 + r * Math.cos(a) - d * Math.sin(a),"
             "                            g.height / 2 + r * Math.sin(a) + d * Math.cos(a));"
             "  return [p.x, p.y]; })")
    value_angle = h.eval("oilGauge.startAngleDegrees + (oilGauge.currentValue - oilGauge.minValue)"
                         " / (oilGauge.maxValue - oilGauge.minValue)"
                         " * (oilGauge.endAngleDegrees - oilGauge.startAngleDegrees)")
    start_angle = h.eval("oilGauge.startAngleDegrees")

    def colour_at(at, d, across):
        x, y = h.eval("%s(%f, %f, %f)" % (probe, at, d, across))
        return image.pixelColor(int(round(x)), int(round(y))).name()

    image = h.view.grabWindow()
    blue, grey = h.eval("String(oilGauge.colour)"), "#1e1e1e"
    for across in (-4, 0, 4):
        before, after = colour_at(value_angle, -3, across), colour_at(value_angle, 3, across)
        h.check(before == blue and after == grey,
                "cut flat at the value, %+d px across the ring: %s just before, %s just after"
                % (across, before, after))
    cap = colour_at(start_angle, -6, 0)
    h.check(cap == blue, "the bar's start keeps its rounded end over the track's (got %s)" % cap)
    h.shot("value_cutoff")

    with h.mock.lock:
        h.mock.pids["engine"] = 0
    h.wait_until("oilGauge.currentValue === 0", 2000)
    h.wait(200)
    image = h.view.grabWindow()
    cap = colour_at(start_angle, -6, 0)
    h.check(cap == grey, "at the bottom of the scale there's no bar, not even its rounded start (got %s)" % cap)


@scenario
def gauge_tap_does_nothing(h):
    """Tapping a gauge sends nothing to the ESP32 and changes nothing."""
    h.start_app()
    for item in ("boostGauge", "oilGauge", "ptuGauge", "gForceGauge"):
        h.click(item)
    h.wait(300)
    h.check(not h.mock.posts and h.current_page() == "PrimaryView.qml", "tapping the engine page's gauges does nothing")
    h.click("nutronLogo")
    h.goto_page("AwdView.qml")
    for item in ("frontLeftTireGauge", "carView"):
        h.click(item)
    h.wait(300)
    h.check(not h.mock.posts and h.current_page() == "AwdView.qml", "nor does tapping the AWD page's gauges")


# Top row, changing the car now: the car's drive mode and ESP, Launch Control, Drift Stick.
# At startup: drive mode, ESP Sport, auto start-stop.
TILES = [("liveDriveModeTile", "Drive Mode", "modeTrack", "#0c32ff"),
         ("escTile", "ESP", "espSport", "#0dc2ff"),
         ("lcTile", "Launch Control", "launchControl", "#ff7e0d"),
         ("driftStickTile", "Drift Stick", "driftStick", "#0dffd7"),
         ("driveModeTile", "Drive Mode", "modeSport", "#0c32ff"),
         ("espTile", "ESP Sport", "espSport", "#0dc2ff"),
         ("startStopTile", "Auto Start-Stop", "autoStartStopOff", "#0dff5e")]


def ring_colour(h, image, item):
    """Screen colour in the middle of a ButtonGauge's ring, at its right-hand side."""
    x, y = h.eval("(function(){ var b = %s; var p = b.mapToItem(null, b.width - b.thick, b.height / 2);"
                  " return [p.x, p.y]; })()" % item)
    return image.pixelColor(int(round(x)), int(round(y))).name()


@scenario
def controls_page(h):
    """The logo opens Controls: a grid of tiles, each lit in its own colour, with icons, names and settings."""
    h.start_app(settings={"enableLC": 1, "esp": 1, "disableStartStop": 1, "enableDriftMode": 1,
                          "driftInAllModes": 1, "driveMode": 1}, pids={"mode": 2, "esc": 1})
    h.goto_controls()
    h.check(h.eval("controlsTitle.text") == "Controls", "tapping the logo opens the Controls page")
    h.check(h.wait_until("lcState.currentValue === 1 && driveModeState.currentValue === 1"
                         " && liveModeState.currentValue === 2 && liveEscState.currentValue === 1", 1500),
            "settings and the car's drive mode and ESP read from the ESP32 on opening")
    ids = ", ".join(t for t, _, _, _ in TILES)
    h.check(h.eval("[%s].map(function(t) { return [t.label, t.icon]; })" % ids) == [[l, i] for _, l, i, _ in TILES],
            "Drive Mode, ESP, Launch Control, Drift Stick; then Drive Mode, ESP Sport, Auto Start-Stop, with their icons")
    h.check(h.eval("[%s].map(function(t) { return t.status; })" % ids)
            == ["Track", "Sport", "On", "All Modes", "Sport", "On", "Off"],
            "each shows its current setting")
    h.check(h.eval("startupHeading.text") == "STARTUP", "the startup controls have their own heading")
    h.check(h.eval("typeof liveHeading") == "undefined", "the top row has no heading")
    h.check(h.eval("[%s].every(function(t) { var p = t.mapToItem(null, 0, 0);"
                   " return p.x >= 0 && p.x + t.width <= 800 && p.y >= controlsTitle.y + controlsTitle.height"
                   " && p.y + t.height <= controlsNote.y; })" % ids),
            "all tiles between the title and the note, on screen")
    h.check(h.eval("[liveDriveModeTile, escTile, lcTile, driftStickTile].every(function(t, i) { return t.parent === liveRow"
                   " && (i === 0 || t.x > [liveDriveModeTile, escTile, lcTile, driftStickTile][i - 1].x); })"
                   " && [driveModeTile, espTile, startStopTile].every(function(t) { return t.parent === startupRow; })"
                   " && controlsTitle.y < liveRow.y && liveRow.y + liveRow.height <= startupHeading.y"
                   " && startupHeading.y < startupRow.y"),
            "the top row runs Drive Mode, ESP, Launch Control, Drift Stick; the startup ones sit under Startup")
    h.check(h.eval("startupRow.width + startupRow.spacing + driveModeTile.width <= liveRow.width"),
            "room left in the startup row for another control")
    image = h.view.grabWindow()
    got = [ring_colour(h, image, t + ".button") for t, _, _, _ in TILES]
    h.check(got == [c for _, _, _, c in TILES], "lit rings in each control's colour (got %s)" % got)
    for tile, _, icon, _ in TILES:
        x, y, size = h.eval("(function(){ var b = %s.button; var p = b.mapToItem(null, b.width / 2 - b.iconSize / 2,"
                            " b.height / 2 - b.iconSize / 2); return [p.x, p.y, b.iconSize]; })()" % tile)
        yellow = sum(1 for dx in range(int(size)) for dy in range(int(size))
                     if image.pixelColor(int(x) + dx, int(y) + dy).name() == "#f8e63c")
        h.check(yellow >= 20, "%s icon is drawn (%d icon-coloured pixels)" % (icon, yellow))
    h.shot("controls_page")

    # On/off tiles: tap to flip, with a note saying what it does
    for tile, key, on_note, off_note in (
            ("lcTile", "enableLC", "Launch Control on", "Launch Control off"),
            ("espTile", "esp", "ESP Sport on from the next start", "ESP Sport off from the next start"),
            ("startStopTile", "disableStartStop", "Auto start-stop off from the next start",
             "Auto start-stop on from the next start")):
        h.click(tile)
        h.check(h.wait_until("!%s.lit && toast.visible" % tile, 1000) and h.mock.posts[-1:] == [{key: 0}]
                and h.eval("toast.text") == off_note, "tapping %s sent %s=0: %r" % (tile, key, off_note))
        h.click(tile)
        h.check(h.wait_until("%s.lit" % tile, 1000) and h.mock.posts[-1:] == [{key: 1}]
                and h.eval("toast.text") == on_note, "and tapping again sent %s=1: %r" % (key, on_note))
    image = h.view.grabWindow()
    h.shot("controls_toast")

    h.start_app(settings={"enableLC": 0, "esp": 0, "disableStartStop": 0, "enableDriftMode": 0})
    h.goto_controls()
    h.wait(300)
    image = h.view.grabWindow()
    got = [ring_colour(h, image, t + ".button") for t, _, _, _ in TILES]
    h.check(got == ["#0c32ff", "#1e1e1e", "#1e1e1e", "#1e1e1e", "#0c32ff", "#1e1e1e", "#1e1e1e"],
            "off: grey rings; the drive modes (always set) still blue (got %s)" % got)

    h.click("backButton")
    h.goto_page("PrimaryView.qml")
    h.check(h.current_page() == "PrimaryView.qml", "back arrow returns to the gauges")


def check_popup_layout(h, popup, count):
    """Checks an open OptionPopup: its option buttons sit in a row inside its panel, on screen."""
    buttons = "[%s]" % ", ".join("%s.optionButton(%d)" % (popup, i) for i in range(count))
    h.check(h.eval("(function(){ var panel = %s.panel.mapToItem(null, 0, 0), pw = %s.panel.width, ph = %s.panel.height;"
                   " return panel.x >= 0 && panel.y >= 0 && panel.x + pw <= 800 && panel.y + ph <= 480"
                   " && %s.every(function(b, i, all) { var p = b.mapToItem(null, 0, 0);"
                   "   return p.x >= panel.x && p.x + b.width <= panel.x + pw && p.y + b.height <= panel.y + ph"
                   "     && (i === 0 || p.x >= all[i - 1].mapToItem(null, 0, 0).x + all[i - 1].width); }); })()"
                   % (popup, popup, popup, buttons)),
            "all %d options in a row inside the pop-up, on screen" % count)


@scenario
def drive_mode_popup(h):
    """Drive Mode opens a pop-up of the five modes; picking one sends driveMode; closing changes nothing."""
    h.start_app(settings={"driveMode": 2})
    h.goto_controls()
    h.check(h.wait_until("driveModeTile.status === 'Track' && driveModeTile.icon === 'modeTrack'", 1500),
            "the tile shows the ESP32's mode (Track) and its icon")
    h.check(not h.eval("driveModePopup.visible"), "pop-up starts closed")

    h.click("driveModeTile")
    h.wait(300)
    h.check(h.eval("driveModePopup.visible && driveModePopup.opacity === 1"), "tapping the tile opens the pop-up")
    h.check(h.eval("driveModePopup.title") == "Startup drive mode"
            and "next time the car starts" in h.eval("driveModePopup.subtitle"),
            "headed Startup drive mode, saying when it applies")
    h.check(h.eval("[0, 1, 2, 3].map(function(i) { return driveModePopup.optionButton(i).name; })")
            == ["Normal", "Sport", "Track", "Drift"], "Normal, Sport, Track, Drift (no Custom)")
    h.check(h.eval("[0, 1, 2, 3].map(function(i) { return driveModePopup.optionButton(i).icon; })")
            == ["modeNormal", "modeSport", "modeTrack", "modeDrift"], "each mode has its icon")
    h.check(h.eval("[0, 1, 2, 3].map(function(i) { return driveModePopup.optionButton(i).currentValue; })")
            == [0, 0, 1, 0], "only Track is lit")
    check_popup_layout(h, "driveModePopup", 4)
    h.shot("drive_mode_popup")

    posts_before = len(h.mock.posts)
    h.click("driveModePopup.optionButton(1)")
    h.check(h.wait_until("!driveModePopup.visible && driveModeTile.status === 'Sport'", 1500),
            "picking Sport closes the pop-up and the tile shows Sport")
    h.check(h.mock.posts[posts_before:] == [{"driveMode": 1}], "sent driveMode=1 and nothing else")
    h.check(h.eval("toast.text") == "Starts in Sport mode from the next start", "and says it applies from the next start")

    # A Custom (5) saved earlier, e.g. from the RSapp phone app, still shows as Custom
    with h.mock.lock:
        h.mock.settings["driveMode"] = 5
    h.check(h.wait_until("driveModeTile.status === 'Custom' && driveModeTile.icon === 'modeCustom'", 7000),
            "a saved Custom still shows on the tile")

    posts_before = len(h.mock.posts)
    h.click("driveModeTile")
    h.wait(300)
    h.click("controlsTitle")  # outside the panel, so this lands on the dimmed background
    h.check(h.wait_until("!driveModePopup.visible", 1000), "tapping outside the panel closes the pop-up")
    h.click("driveModeTile")
    h.wait(300)
    h.click("driveModePopup.closeButton")
    h.check(h.wait_until("!driveModePopup.visible", 1000) and len(h.mock.posts) == posts_before,
            "so does its close button, and neither sends anything")

    h.eval("driveModePopup.closeAfterMs = 500")
    h.click("driveModeTile")
    h.check(h.wait_until("!driveModePopup.visible", 1500), "the pop-up closes by itself if nothing is picked")


@scenario
def drift_stick_popup(h):
    """Drift Stick opens a pop-up of Off / Drift Only / All Modes; each pick sends only what changes."""
    h.start_app(settings={"enableDriftMode": 0, "driftInAllModes": 0})
    h.goto_controls()
    h.check(h.wait_until("driftStickTile.status === 'Off' && !driftStickTile.lit", 1500), "starts off, and the tile says so")

    h.click("driftStickTile")
    h.wait(300)
    h.check(h.eval("driftStickPopup.visible && !driveModePopup.visible"), "tapping Drift Stick opens its own pop-up")
    h.check(h.eval("[0, 1, 2].map(function(i) { return driftStickPopup.optionButton(i).name; })")
            == ["Off", "Drift\nOnly", "All\nModes"], "Off, Drift Only, All Modes")
    h.check(h.eval("[0, 1, 2].map(function(i) { return driftStickPopup.optionButton(i).currentValue; })") == [1, 0, 0],
            "only Off is lit")
    check_popup_layout(h, "driftStickPopup", 3)
    image = h.view.grabWindow()
    h.check(ring_colour(h, image, "driftStickPopup.optionButton(0)") == "#0dffd7", "lit in Drift Stick's aqua")
    h.shot("drift_stick_popup")

    # Off -> All Modes: turn it on, then set all modes
    posts_before = len(h.mock.posts)
    h.click("driftStickPopup.optionButton(2)")
    h.check(h.wait_until("driftStickChoice === 2", 1500), "picking All Modes turned it on in all modes")
    h.check(h.mock.posts[posts_before:] == [{"enableDriftMode": 1}, {"driftInAllModes": 1}],
            "sent enableDriftMode=1, then driftInAllModes=1")
    h.check(h.wait_until("driftStickTile.lit && driftStickTile.status === 'All Modes'"
                         " && toast.text === 'Drift Stick: All Modes'", 1000), "tile lit, All Modes, and a note")

    # All Modes -> Drift Only: already on, so only the mode choice
    posts_before = len(h.mock.posts)
    h.click("driftStickTile")
    h.wait(300)
    h.click("driftStickPopup.optionButton(1)")
    h.check(h.wait_until("driftStickChoice === 1", 1500), "picking Drift Only switched to Drift mode only")
    h.check(h.mock.posts[posts_before:] == [{"driftInAllModes": 0}], "sent only driftInAllModes=0")

    # Drift Only -> Off: only the on/off switch
    posts_before = len(h.mock.posts)
    h.click("driftStickTile")
    h.wait(300)
    h.click("driftStickPopup.optionButton(0)")
    h.check(h.wait_until("driftStickChoice === 0", 1500), "picking Off turned it off")
    h.check(h.mock.posts[posts_before:] == [{"enableDriftMode": 0}], "sent only enableDriftMode=0")

    # Picking the current choice sends nothing
    posts_before = len(h.mock.posts)
    h.click("driftStickTile")
    h.wait(300)
    h.click("driftStickPopup.optionButton(0)")
    h.wait(300)
    h.check(len(h.mock.posts) == posts_before and not h.eval("driftStickPopup.visible"),
            "picking Off again closes the pop-up and sends nothing")

    # If the ESP32 rejects turning it on, the mode choice isn't sent
    h.mock.post_status = 500
    posts_before = len(h.mock.posts)
    h.click("driftStickTile")
    h.wait(300)
    h.click("driftStickPopup.optionButton(2)")
    h.wait(600)
    h.check(h.mock.posts[posts_before:] == [{"enableDriftMode": 1}] and h.eval("driftStickChoice") == 0,
            "rejected: only the switch was tried, and it still shows Off")
    h.check(h.eval("toast.failed") and h.eval("toast.text").startswith("Couldn't reach"), "and a note says it failed")


@scenario
def controls_sync(h):
    """The Controls page keeps up with the ESP32 (e.g. changes from the RSapp phone app) every 5 s."""
    h.start_app(settings={"driveMode": 1, "esp": 0, "enableLC": 0})
    h.goto_controls()
    h.check(h.wait_until("driveModeState.currentValue === 1", 1500), "starts on Sport")
    with h.mock.lock:
        h.mock.settings.update({"driveMode": 3, "esp": 1, "enableLC": 1})
    h.check(h.wait_until("driveModeTile.status === 'Drift' && espTile.lit && lcTile.lit", 7000),
            "settings changed on the ESP32 show up within 5 s")
    h.mock.post_status = 500
    h.click("espTile")
    h.check(h.wait_until("toast.failed", 1000) and h.eval("espTile.lit"),
            "a rejected change says so and leaves the setting as it was")


@scenario
def controls_live(h):
    """The live Drive Mode and ESP tiles show the car's current state and change it now through POST /control."""
    h.start_app(pids={"mode": 0, "esc": 0})
    h.goto_controls()
    h.check(h.wait_until("liveDriveModeTile.status === 'Normal' && escTile.status === 'On'", 1500),
            "the tiles show the car's drive mode and ESP from /pids")
    h.check(not h.eval("escTile.lit") and h.eval("liveDriveModeTile.lit"), "ESP unlit while On")

    h.click("liveDriveModeTile")
    h.wait(300)
    h.check(h.eval("liveDriveModePopup.visible && !driveModePopup.visible"), "the live Drive Mode tile opens its own pop-up")
    h.check(h.eval("liveDriveModePopup.title") == "Drive mode now" and "right away" in h.eval("liveDriveModePopup.subtitle"),
            "headed Drive mode now, saying it applies right away")
    h.check(h.eval("[0, 1, 2, 3].map(function(i) { return liveDriveModePopup.optionButton(i).name; })")
            == ["Normal", "Sport", "Track", "Drift"], "Normal, Sport, Track, Drift")
    h.check(h.eval("[0, 1, 2, 3].map(function(i) { return liveDriveModePopup.optionButton(i).currentValue; })") == [1, 0, 0, 0],
            "only Normal is lit")
    check_popup_layout(h, "liveDriveModePopup", 4)
    h.shot("live_drive_mode_popup")

    h.click("liveDriveModePopup.optionButton(3)")
    h.check(h.wait_until("liveDriveModeTile.status === 'Drift'", 3000), "picking Drift sent it and the tile follows /pids")
    h.check(h.mock.controls == [{"mode": 3}] and h.mock.posts == [], "sent POST /control {mode: 3}, and nothing to /settings")
    h.check(h.eval("toast.text") == "Switching to Drift mode", "and a note says so")

    # picking the current mode sends nothing
    h.click("liveDriveModeTile")
    h.wait(300)
    h.click("liveDriveModePopup.optionButton(3)")
    h.wait(300)
    h.check(len(h.mock.controls) == 1, "picking the current mode sends nothing")

    # ESP
    h.click("escTile")
    h.wait(300)
    h.check(h.eval("escPopup.visible") and h.eval("escPopup.title") == "ESP now", "the ESP tile opens its pop-up")
    h.check(h.eval("[0, 1, 2].map(function(i) { return escPopup.optionButton(i).name; })") == ["On", "Sport", "Off"],
            "On, Sport, Off")
    check_popup_layout(h, "escPopup", 3)
    h.click("escPopup.optionButton(2)")
    h.check(h.wait_until("escTile.status === 'Off' && escTile.lit", 3000), "picking Off sent it and the tile follows")
    h.check(h.mock.controls[-1:] == [{"esc": 2}], "sent POST /control {esc: 2}")

    # while the car is making a change, the tile says so
    with h.mock.lock:
        h.mock.hold_controls = True
    h.click("liveDriveModeTile")
    h.wait(300)
    h.click("liveDriveModePopup.optionButton(1)")
    h.check(h.wait_until("liveDriveModeTile.status === 'Changing to Sport...'", 1500),
            "until /pids shows it, the tile says Changing to Sport...")
    with h.mock.lock:
        h.mock.pids["mode"] = 1
    h.check(h.wait_until("liveDriveModeTile.status === 'Sport'", 3000), "then shows Sport")
    with h.mock.lock:
        h.mock.hold_controls = False

    # failures leave the tile as it was, and the note says why. (A 409 reads as no answer in Qt, so it
    # gets the default, like 500.)
    for status, text in ((503, "isn't ready"), (404, "can't do that yet"),
                         (500, "Couldn't reach")):
        h.mock.control_status = status
        h.click("escTile")
        h.wait(300)
        h.click("escPopup.optionButton(1)")
        ok = h.wait_until("toast.failed && toast.text.indexOf(%r) >= 0" % text, 1500)
        h.check(ok, "HTTP %d says: %s (toast: %r)" % (status, text, h.eval("toast.text")))
        h.check(h.eval("escTile.status") == "Off", "and the tile still shows Off")
        h.eval("toastTimer.stop()")
        h.wait(300)

    # a car that isn't saying (asleep, or firmware without these values)
    h.start_app(pids={"mode": -1, "esc": -1})
    h.goto_controls()
    h.wait(400)
    h.check(h.eval("liveDriveModeTile.status") == "Not available" and h.eval("escTile.status") == "Not available"
            and not h.eval("liveDriveModeTile.lit") and not h.eval("escTile.lit"), "unknown: Not available, unlit")


@scenario
def settings_obd_toggle(h):
    """Flip OBD on the settings page and back."""
    h.start_app()
    h.goto_settings()
    h.check(h.eval("obdToggle.currentState") == "Alone", "OBD toggle starts at Alone")
    h.shot("settings_alone")

    h.click("obdToggle")
    h.check(h.wait_until("notAlone"), "app switched to Not Alone")
    h.check(h.mock.posts[-1:] == [{"cobbFriendly": 1}], "sent cobbFriendly=1 to the ESP32")
    h.check(h.eval("obdToggle.currentState") == "Not Alone", "toggle shows Not Alone")
    h.check(not h.eval("obdRequestPending"), "toggle un-dimmed once the ESP32 accepted")
    h.wait(300)  # slider animation
    h.shot("settings_not_alone")

    h.click("obdToggle")
    h.check(h.wait_until("!notAlone"), "app switched back to Alone")
    h.check(h.mock.posts[-1:] == [{"cobbFriendly": 0}], "sent cobbFriendly=0 to the ESP32")


@scenario
def settings_obd_refresh(h):
    """Opening settings re-reads the OBD mode, e.g. after it was changed from the RSapp phone app."""
    h.start_app()
    with h.mock.lock:
        h.mock.settings["cobbFriendly"] = 1  # changed elsewhere, before the main page's next 5 s check
    h.goto_settings()
    h.check(h.wait_until("obdToggle.currentState === 'Not Alone'", 1500), "toggle shows Not Alone as soon as settings opens")


@scenario
def controls_help(h):
    """Settings' Controls Help button opens a page explaining each main view control; back returns to settings."""
    h.start_app()
    h.goto_settings()
    h.check(h.eval("(function() { var p = controlsHelpButton.mapToItem(null, 0, 0);"
                   " return p.x < 40 && p.y + controlsHelpButton.height > 440; })()"),
            "Controls Help button in the bottom left of the settings page")
    h.click("controlsHelpButton")
    h.goto_page("ControlsHelpView.qml")
    rows = ["closeHelp", "settingsHelp", "controlsButtonHelp", "logoHelp", "lcHelp", "espHelp", "driveModeHelp",
            "startStopHelp", "driftStickHelp"]
    h.check(h.eval("[%s].map(function(r) { return r.label; })" % ", ".join(rows))
            == ["Close", "Settings", "Controls", "Logo - Second page", "Launch Control", "ESP Sport (at startup)",
                "Drive Mode (at startup)", "Auto Start-Stop (at startup)", "Drift Stick"],
            "explains Close, Settings, the logo, then each control, marking the startup settings")
    h.check(h.eval("[%s].every(function(r) { return r.description.length > 10; })" % ", ".join(rows)),
            "every control has a description")
    h.check(h.eval("driftStickHelp.mapToItem(null, 0, driftStickHelp.height).y <= 480"
                   " && helpRows.y >= helpTitle.y + helpTitle.height"),
            "all rows fit on the page under the title, the last one included")
    h.shot("controls_help")
    h.click("backButton")
    h.goto_page("SettingsView.qml")
    h.check(h.current_page() == "SettingsView.qml", "back arrow returns to settings")


@scenario
def settings_version(h):
    """The settings page footer shows the app version from version.txt."""
    version = (APP / "version.txt").read_text(encoding="utf-8").strip()
    h.start_app()
    h.goto_settings()
    h.wait(300)
    h.check(h.eval("copyright.text").startswith("RSdash %sJC" % version), "footer says RSdash %sJC" % version)
    # Nutron (the ESP32 device and firmware) credited with its logo, above
    # the app's own credit line, clear of the settings toggles
    h.check(h.eval("nutronLogo.status === Image.Ready && nutronLogo.paintedWidth > 0"
                   " && nutronCredit.text.indexOf('Nutron') >= 0"), "Nutron logo loaded, with its credit line")
    h.check(h.eval("nutronLogo.y + nutronLogo.height <= nutronCredit.y && nutronCredit.y + nutronCredit.height <= copyright.y"
                   " && nutronLogo.x >= obdToggle.mapToItem(null, obdToggle.width, 0).x + 10"
                   " && nutronLogo.x + nutronLogo.width <= 800 && nutronLogo.x >= controlsHelpButton.x + controlsHelpButton.width"),
            "logo and credit sit above the author line, beside the toggles, clear of Controls Help")
    h.shot("settings_credits")


@scenario
def settings_obd_rejected(h):
    """If the ESP32 rejects the change, the toggle stays put and un-dims."""
    h.start_app()
    h.goto_settings()
    h.mock.post_status = 500
    h.click("obdToggle")
    h.wait(800)
    h.check(h.mock.posts == [{"cobbFriendly": 1}], "the change was sent")
    h.check(not h.eval("notAlone") and h.eval("obdToggle.currentState") == "Alone", "toggle stayed at Alone")
    h.check(not h.eval("obdRequestPending"), "toggle un-dimmed")


@scenario
def settings_obd_slow_esp32(h):
    """ESP32 answers after 6 s: toggle dims, un-dims at the 5 s timeout, then syncs on the late answer."""
    h.start_app()
    h.goto_settings()
    h.mock.latency = 6
    h.click("obdToggle")
    h.wait(1000)
    h.check(h.eval("obdRequestPending") and not h.eval("notAlone"), "dimmed and unchanged while waiting")
    h.shot("settings_obd_pending")
    h.check(h.wait_until("!obdRequestPending", 5000), "un-dimmed after the 5 s timeout")
    h.mock.latency = 0
    h.check(h.wait_until("notAlone", 3000), "late acceptance still switched the app to Not Alone")


@scenario
def settings_units_saved(h):
    """The unit toggles still write NutronConfig.ini."""
    h.start_app()
    h.goto_settings()
    h.click("temperatureToggle")
    h.wait(300)
    h.check("TemperatureUnit=Fahrenheit" in h.ini_path.read_text(encoding="utf-8"), "ini now says Fahrenheit")
    h.check(h.eval("temperatureUnit") == "Fahrenheit", "app switched to Fahrenheit")
    h.click("speedToggle")
    h.wait(300)
    h.check("SpeedUnit=mph" in h.ini_path.read_text(encoding="utf-8") and h.eval("speedUnit") == "mph",
            "the speed toggle saves mph, and the ini still has the other units")
    h.check("TemperatureUnit=Fahrenheit" in h.ini_path.read_text(encoding="utf-8"), "without losing Fahrenheit")


@scenario
def imperial_worst_case(h):
    """Fahrenheit/PSI/Lb-Ft/mph, hot clutches, big numbers: worst case for text fit on both pages."""
    h.start_app(ini={"TemperatureUnit": "Fahrenheit", "PressureUnit": "PSI", "TorqueUnit": "Lb-Ft", "SpeedUnit": "mph"},
                pids={"rdutl": 118, "rdutr": 125, "engine": 121, "coolant": 121, "iat": 79, "ptu": 121, "rdu": 121,
                      "rdutql": 1550, "rdutqr": 1480, "speed": 258, "boost": 2.4, "latG": -1.4, "longG": 1.4,
                      "steering": -450, "yaw": 90, "brake": 100, "wheelFL": 258, "wheelFR": 258, "wheelRL": 258,
                      "wheelRR": 258, "flw": 3.45, "frw": 3.45, "rlw": 3.45, "rrw": 3.45})
    h.check(h.eval("temperatureUnit") == "Fahrenheit", "imperial units loaded from the ini")
    h.wait(300)
    h.check(h.eval("boostGauge.currentValue") == 2.4 and h.eval("coolantGauge.currentValue") == 121, "big values received")
    h.shot("imperial_engine")
    h.click("nutronLogo")
    h.goto_page("AwdView.qml")
    h.wait(300)
    h.check(h.eval("[leftTqBar, rightTqBar, splitBar, totalBar, slipBar].every(function(b) { return b.valueLabel.paintedWidth <= b.valueWidth; })"),
            "the torque, split, total and slip readings fit")
    h.check(h.eval("vehicleSpeedText.paintedWidth <= 200"), "so does the car's speed")
    h.shot("imperial_awd")


@scenario
def esp32_offline(h):
    """ESP32 unreachable at startup: nothing breaks, and values appear once it's back."""
    h.start_app(esp32_online=False)
    h.wait(1000)
    h.check(h.eval("oilGauge.currentValue") == 0, "no values while offline")
    h.shot("esp32_offline")
    h.mock.online = True
    h.check(h.wait_until("oilGauge.currentValue === 92", 5000), "values arrived once the ESP32 came back")


@scenario
def ready_to_race(h):
    """The Ready To Race popup appears once PTU, RDU and oil are all warm."""
    h.start_app(suppress_rtr=False, pids={"ptu": 20, "rdu": 10, "engine": 40})
    h.check(not h.eval("rtrDisplayed", on="app"), "no popup while cold")
    with h.mock.lock:
        h.mock.pids.update(ptu=62, rdu=58, engine=92)
    h.check(h.wait_until("rtrDisplayed", 2000, on="app"), "popup triggered once warm")
    h.wait(700)
    h.shot("ready_to_race")
    h.check(h.wait_until("readyToRaceLogo.opacity === 0", 5000), "popup faded out")
    for pids in ({"ptu": 20}, {"ptu": 62}):  # cool down, warm up again
        with h.mock.lock:
            h.mock.pids.update(pids)
        h.wait(700)
    h.check(h.eval("readyToRaceLogo.opacity") == 0, "popup doesn't come back on re-warming")


# --------------------------------------------------------------------- main

def run_scenarios(h, log, names):
    total_problems = 0
    for fn in [s for s in SCENARIOS if not names or any(n in s.__name__ for n in names)]:
        print("\n== %s: %s" % (fn.__name__, fn.__doc__))
        mark = log.mark()
        failures_before = len(h.failures)
        try:
            fn(h)
        except HarnessError as e:
            h.check(False, "harness: %s" % e)
        h.stop_app()
        problems = log.problems_since(mark)
        for text in problems:
            print("    QML  %s" % text)
        total_problems += len(problems)
        if len(h.failures) == failures_before and not problems:
            print("    passed")
    return total_problems


def render_readme_shots(h):
    """Renders the screenshots shown in README.md into docs/screenshots/."""
    h.start_app(pids={"rdutql": 240, "rdutqr": 310})
    h.shot("main_view", README_SHOTS)
    h.click("nutronLogo")
    h.goto_page("AwdView.qml")
    h.wait(300)
    h.shot("awd_view", README_SHOTS)

    h.start_app(settings={"enableDriftMode": 1, "driftInAllModes": 1, "esp": 1, "disableStartStop": 1, "driveMode": 2},
                pids={"mode": 1, "esc": 0})
    h.goto_controls()
    h.wait(300)
    h.shot("controls", README_SHOTS)
    h.click("driveModeTile")
    h.wait(300)
    h.shot("drive_mode_popup", README_SHOTS)
    h.click("driveModePopup.closeButton")
    h.wait(300)
    h.click("driftStickTile")
    h.wait(300)
    h.shot("drift_stick_popup", README_SHOTS)
    h.click("driftStickPopup.closeButton")
    h.wait(300)
    h.click("backButton")
    h.goto_page("PrimaryView.qml")
    h.goto_settings()
    h.shot("settings", README_SHOTS)
    h.click("controlsHelpButton")
    h.goto_page("ControlsHelpView.qml")
    h.shot("controls_help", README_SHOTS)


def run_interactive(h, args):
    h.start_app(settings={"cobbFriendly": int(args.not_alone)}, suppress_rtr=False)
    h.mock.animate = args.animate
    print("RSdash is running against a fake ESP32 at %s" % h.mock.url)
    print("Anything the app sends to the ESP32 is printed below. Close the window to quit.")
    seen = [0]

    def show_posts():
        with h.mock.lock:
            new = h.mock.posts[seen[0]:]
            seen[0] = len(h.mock.posts)
        for body in new:
            print("  app -> ESP32: POST /settings %s" % body)

    timer = QTimer()
    timer.timeout.connect(show_posts)
    timer.start(200)
    h.qt_app.exec_()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="*", help="only run scenarios whose name contains one of these")
    parser.add_argument("--list", action="store_true", help="list scenarios and exit")
    parser.add_argument("--interactive", action="store_true", help="open a clickable window instead")
    parser.add_argument("--not-alone", action="store_true", help="interactive: start in OBD Not Alone")
    parser.add_argument("--animate", action="store_true", help="interactive: drift the live values")
    parser.add_argument("--readme-shots", action="store_true", help="render the README screenshots into docs/screenshots/")
    parser.add_argument("--verbose", action="store_true", help="also print the app's console.log output")
    args = parser.parse_args()

    if args.list:
        for fn in SCENARIOS:
            print("%-26s %s" % (fn.__name__, fn.__doc__))
        return 0

    qt_app = QGuiApplication(sys.argv[:1])
    log = MessageLog(args.verbose)

    print("== static checks (Sync 3 compatibility)")
    static_problems = static_checks()
    for problem in static_problems:
        print("    FAIL %s" % problem)
    if not static_problems:
        print("    passed")

    h = Harness(qt_app, log, args.interactive)
    try:
        if args.interactive:
            run_interactive(h, args)
            return 0
        if args.readme_shots:
            print("\n== README screenshots")
            mark = log.mark()
            render_readme_shots(h)
            h.stop_app()
            problems = log.problems_since(mark)
            for text in problems:
                print("    QML  %s" % text)
            return 1 if problems else 0
        qml_problems = run_scenarios(h, log, args.names)
    finally:
        h.close()

    print("\n%d failed checks, %d QML warnings/errors, %d static problems"
          % (len(h.failures), qml_problems, len(static_problems)))
    return 1 if (h.failures or qml_problems or static_problems) else 0


if __name__ == "__main__":
    sys.exit(main())
