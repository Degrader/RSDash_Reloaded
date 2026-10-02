"""Records a video tour of RSdash into docs/: tour.mp4 and tour.gif.

    python dev/tour.py

Drives the real app against the fake ESP32 (live values drifting), like the
harness does. The app renders at 2x (1600x960) for sharp text and rings, and
the window is grabbed 30 times a second. Each frame gets a caption strip
under the app and a ring where the last tap landed, and is streamed straight
into ffmpeg as raw pixels (saving PNGs was too slow to keep up). That makes
a lossless intermediate, which is then encoded into the MP4 and the GIF.

Needs PyQt5 plus imageio-ffmpeg for its ffmpeg build:

    python -m pip install PyQt5 imageio-ffmpeg
"""

import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# Render the app at 2x. Read by Qt when the QGuiApplication is created.
SCALE = 2
os.environ["QT_SCALE_FACTOR"] = str(SCALE)

from harness import DEV, Harness, MessageLog  # sets the rest of the Qt environment

from PyQt5.QtCore import QPointF, QRectF, Qt, QTimer
from PyQt5.QtGui import QColor, QFont, QFontMetrics, QGuiApplication, QImage, QPainter, QPen

import imageio_ffmpeg

DOCS = DEV.parent / "docs"
FPS = 30
APP_W, APP_H = 800, 480  # logical size; frames are SCALE times this
CAPTION_H = 56
TAP_MS = 600  # how long the tap ring stays visible
FRAME_W, FRAME_H = APP_W * SCALE, (APP_H + CAPTION_H) * SCALE


class Recorder:
    """Grabs the harness window on a timer and streams framed pictures to ffmpeg.

    Frames are written against the wall clock, so if a grab runs late the
    previous frame is repeated and the video keeps real-time pacing. The
    repeats are counted, to show how smooth the recording was.
    """

    def __init__(self, h, out_path):
        self.h = h
        self.caption = ""
        self.tap = None  # (x, y, time), logical coordinates
        self.count = 0
        self.repeats = 0
        self.started = None
        self.ffmpeg = subprocess.Popen(
            [imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error",
             "-f", "rawvideo", "-pix_fmt", "bgra", "-s", "%dx%d" % (FRAME_W, FRAME_H), "-r", str(FPS), "-i", "-",
             "-c:v", "libx264", "-preset", "ultrafast", "-qp", "0", str(out_path)],
            stdin=subprocess.PIPE)
        self.timer = QTimer()
        self.timer.setTimerType(Qt.PreciseTimer)
        self.timer.setInterval(1000 // FPS)
        self.timer.timeout.connect(self._tick)

    def start(self):
        self.started = time.time()
        self.timer.start()
        self._tick()

    def stop(self):
        self.timer.stop()
        self.ffmpeg.stdin.close()
        if self.ffmpeg.wait() != 0:
            raise RuntimeError("ffmpeg failed while recording")

    def _frame(self):
        grab = self.h.view.grabWindow()
        frame = QImage(FRAME_W, FRAME_H, QImage.Format_RGB32)
        frame.fill(QColor("#101010"))
        p = QPainter(frame)
        p.setRenderHint(QPainter.Antialiasing)
        p.setRenderHint(QPainter.TextAntialiasing)
        p.drawImage(QRectF(0, 0, APP_W * SCALE, APP_H * SCALE), grab)
        p.scale(SCALE, SCALE)  # the rest is drawn in logical coordinates

        if self.tap:
            x, y, t = self.tap
            age = (time.time() - t) * 1000
            if age < TAP_MS:
                fade = 1 - age / TAP_MS
                p.setPen(QPen(QColor(255, 255, 255, int(220 * fade)), 3))
                p.setBrush(QColor(255, 255, 255, int(60 * fade)))
                r = 22 + 14 * (1 - fade)
                p.drawEllipse(QPointF(x, y), r, r)

        p.setPen(QPen(QColor("#329BFD"), 1))
        p.drawLine(QPointF(0, APP_H), QPointF(APP_W, APP_H))
        # Largest size up to 22 px that fits the caption on one line
        font = QFont("Segoe UI")
        font.setBold(True)
        for size in range(22, 11, -1):
            font.setPixelSize(size)
            if QFontMetrics(font).horizontalAdvance(self.caption) <= APP_W - 32:
                break
        p.setFont(font)
        p.setPen(QColor("#F8E63C"))
        p.drawText(QRectF(0, APP_H, APP_W, CAPTION_H), Qt.AlignCenter, self.caption)
        p.end()
        bits = frame.constBits()
        bits.setsize(frame.sizeInBytes())
        return bytes(bits)

    def _tick(self):
        frame = self._frame()
        due = int((time.time() - self.started) * FPS) + 1
        first = True
        while self.count < due:
            self.ffmpeg.stdin.write(frame)
            self.count += 1
            if not first:
                self.repeats += 1
            first = False


def tap(h, rec, item_id):
    """Taps an item like h.click does, and shows a ring there in the video."""
    x, y = h.eval("(function(){ var p = %s.mapToItem(null, %s.width / 2, %s.height / 2); return [p.x, p.y]; })()"
                  % ((item_id,) * 3))
    rec.tap = (x, y, time.time())
    h.click(item_id)


def say(rec, text):
    rec.caption = text


def run_tour(h, rec):
    h.mock.animate = True
    # PTU starts at 70 so its drift (+-15) stays warm for the Ready To Race part
    h.start_app(pids={"ptu": 70},
                settings={"driveMode": 1, "enableDriftMode": 0, "driftInAllModes": 0,
                          "esp": 1, "disableStartStop": 1, "enableLC": 0})
    rec.start()

    say(rec, "RSdash on the Sync 3: boost, gear and G-force live from the ESP32")
    h.wait(5000)
    say(rec, "Coolant, oil, intake, PTU and RDU temps, then brake, steering and yaw")
    h.wait(5000)

    say(rec, "Tap the logo for the AWD page")
    h.wait(1000)
    tap(h, rec, "nutronLogo")
    h.wait(2500)
    say(rec, "AWD temps, clutch torque and split on the left; tyre pressures and wheel speeds on the right")
    h.wait(7000)
    say(rec, "Tap the logo to go back")
    h.wait(800)
    tap(h, rec, "nutronLogo")
    h.wait(2000)

    say(rec, "The button on the left opens Controls")
    h.wait(1000)
    tap(h, rec, "chrome.controlsButton")
    h.wait(2200)
    say(rec, "Launch Control, ESP Sport and auto start-stop switch with a tap")
    h.wait(800)
    tap(h, rec, "lcTile")
    h.wait(1600)
    tap(h, rec, "espTile")
    h.wait(1600)
    tap(h, rec, "espTile")
    h.wait(1600)

    say(rec, "Drive Mode and ESP change the car right now")
    h.wait(800)
    tap(h, rec, "liveDriveModeTile")
    h.wait(2200)
    tap(h, rec, "liveDriveModePopup.optionButton(1)")
    h.wait(2400)
    tap(h, rec, "escTile")
    h.wait(2200)
    tap(h, rec, "escPopup.optionButton(1)")
    h.wait(2400)

    say(rec, "Below, Drive Mode is the mode the car starts in")
    h.wait(800)
    tap(h, rec, "driveModeTile")
    h.wait(2200)
    tap(h, rec, "driveModePopup.optionButton(2)")
    h.wait(2400)

    say(rec, "Drift Stick: Off, Drift Only or All Modes")
    h.wait(800)
    tap(h, rec, "driftStickTile")
    h.wait(2200)
    tap(h, rec, "driftStickPopup.optionButton(2)")
    h.wait(2400)
    tap(h, rec, "backButton")
    h.wait(1000)

    say(rec, "Settings: units for temperature, pressure, speed and torque")
    h.wait(800)
    tap(h, rec, "chrome.settingsButton")
    h.wait(2500)
    say(rec, "Controls Help explains what every button does")
    tap(h, rec, "controlsHelpButton")
    h.wait(4500)
    tap(h, rec, "backButton")
    h.wait(1000)
    tap(h, rec, "backButton")
    h.wait(1500)

    # Ready To Race: cool the oil, re-arm the popup, then warm it back up
    with h.mock.lock:
        h.mock.pids["engine"] = 40
    h.wait(800)
    h.eval("rtrDisplayed = false", on="app")
    say(rec, "Ready To Race pops up once PTU, RDU and oil are all warm")
    h.wait(1200)
    with h.mock.lock:
        h.mock.pids["engine"] = 92
    h.wait(5200)

    say(rec, "RSdash Reloaded")
    h.wait(2500)
    rec.stop()


def encode(source, name):
    """Encodes the lossless recording into docs/<name>.mp4 (full 2x size) and .gif."""
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    mp4 = DOCS / ("RSDashTour" if name == "tour" else name) .with_suffix(".mp4")
    gif = DOCS / (name + ".gif")
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(source),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "slow",
                    "-tune", "animation", "-movflags", "+faststart", str(mp4)], check=True)
    # Two-pass palette for a clean GIF, at 15 fps and the app's own 800 px width
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(source),
                    "-vf", "fps=15,scale=%d:-1:flags=lanczos,split[a][b];"
                           "[a]palettegen=stats_mode=diff[p];"
                           "[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" % APP_W,
                    str(gif)], check=True)
    for path in (mp4, gif):
        print("    %s  %.1f MB" % (path.relative_to(DEV.parent), path.stat().st_size / 1e6))


def main():
    qt_app = QGuiApplication(sys.argv[:1])
    log = MessageLog(False)
    h = Harness(qt_app, log, interactive=False)
    work = Path(tempfile.mkdtemp(prefix="rsdash-tour-"))
    recording = work / "tour.mkv"
    try:
        print("== recording")
        mark = log.mark()
        rec = Recorder(h, recording)
        run_tour(h, rec)
        h.stop_app()
        problems = log.problems_since(mark)
        for text in problems:
            print("    QML  %s" % text)
        print("    %d frames (%.1f s), %d repeated to keep pace (%.1f%%)"
              % (rec.count, rec.count / FPS, rec.repeats, 100.0 * rec.repeats / max(rec.count, 1)))
        print("== encoding")
        encode(recording, "tour")
        return 1 if problems else 0
    finally:
        h.close()
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
