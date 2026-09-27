"""Runs RSdash on a PC against a fake ESP32 (mock_esp32.py).

    python dev/harness.py                  run every scenario; screenshots go to dev/out/
    python dev/harness.py obd              run only scenarios whose name contains "obd"
    python dev/harness.py --list           list the scenarios
    python dev/harness.py --interactive    open a clickable 800x480 window
                          [--not-alone] [--animate]

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
from PyQt5.QtGui import QGuiApplication
from PyQt5.QtQml import QJSValue, QQmlComponent, QQmlExpression
from PyQt5.QtQuick import QQuickItem, QQuickView
from PyQt5.QtTest import QTest

from mock_esp32 import MockEsp32

DEV = Path(__file__).resolve().parent
APP = DEV.parent / "SyncMyMod" / "app"
OUT = DEV / "out"

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

    def goto_settings(self):
        if self.current_page() == "PrimaryView.qml":
            self.click("nutronLogo")
            self.goto_page("SecondaryView.qml")
        self.click("settingsButton")
        self.goto_page("SettingsView.qml")

    def goto_gauges(self):
        if self.current_page() == "SettingsView.qml":
            self.click("backButton")
            self.goto_page("SecondaryView.qml")
        if self.current_page() == "SecondaryView.qml":
            self.click("nutronLogo2")
            self.goto_page("PrimaryView.qml")

    # -- results

    def check(self, ok, what):
        print("    %s %s" % ("ok  " if ok else "FAIL", what))
        if not ok:
            self.failures.append(what)

    def shot(self, name):
        OUT.mkdir(exist_ok=True)
        path = OUT / (name + ".png")
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
    h.check(h.eval("lambdaGauge.visible && !clutchTempGauge.visible"), "lambda shown, split clutch gauge hidden")
    h.check(h.eval("oilGauge.x === lambdaGauge.x && oilGauge.y < lambdaGauge.y"), "Oil sits directly above lambda")
    h.check(h.eval("oilGauge.currentValue") == 92, "oil temp received from the ESP32")
    h.check(abs(h.eval("lambdaGauge.currentValue") - 0.98) < 1e-9, "lambda received from the ESP32")
    h.shot("gauges_alone")


@scenario
def gauges_not_alone(h):
    """OBD Not Alone (set on the ESP32): the split RDU clutch gauge replaces lambda."""
    h.start_app(settings={"cobbFriendly": 1})
    h.check(h.eval("notAlone"), "app picked up Not Alone from the ESP32")
    h.check(h.eval("clutchTempGauge.visible && !lambdaGauge.visible"), "split clutch gauge shown in lambda's place")
    h.check(h.eval("[clutchTempGauge.leftValue, clutchTempGauge.rightValue]") == [71, 74], "left/right clutch temps")
    h.shot("gauges_not_alone")


@scenario
def gauge_tap_does_nothing(h):
    """Tapping the lambda / split gauge no longer changes the OBD mode."""
    h.start_app()
    h.click("lambdaGauge")
    h.wait(300)
    h.check(not h.mock.posts, "tapping lambda sent nothing to the ESP32")
    h.start_app(settings={"cobbFriendly": 1})
    h.click("clutchTempGauge")
    h.wait(300)
    h.check(not h.mock.posts, "tapping the split gauge sent nothing to the ESP32")


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
    h.check(h.eval("clutchTempGauge.visible && !lambdaGauge.visible"), "gauge page shows the split clutch gauge")

    h.goto_settings()
    h.click("obdToggle")
    h.check(h.wait_until("!notAlone"), "app switched back to Alone")
    h.check(h.mock.posts[-1:] == [{"cobbFriendly": 0}], "sent cobbFriendly=0 to the ESP32")
    h.goto_gauges()
    h.check(h.eval("lambdaGauge.visible && !clutchTempGauge.visible"), "gauge page shows lambda again")


@scenario
def settings_obd_refresh(h):
    """Opening settings re-reads the OBD mode, e.g. after it was changed from the RSapp phone app."""
    h.start_app()
    h.click("nutronLogo")
    h.goto_page("SecondaryView.qml")
    with h.mock.lock:
        h.mock.settings["cobbFriendly"] = 1  # changed elsewhere; the secondary page doesn't poll it
    h.click("settingsButton")
    h.goto_page("SettingsView.qml")
    h.check(h.wait_until("obdToggle.currentState === 'Not Alone'", 1500), "toggle shows Not Alone as soon as settings opens")


@scenario
def settings_version(h):
    """The settings page footer shows the app version from version.txt."""
    version = (APP / "version.txt").read_text(encoding="utf-8").strip()
    h.start_app()
    h.goto_settings()
    h.wait(300)
    h.check(h.eval("copyright.text").startswith("RSdash %sJC" % version), "footer says RSdash %sJC" % version)


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
    """Fahrenheit/PSI/Lb-Ft, RDU extra view, hot clutches: worst case for text fit."""
    h.start_app(ini={"TemperatureUnit": "Fahrenheit", "PressureUnit": "PSI", "TorqueUnit": "Lb-Ft",
                     "ExtraAreaView": "RDU"},
                settings={"cobbFriendly": 1}, pids={"rdutl": 118, "rdutr": 125, "engine": 121})
    h.check(h.eval("extraAreaView") == "RDU", "RDU extra view loaded from the ini")
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
        qml_problems = run_scenarios(h, log, args.names)
    finally:
        h.close()

    print("\n%d failed checks, %d QML warnings/errors, %d static problems"
          % (len(h.failures), qml_problems, len(static_problems)))
    return 1 if (h.failures or qml_problems or static_problems) else 0


if __name__ == "__main__":
    sys.exit(main())
