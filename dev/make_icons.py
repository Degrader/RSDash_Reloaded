"""Converts the button icons in docs/icons/ into SyncMyMod/app/Components/Icons.js.

    python dev/make_icons.py

The icons are traced SVGs made only of straight lines: each <path> uses
M/L/H/V/Z (absolute or relative). The Sync 3's QtQuick canvas has no SVG
support to rely on, so each path becomes a list of polygons that the app
draws with moveTo/lineTo and fills with fillRule = Qt.OddEvenFill
(SvgIcon.qml). An icon can have several paths (e.g. a gauge plus the letters
"L" and "C"); each is filled on its own.

A path can use the even-odd rule (inner outlines become holes) or the SVG
default, non-zero. The app always fills with even-odd, which only differs
from non-zero where a path's outlines overlap, so a non-zero path must be a
single outline; this stops with an error otherwise.

Along the way this:
  - drops traced points that don't change the shape (Ramer-Douglas-Peucker,
    within 0.15% of the icon's size, far below a pixel on the Sync 3), and
  - crops each icon to its visible shape and scales it to a 0..1 box,
    centred, so every icon lines up the same way whatever its SVG padding.

Re-run this after changing an icon in docs/icons/.
"""

import math
import re
import sys
from pathlib import Path

DEV = Path(__file__).resolve().parent
ICONS = DEV.parent / "docs" / "icons"
OUT = DEV.parent / "SyncMyMod" / "app" / "Components" / "Icons.js"

# Name used in the app -> SVG file
SOURCES = {
    "launchControl": "main_page/launch_control_lc.svg",
    "espSport": "main_page/esp_sport_1.svg",
    "autoStartStopOff": "main_page/auto_start_stop_off.svg",
    "driftStick": "main_page/drift_stick_1.svg",
    "modeNormal": "drive_mode_icons/drive_mode_normal.svg",
    "modeSport": "drive_mode_icons/drive_mode_sport.svg",
    "modeTrack": "drive_mode_icons/drive_mode_track.svg",
    "modeDrift": "drive_mode_icons/drive_mode_drift.svg",
    "modeCustom": "drive_mode_icons/drive_mode_custom.svg",
}

TOLERANCE = 0.0015  # of the icon's size


def parse_path(name, d):
    """Polygons of one SVG path's data, as lists of (x, y)."""
    polygons, current = [], None
    x = y = 0.0
    for command, args in re.findall(r"([A-Za-z])([^A-Za-z]*)", d):
        numbers = [float(n) for n in re.findall(r"-?\d*\.?\d+(?:[eE][-+]?\d+)?", args)]
        relative = command.islower()
        kind = command.upper()
        if kind == "M":
            x, y = (x + numbers[0], y + numbers[1]) if relative else (numbers[0], numbers[1])
            current = [(x, y)]
            polygons.append(current)
            pairs = numbers[2:]  # extra pairs after M are line-tos
            for px, py in zip(pairs[0::2], pairs[1::2]):
                x, y = (x + px, y + py) if relative else (px, py)
                current.append((x, y))
        elif kind == "L":
            for px, py in zip(numbers[0::2], numbers[1::2]):
                x, y = (x + px, y + py) if relative else (px, py)
                current.append((x, y))
        elif kind == "H":
            for px in numbers:
                x = x + px if relative else px
                current.append((x, y))
        elif kind == "V":
            for py in numbers:
                y = y + py if relative else py
                current.append((x, y))
        elif kind == "Z":
            if current:
                x, y = current[0]
            current = None
        else:
            raise SystemExit("%s: unsupported path command %r (only M, L, H, V, Z)" % (name, command))
    return [p for p in polygons if len(p) >= 3]


def read_shapes(path):
    """The icon's paths, each a list of polygons."""
    svg = path.read_text(encoding="utf-8")
    if re.search(r"transform=", svg):
        raise SystemExit("%s: transforms aren't supported" % path.name)
    shapes = []
    for tag in re.findall(r"<path\b[^>]*>", svg):
        d = re.search(r'\bd="([^"]+)"', tag)
        if not d:
            continue
        polygons = parse_path(path.name, d.group(1))
        even_odd = 'fill-rule="evenodd"' in tag
        if not even_odd and len(polygons) > 1:
            raise SystemExit("%s: a non-zero path with %d outlines would fill differently; make it even-odd"
                             % (path.name, len(polygons)))
        if polygons:
            shapes.append(polygons)
    if not shapes:
        raise SystemExit("%s: no paths" % path.name)
    return shapes


def simplify(points, tolerance):
    """Ramer-Douglas-Peucker on an open polyline."""
    if len(points) < 3:
        return points
    (x1, y1), (x2, y2) = points[0], points[-1]
    length = math.hypot(x2 - x1, y2 - y1)
    worst, index = 0.0, 0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        if length == 0:
            d = math.hypot(px - x1, py - y1)
        else:
            d = abs((x2 - x1) * (y1 - py) - (x1 - px) * (y2 - y1)) / length
        if d > worst:
            worst, index = d, i
    if worst <= tolerance:
        return [points[0], points[-1]]
    return simplify(points[:index + 1], tolerance)[:-1] + simplify(points[index:], tolerance)


def simplify_ring(ring, tolerance):
    # Split the closed ring at its point farthest from the first, simplify
    # both halves, and join them again
    far = max(range(len(ring)), key=lambda i: math.hypot(ring[i][0] - ring[0][0], ring[i][1] - ring[0][1]))
    first = simplify(ring[:far + 1], tolerance)
    second = simplify(ring[far:] + [ring[0]], tolerance)
    return first[:-1] + second[:-1]


def convert(name, path):
    shapes = read_shapes(path)
    xs = [x for s in shapes for p in s for x, _ in p]
    ys = [y for s in shapes for p in s for _, y in p]
    left, top, right, bottom = min(xs), min(ys), max(xs), max(ys)
    size = max(right - left, bottom - top)
    # Centre the icon in a size x size box, then scale that to 0..1
    ox = left - (size - (right - left)) / 2
    oy = top - (size - (bottom - top)) / 2
    before = sum(len(p) for s in shapes for p in s)
    out = []
    for polygons in shapes:
        shape = []
        for polygon in polygons:
            ring = simplify_ring(polygon, TOLERANCE * size)
            if len(ring) >= 3:
                shape.append([round(v, 4) for x, y in ring for v in ((x - ox) / size, (y - oy) / size)])
        if shape:
            out.append(shape)
    after = sum(len(p) // 2 for s in out for p in s)
    print("  %-17s %-40s %5d -> %4d points, %d path(s), %d polygon(s)"
          % (name, path.relative_to(ICONS), before, after, len(out), sum(len(s) for s in out)))
    return out


def main():
    lines = [
        "// Generated by dev/make_icons.py from the SVGs in docs/icons/ - don't edit by hand.",
        "//",
        "// Each icon is a list of shapes (one per SVG path), each shape a list of",
        "// polygons, each polygon a flat [x0, y0, x1, y1, ...] list in a 0..1 box with",
        "// the icon centred in it. SvgIcon.qml fills each shape on its own with the",
        "// even-odd rule, so outlines inside others become holes.",
        ".pragma library",
        "",
        "var shapes = {",
    ]
    entries = []
    for name, relative in SOURCES.items():
        shapes = convert(name, ICONS / relative)
        body = ",\n".join(
            "        [\n" + ",\n".join("            [" + ", ".join("%g" % v for v in p) + "]" for p in shape) + "\n        ]"
            for shape in shapes)
        entries.append("    %s: [\n%s\n    ]" % (name, body))
    lines.append(",\n".join(entries))
    lines.append("};")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print("wrote %s (%.0f KB)" % (OUT.relative_to(DEV.parent), OUT.stat().st_size / 1024))


if __name__ == "__main__":
    sys.exit(main())
