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
        self.click("nutronLogo")
        self.goto_page("ControlsView.qml")

    def goto_settings(self):
        self.click("settingsButton")
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


@scenario
def gauges_alone(h):
    """OBD Alone: Oil on top, lambda below it, live values arriving."""
    h.start_app()
    h.check(h.eval("lambdaGauge.visible && !torqueSplitGauge.visible"), "lambda shown, torque split gauge hidden")
    h.check(h.eval("oilGauge.x === lambdaGauge.x && oilGauge.y < lambdaGauge.y"), "Oil sits directly above lambda")
    h.check(h.eval("oilGauge.currentValue") == 92, "oil temp received from the ESP32")
    h.check(abs(h.eval("lambdaGauge.currentValue") - 0.98) < 1e-9, "lambda received from the ESP32")
    h.check(h.eval("frontLeftTireGauge.visible && rearRightTireGauge.visible"
                   " && leftRDUTqGauge.visible && rightRDUTqGauge.visible"),
            "tire pressures and RDU torque both shown")
    h.check(h.eval("[leftRDUTqGauge.currentValue, rightRDUTqGauge.currentValue]") == [120, 135], "RDU torque received")
    h.check(h.eval("typeof lcGauge === 'undefined' && typeof driveModeGauge === 'undefined'"),
            "no control buttons on the main view (they're on the Controls page)")
    h.check(h.eval("Math.abs(ptuGauge.x - (800 - (sensorArea.x + sensorArea.width))) < 1"),
            "gauges centred across the screen")
    h.check(h.eval("oilGauge.x >= ptuGauge.x + ptuGauge.width && sensorArea.x >= oilGauge.x + oilGauge.width"
                   " && sensorArea.x + sensorArea.width <= 800"),
            "big gauges and the right column fit side by side on 800 px")
    h.check(h.eval("rduGauge.y >= ptuGauge.y + ptuGauge.height && rduGauge.y + rduGauge.height <= 480"),
            "both rows of big gauges fit on 480 px")
    # The top rings are open at the bottom, so the free space between the
    # four gauges runs from the lowest point of the top rings (their ends) to
    # the highest point of the bottom rings
    h.check(h.eval("(function() {"
                   "  var g = ptuGauge, a = g.startAngleDegrees * Math.PI / 180;"
                   "  var topRingsBottom = g.y + g.height / 2 + (g.width / 2 - g.thick) * Math.sin(a) + g.thick / 2;"
                   "  var bottomRingsTop = rduGauge.y + rduGauge.thick / 2;"
                   "  var cx = (ptuGauge.x + oilGauge.x + oilGauge.width) / 2, cy = (topRingsBottom + bottomRingsTop) / 2;"
                   "  return Math.abs(nutronLogo.x + nutronLogo.width / 2 - cx) < 1"
                   "      && Math.abs(nutronLogo.y + nutronLogo.height / 2 - cy) < 1; })()"),
            "logo centred in the free space between the four big gauges")
    # The visible part of the logo at its 1.1x pulse vs each ring as drawn:
    # its arc, the ring's thickness, and the 3 px the threshold marks stick
    # out past it. The logo scales about its centre.
    left, top, right, bottom = opaque_bounds(APP / "res" / "mountuners.png")
    clearance = h.eval("(function() {"
                       "  var s = 1.1, iw = nutronLogo.sourceSize.width, ih = nutronLogo.sourceSize.height;"
                       "  var k = nutronLogo.paintedHeight / ih;"
                       "  var cx = nutronLogo.x + nutronLogo.width / 2, cy = nutronLogo.y + nutronLogo.height / 2;"
                       "  var lx = cx + ((%f + %f) / 2 - iw / 2) * k * s, ly = cy + ((%f + %f) / 2 - ih / 2) * k * s;"
                       "  var hw = (%f - %f) / 2 * k * s, hh = (%f - %f) / 2 * k * s;"
                       % (left, right, top, bottom, right, left, bottom, top) +
                       "  var least = 1e9;"
                       "  [ptuGauge, oilGauge, rduGauge, lambdaGauge].forEach(function(g) {"
                       "    var r = g.width / 2 - g.thick, gx = g.x + g.width / 2, gy = g.y + g.height / 2;"
                       "    for (var d = g.startAngleDegrees; d <= g.endAngleDegrees; d += 0.25) {"
                       "      var px = gx + r * Math.cos(d * Math.PI / 180), py = gy + r * Math.sin(d * Math.PI / 180);"
                       "      var dx = Math.max(0, Math.abs(px - lx) - hw), dy = Math.max(0, Math.abs(py - ly) - hh);"
                       "      least = Math.min(least, Math.sqrt(dx * dx + dy * dy) - g.thick / 2 - 3);"
                       "    }"
                       "  });"
                       "  return least;"
                       "})()")
    h.check(clearance >= 8, "logo clears all four rings and marks by %.1f px at the top of its pulse (at least 8)" % clearance)
    h.check(h.eval("nutronLogo.height") == 80, "logo is 80 px tall")
    h.check(h.eval("pulseTimer.running && pulseTimer.repeat && nutronLogo.scale !== 1"), "logo is pulsing")
    # The gear sits in the bottom left corner: its nearest point to RDU's
    # ring must clear the ring, including the rounded end of its arc
    h.check(h.eval("(function() { var b = settingsButton, g = rduGauge;"
                   "  if (b.x > 10 || b.y + b.height < 470) return false;"
                   "  var r = g.width / 2 - g.thick, gx = g.x + g.width / 2, gy = g.y + g.height / 2, least = 1e9;"
                   "  for (var d = g.startAngleDegrees; d <= g.endAngleDegrees; d += 0.5) {"
                   "    var px = gx + r * Math.cos(d * Math.PI / 180), py = gy + r * Math.sin(d * Math.PI / 180);"
                   "    var dx = Math.max(0, Math.abs(px - (b.x + b.width / 2)) - b.width / 2);"
                   "    var dy = Math.max(0, Math.abs(py - (b.y + b.height / 2)) - b.height / 2);"
                   "    least = Math.min(least, Math.sqrt(dx * dx + dy * dy) - g.thick / 2);"
                   "  }"
                   "  return least >= 8; })()"),
            "settings button in the bottom left corner, clear of RDU's ring")
    h.check(h.eval("(function() { var rows = [[frontLeftTireGauge, frontRightTireGauge], [rearLeftTireGauge, rearRightTireGauge],"
                   " [leftRDUTempGauge, rightRDUTempGauge], [leftRDUTqGauge, rightRDUTqGauge]];"
                   " return rows.every(function(r, i) { var l = r[0].mapToItem(null, 0, 0), g = r[1].mapToItem(null, 0, 0);"
                   " return r[0].visible && r[1].visible && l.y === g.y && l.y >= 0 && l.y + r[0].height <= 480"
                   " && (i === 0 || l.y >= rows[i - 1][0].mapToItem(null, 0, 0).y + rows[i - 1][0].height); }); })()"),
            "front, rear, RDU temps and RDU torque rows all shown, top to bottom, on screen")
    h.check(h.eval("ptuGauge.showThresholdMarks && rduGauge.showThresholdMarks && oilGauge.showThresholdMarks"
                   " && frontLeftTireGauge.showThresholdMarks && rearRightTireGauge.showThresholdMarks"
                   " && !lambdaGauge.showThresholdMarks && !leftRDUTqGauge.showThresholdMarks"),
            "low/high marks on the temperature and tire gauges, not lambda or torque")
    h.shot("gauges_alone")


@scenario
def gauges_not_alone(h):
    """OBD Not Alone (set on the ESP32): the RDU torque split gauge replaces lambda."""
    h.start_app(settings={"cobbFriendly": 1})
    h.check(h.eval("notAlone"), "app picked up Not Alone from the ESP32")
    h.check(h.eval("torqueSplitGauge.visible && !lambdaGauge.visible"), "torque split gauge shown in lambda's place")
    # Default mock torque: 120 Nm left, 135 Nm right
    split = h.eval("[torqueSplitGauge.leftValue, torqueSplitGauge.rightValue]")
    h.check(abs(split[0] - 100 * 120 / 255) < 1e-9 and abs(split[1] - 100 * 135 / 255) < 1e-9,
            "left/right share of the rear torque: 47% / 53%")
    h.check(h.eval("torqueSplitGauge.name") == "Torque Split", "named Torque Split")
    h.check(h.eval("torqueSplitGauge.caption") == "OBD\nNOT ALONE", "caption reads OBD / NOT ALONE")
    h.check(h.eval("torqueSplitGauge.highTreshold >= torqueSplitGauge.maxValue && torqueSplitGauge.lowTreshold <= 0"),
            "a share never turns the gauge red")
    h.shot("gauges_not_alone")


@scenario
def rdu_rows(h):
    """RDU clutch temps and RDU torque are both shown, temps above torque; tapping them does nothing."""
    h.start_app(pids={"rdutl": 108, "rdutr": 98})  # left clutch over the 105 C red line, right under it
    h.check(h.eval("[leftRDUTempGauge.currentValue, rightRDUTempGauge.currentValue]") == [108, 98], "clutch temps received")
    h.check(h.eval("[leftRDUTqGauge.currentValue, rightRDUTqGauge.currentValue]") == [120, 135], "RDU torque received")
    h.check(h.eval("[rduTempText.text, rduText.text, rduTorqueText.text]") == ["Temps", "RDU", "Torque"],
            "labelled like TPMS: Temps, RDU between the rows, Torque")
    h.check(h.eval("rduText.font.pixelSize === tpmsText.font.pixelSize && rduTempText.font.pixelSize === frontText.font.pixelSize"
                   " && rduTorqueText.font.pixelSize === frontText.font.pixelSize"
                   " && Math.abs((rduText.y + rduText.height / 2)"
                   " - (leftRDUTempGauge.y + leftRDUTempGauge.height + leftRDUTqGauge.y) / 2) < 1"
                   " && Math.abs(rduText.x + rduText.width / 2 - sensorArea.width / 2) < 1"),
            "same sizes as the TPMS labels, with RDU centred between the four RDU gauges")
    h.check(h.eval("leftRDUTempGauge.highTreshold === 105 && rightRDUTempGauge.highTreshold === 105"),
            "clutch temp red line is 105 C on both clutch gauges")
    h.shot("rdu_rows")
    h.click("leftRDUTempGauge")
    h.click("leftRDUTqGauge")
    h.wait(300)
    h.check(not h.mock.posts and h.eval("leftRDUTempGauge.visible && leftRDUTqGauge.visible"),
            "tapping the rows sends nothing and hides nothing")


@scenario
def tire_pressure_limits(h):
    """Tire pressures go red below 35 psi and above 50 psi; 41-46 psi is normal."""
    # The ESP32 sends bar: 2.30 = 33.4 psi (low), 3.03 = 43.9 psi, 3.52 = 51.1 psi (high), 3.38 = 49.0 psi
    h.start_app(ini={"PressureUnit": "PSI"}, pids={"flw": 2.30, "frw": 3.03, "rlw": 3.52, "rrw": 3.38})
    limits = h.eval("[frontLeftTireGauge.lowTreshold * 14.5038, frontLeftTireGauge.highTreshold * 14.5038]")
    h.check(abs(limits[0] - 35) < 1e-9 and abs(limits[1] - 50) < 1e-9, "limits are 35 and 50 psi")
    h.shot("tire_pressure_limits")  # rendering also sets each gauge's colour
    colours = h.eval("[frontLeftTireGauge, frontRightTireGauge, rearLeftTireGauge, rearRightTireGauge]"
                     ".map(function(g) { return String(g.colour); })")
    red, blue = "#ce1845", "#0c32ff"
    h.check(colours == [red, blue, red, blue], "33.4 psi red, 43.9 blue, 51.1 red, 49.0 blue")


@scenario
def torque_split_idle(h):
    """Not Alone torque split: all torque on one side reads 100 / 0; under 10 Nm total both halves read 0."""
    h.start_app(settings={"cobbFriendly": 1}, pids={"rdutql": 0, "rdutqr": 400})
    h.check(h.eval("[torqueSplitGauge.leftValue, torqueSplitGauge.rightValue]") == [0, 100], "all on the right: 0% / 100%")
    h.shot("torque_split_right")
    with h.mock.lock:
        h.mock.pids.update({"rdutql": 4, "rdutqr": 5})
    h.check(h.wait_until("torqueSplitGauge.leftValue === 0 && torqueSplitGauge.rightValue === 0", 2000),
            "9 Nm total: both halves read 0 instead of 44% / 56%")


@scenario
def value_cutoff(h):
    """A gauge's coloured bar is cut flat, straight across the ring, exactly at its value; no indicator circle."""
    h.start_app(pids={"ptu": 65})
    h.wait(300)
    # Points on PTU's ring, d px along the ring from angle `at` (positive is
    # towards higher values) and `across` px out from the ring's centre line
    probe = ("(function(at, d, across) { var g = ptuGauge;"
             "  var a = at * Math.PI / 180, r = Math.min(g.width, g.height) / 2 - g.thick + across;"
             "  var p = g.mapToItem(null, g.width / 2 + r * Math.cos(a) - d * Math.sin(a),"
             "                            g.height / 2 + r * Math.sin(a) + d * Math.cos(a));"
             "  return [p.x, p.y]; })")
    value_angle = h.eval("ptuGauge.startAngleDegrees + (ptuGauge.currentValue - ptuGauge.minValue)"
                         " / (ptuGauge.maxValue - ptuGauge.minValue)"
                         " * (ptuGauge.endAngleDegrees - ptuGauge.startAngleDegrees)")
    start_angle = h.eval("ptuGauge.startAngleDegrees")

    def colour_at(at, d, across):
        x, y = h.eval("%s(%f, %f, %f)" % (probe, at, d, across))
        return image.pixelColor(int(round(x)), int(round(y))).name()

    image = h.view.grabWindow()
    blue, grey = h.eval("String(ptuGauge.colour)"), "#1e1e1e"
    for across in (-8, 0, 8):
        before, after = colour_at(value_angle, -3, across), colour_at(value_angle, 3, across)
        h.check(before == blue and after == grey,
                "cut flat at the value, %+d px across the ring: %s just before, %s just after"
                % (across, before, after))
    cap = colour_at(start_angle, -6, 0)
    h.check(cap == blue, "the bar's start keeps its rounded end over the track's (got %s)" % cap)
    h.shot("value_cutoff")

    with h.mock.lock:
        h.mock.pids["ptu"] = 0
    h.wait_until("ptuGauge.currentValue === 0", 2000)
    h.wait(200)
    image = h.view.grabWindow()
    cap = colour_at(start_angle, -6, 0)
    h.check(cap == grey, "at the bottom of the scale there's no bar, not even its rounded start (got %s)" % cap)


@scenario
def gauge_tap_does_nothing(h):
    """Tapping the lambda / split gauge no longer changes the OBD mode."""
    h.start_app()
    h.click("lambdaGauge")
    h.wait(300)
    h.check(not h.mock.posts, "tapping lambda sent nothing to the ESP32")
    h.start_app(settings={"cobbFriendly": 1})
    h.click("torqueSplitGauge")
    h.wait(300)
    h.check(not h.mock.posts, "tapping the split gauge sent nothing to the ESP32")


TILES = [("lcTile", "Launch Control", "launchControl", "#ff7e0d"),
         ("espTile", "ESP Sport", "espSport", "#0dc2ff"),
         ("driveModeTile", "Drive Mode", "modeSport", "#0c32ff"),
         ("startStopTile", "Auto Start-Stop", "autoStartStopOff", "#0dff5e"),
         ("driftStickTile", "Drift Stick", "driftStick", "#0dffd7")]


def ring_colour(h, image, item):
    """Screen colour in the middle of a ButtonGauge's ring, at its right-hand side."""
    x, y = h.eval("(function(){ var b = %s; var p = b.mapToItem(null, b.width - b.thick, b.height / 2);"
                  " return [p.x, p.y]; })()" % item)
    return image.pixelColor(int(round(x)), int(round(y))).name()


@scenario
def controls_page(h):
    """The logo opens Controls: a grid of tiles, each lit in its own colour, with icons, names and settings."""
    h.start_app(settings={"enableLC": 1, "esp": 1, "disableStartStop": 1, "enableDriftMode": 1,
                          "driftInAllModes": 1, "driveMode": 1})
    h.goto_controls()
    h.check(h.eval("controlsTitle.text") == "Controls", "tapping the logo opens the Controls page")
    h.check(h.wait_until("lcState.currentValue === 1 && driveModeState.currentValue === 1", 1500),
            "settings read from the ESP32 on opening")
    ids = ", ".join(t for t, _, _, _ in TILES)
    h.check(h.eval("[%s].map(function(t) { return [t.label, t.icon]; })" % ids) == [[l, i] for _, l, i, _ in TILES],
            "Launch Control, ESP Sport, Drive Mode, Auto Start-Stop, Drift Stick, with their icons")
    h.check(h.eval("[%s].map(function(t) { return t.status; })" % ids)
            == ["On", "On at startup", "Sport at startup", "Off at startup", "All Modes"],
            "each shows its current setting, marking the startup ones")
    h.check(h.eval("controlGrid.columns === 3 && [%s].every(function(t) { var p = t.mapToItem(null, 0, 0);"
                   " return p.x >= 0 && p.x + t.width <= 800 && p.y >= controlsTitle.y + controlsTitle.height"
                   " && p.y + t.height <= controlsNote.y; })" % ids),
            "tiles in a 3-column grid, between the title and the note, on screen")
    h.check(h.eval("controlGrid.height + controlsTitle.height + controlsNote.height < 480 - 20"),
            "room left in the grid for another control")
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
    h.check(got == ["#1e1e1e", "#1e1e1e", "#0c32ff", "#1e1e1e", "#1e1e1e"],
            "off: grey rings, Drive Mode (always set) still blue (got %s)" % got)

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
    h.check(h.wait_until("driveModeTile.status === 'Track at startup' && driveModeTile.icon === 'modeTrack'", 1500),
            "the tile shows the ESP32's mode (Track) and its icon")
    h.check(not h.eval("driveModePopup.visible"), "pop-up starts closed")

    h.click("driveModeTile")
    h.wait(300)
    h.check(h.eval("driveModePopup.visible && driveModePopup.opacity === 1"), "tapping the tile opens the pop-up")
    h.check(h.eval("driveModePopup.title") == "Startup drive mode"
            and "next time the car starts" in h.eval("driveModePopup.subtitle"),
            "headed Startup drive mode, saying when it applies")
    h.check(h.eval("[0, 1, 2, 3, 4].map(function(i) { return driveModePopup.optionButton(i).name; })")
            == ["Normal", "Sport", "Track", "Drift", "Custom"], "Normal to Custom")
    h.check(h.eval("[0, 1, 2, 3, 4].map(function(i) { return driveModePopup.optionButton(i).icon; })")
            == ["modeNormal", "modeSport", "modeTrack", "modeDrift", "modeCustom"], "each mode has its icon")
    h.check(h.eval("[0, 1, 2, 3, 4].map(function(i) { return driveModePopup.optionButton(i).currentValue; })")
            == [0, 0, 1, 0, 0], "only Track is lit")
    check_popup_layout(h, "driveModePopup", 5)
    h.shot("drive_mode_popup")

    posts_before = len(h.mock.posts)
    h.click("driveModePopup.optionButton(1)")
    h.check(h.wait_until("!driveModePopup.visible && driveModeTile.status === 'Sport at startup'", 1500),
            "picking Sport closes the pop-up and the tile shows Sport")
    h.check(h.mock.posts[posts_before:] == [{"driveMode": 1}], "sent driveMode=1 and nothing else")
    h.check(h.eval("toast.text") == "Starts in Sport mode from the next start", "and says it applies from the next start")

    # Custom is driveMode 5 (4 isn't used)
    h.click("driveModeTile")
    h.wait(300)
    h.click("driveModePopup.optionButton(4)")
    h.wait(300)
    h.check(h.mock.posts[-1:] == [{"driveMode": 5}], "tapping Custom sent driveMode=5")

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
    h.check(h.wait_until("driveModeTile.status === 'Drift at startup' && espTile.lit && lcTile.lit", 7000),
            "settings changed on the ESP32 show up within 5 s")
    h.mock.post_status = 500
    h.click("espTile")
    h.check(h.wait_until("toast.failed", 1000) and h.eval("espTile.lit"),
            "a rejected change says so and leaves the setting as it was")


@scenario
def settings_obd_toggle(h):
    """Flip OBD on the settings page and back; the gauge page follows."""
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

    h.goto_gauges()
    h.check(h.eval("torqueSplitGauge.visible && !lambdaGauge.visible"), "gauge page shows the torque split gauge")

    h.goto_settings()
    h.click("obdToggle")
    h.check(h.wait_until("!notAlone"), "app switched back to Alone")
    h.check(h.mock.posts[-1:] == [{"cobbFriendly": 0}], "sent cobbFriendly=0 to the ESP32")
    h.goto_gauges()
    h.check(h.eval("lambdaGauge.visible && !torqueSplitGauge.visible"), "gauge page shows lambda again")


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
    rows = ["closeHelp", "settingsHelp", "logoHelp", "lcHelp", "espHelp", "driveModeHelp", "startStopHelp",
            "driftStickHelp"]
    h.check(h.eval("[%s].map(function(r) { return r.label; })" % ", ".join(rows))
            == ["Close", "Settings", "Logo - Controls", "Launch Control", "ESP Sport (at startup)",
                "Drive Mode (at startup)", "Auto Start-Stop (at startup)", "Drift Stick"],
            "explains Close, Settings, the logo, then each control, marking the startup settings")
    h.check(h.eval("[%s].every(function(r) { return r.description.length > 10; })" % ", ".join(rows)),
            "every control has a description")
    h.check(h.eval("helpRows.mapToItem(null, 0, helpRows.height).y <= 480 && helpRows.y >= helpTitle.y + helpTitle.height"),
            "all rows fit on the page under the title")
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
                   " && nutronLogo.y >= obdToggle.mapToItem(null, 0, obdToggle.height).y + 10"
                   " && nutronLogo.x + nutronLogo.width <= 800 && nutronLogo.x >= controlsHelpButton.x + controlsHelpButton.width"),
            "logo and credit sit above the author line, below the toggles, clear of Controls Help")
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


@scenario
def imperial_not_alone(h):
    """Fahrenheit/PSI/Lb-Ft, hot clutches, big torque: worst case for text fit."""
    h.start_app(ini={"TemperatureUnit": "Fahrenheit", "PressureUnit": "PSI", "TorqueUnit": "Lb-Ft"},
                settings={"cobbFriendly": 1},
                pids={"rdutl": 118, "rdutr": 125, "engine": 121, "rdutql": 1550, "rdutqr": 1480})
    h.check(h.eval("temperatureUnit") == "Fahrenheit", "imperial units loaded from the ini")
    h.shot("imperial_not_alone")


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

    h.start_app(settings={"cobbFriendly": 1}, pids={"rdutql": 240, "rdutqr": 310})
    h.shot("main_view_not_alone", README_SHOTS)

    h.start_app(settings={"enableDriftMode": 1, "driftInAllModes": 1, "esp": 1, "disableStartStop": 1, "driveMode": 2})
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
