"""Makes SyncMyMod/app/res/car_top.png, the picture of the car on the AWD page,
from docs/car/focus_rs_top.webp.

    python dev/make_car.py

The source is a top-down picture of the Focus RS, nose to the left, with its
four tyres drawn in. The app draws the tyres itself, so each can turn red
with its pressure (CarTopView.qml), so this:

  - fills the hole in the roof (the picture has a gap where something was
    removed from it) with the roof's own colour,
  - blacks out the four drawn tyres, leaving a plain dark pill under the
    ones the app draws on top,
  - turns the car nose-up, trims it to a box centred on the car, and scales
    it to 360 px wide (twice the width it's shown at, so it stays sharp).

It prints the numbers CarTopView.qml needs (the picture's size in its own
units and where the tyres are), which are measured in the trimmed full-size
picture. Needs PyQt5 only. Re-run it after replacing the source picture, and
update the pill and hole positions below if the new one differs.
"""

import sys
from pathlib import Path

from PyQt5.QtCore import QPointF, QRectF, Qt
from PyQt5.QtGui import QColor, QGuiApplication, QImage, QPainter, QPainterPath, QTransform

DEV = Path(__file__).resolve().parent
SOURCE = DEV.parent / "docs" / "car" / "focus_rs_top.webp"
OUT = DEV.parent / "SyncMyMod" / "app" / "res" / "car_top.png"

# Measured on the source (x to the right, y down, nose on the left)
HOLE = (1050, 232, 1456, 608)       # a box round the gap in the roof: left, top, right, bottom
ROOF = (10, 16, 21)                 # the roof's colour round the gap
# The tyres drawn in the source: left, top, right, bottom of each one's outline
PILLS = [(352, 34, 557, 112), (1257, 34, 1467, 113), (352, 748, 558, 825), (1257, 747, 1466, 825)]
PILL_BLACK = (4, 6, 8)
PILL_LENGTH, PILL_WIDTH = 206, 79   # size of the pill the app draws, along and across the car
CLEAR_MARGIN = 3                    # how far past an outline to black out
# After turning the car nose-up: the box to keep, centred on the car and trimmed
# close to its nose, tail and the mirrors
CROP = (28, 36, 824, 1752)          # left, top, width, height
OUT_WIDTH = 360


def pixels(image):
    """The image's bytes as a writable view: B, G, R, A for each pixel (ARGB32)."""
    ptr = image.bits()
    ptr.setsize(image.byteCount())
    return memoryview(ptr).cast("B")


def rounded_box(box, radius):
    path = QPainterPath()
    path.addRoundedRect(QRectF(box[0], box[1], box[2] - box[0], box[3] - box[1]), radius, radius)
    return path


def main():
    app = QGuiApplication(sys.argv[:1])
    image = QImage(str(SOURCE)).convertToFormat(QImage.Format_ARGB32)
    if image.isNull():
        sys.exit("can't read %s" % SOURCE)
    width, height = image.width(), image.height()
    data = pixels(image)
    stride = image.bytesPerLine()

    # --- Fill the hole in the roof: whatever is see-through inside the box
    left, top, right, bottom = HOLE
    filled = 0
    for y in range(top, bottom):
        for x in range(left, right):
            i = y * stride + x * 4
            if data[i + 3] < 245:
                data[i], data[i + 1], data[i + 2], data[i + 3] = ROOF[2], ROOF[1], ROOF[0], 254
                filled += 1
    print("filled %d roof pixels" % filled)

    # --- Black out the drawn tyres, and any cyan fringe just outside them
    for box in PILLS:
        cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        inner = rounded_box((cx - PILL_LENGTH / 2 - CLEAR_MARGIN, cy - PILL_WIDTH / 2 - CLEAR_MARGIN,
                             cx + PILL_LENGTH / 2 + CLEAR_MARGIN, cy + PILL_WIDTH / 2 + CLEAR_MARGIN), 22)
        for y in range(box[1] - 8, box[3] + 9):
            for x in range(box[0] - 8, box[2] + 9):
                if not (0 <= x < width and 0 <= y < height):
                    continue
                i = y * stride + x * 4
                if inner.contains(QPointF(x + 0.5, y + 0.5)):
                    data[i], data[i + 1], data[i + 2], data[i + 3] = PILL_BLACK[2], PILL_BLACK[1], PILL_BLACK[0], 255
                elif data[i] - data[i + 2] > 20 and data[i + 3] > 0:    # blue well above red: a cyan fringe
                    dark = min(data[i], data[i + 1], data[i + 2])
                    data[i], data[i + 1], data[i + 2] = dark, dark, dark

    # --- Nose up (clockwise a quarter turn), trimmed, and scaled for the app
    turned = image.transformed(QTransform().rotate(90), Qt.SmoothTransformation)
    if (turned.width(), turned.height()) != (height, width):
        sys.exit("unexpected size after turning: %dx%d" % (turned.width(), turned.height()))
    left, top, crop_width, crop_height = CROP
    trimmed = turned.copy(left, top, crop_width, crop_height)
    out_height = round(crop_height * OUT_WIDTH / crop_width)
    small = trimmed.convertToFormat(QImage.Format_ARGB32_Premultiplied).scaled(
        OUT_WIDTH, out_height, Qt.IgnoreAspectRatio, Qt.SmoothTransformation).convertToFormat(QImage.Format_ARGB32)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if not small.save(str(OUT), "PNG"):
        sys.exit("can't write %s" % OUT)
    print("wrote %s: %dx%d, %.0f KB" % (OUT.relative_to(DEV.parent), small.width(), small.height(), OUT.stat().st_size / 1000))

    # --- Where the tyres are, in the trimmed full-size picture's units. The source's x
    # (along the car) becomes y, and its y (across it) becomes x, flipped
    fronts = [(b[0] + b[2]) / 2 for b in PILLS if (b[0] + b[2]) / 2 < width / 2]
    rears = [(b[0] + b[2]) / 2 for b in PILLS if (b[0] + b[2]) / 2 > width / 2]
    across = [(b[1] + b[3]) / 2 for b in PILLS]
    centre = height - 1 - (min(across) + max(across)) / 2 - left          # the tyres' centre line
    print("\nfor CarTopView.qml, in the picture's own units:")
    print("  designWidth  %d   designHeight %d" % (crop_width, crop_height))
    print("  centreX      %.1f" % centre)
    print("  frontAxleY   %.1f" % (sum(fronts) / len(fronts) - top))
    print("  rearAxleY    %.1f" % (sum(rears) / len(rears) - top))
    print("  tireOffset   %.1f   tireWidth %d   tireHeight %d" % ((max(across) - min(across)) / 2, PILL_WIDTH, PILL_LENGTH))


if __name__ == "__main__":
    main()
