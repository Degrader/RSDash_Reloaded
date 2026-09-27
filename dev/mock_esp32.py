"""Fake Nutron ESP32 for testing RSdash on a PC.

Serves the two endpoints the app uses, with the same JSON keys the real
RSapp 2.8.1 firmware sends:

    GET  /pids      live values (temps, tire pressures, RDU torque)
    GET  /settings  toggles, including cobbFriendly (OBD Not Alone)
    POST /settings  JSON body like {"cobbFriendly": 1}; merged into the state

Single-threaded like the real ESP32's HTTP server. Run it on its own for
manual testing (python dev/mock_esp32.py) or use it from harness.py.
"""

import json
import math
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

DEFAULT_PIDS = {
    "ptu": 62, "rdu": 58, "engine": 92, "lambda": 0.98,
    "flw": 3.0, "frw": 3.0, "rlw": 2.95, "rrw": 2.95,     # bar (about 43 psi)
    "rdutl": 71, "rdutr": 74,                             # RDU clutch temps, C
    "rdutql": 120, "rdutqr": 135,                         # RDU clutch torque, Nm
}

# Values the app doesn't read (units, wifi, product, protocol) are placeholders.
DEFAULT_SETTINGS = {
    "enableDriftMode": 0, "driftInAllModes": 0, "disableStartStop": 1,
    "enableLC": 0, "driveMode": 1, "units": 1, "version": "2.8.1",
    "esp": 0, "wifi": 1, "product": "focusrs", "protocol": "focusrs",
    "cobbFriendly": 0,
}


class MockEsp32:
    def __init__(self, port=0, pids=None, settings=None, animate=False):
        self.lock = threading.Lock()
        self.pids = dict(DEFAULT_PIDS, **(pids or {}))
        self.settings = dict(DEFAULT_SETTINGS, **(settings or {}))
        self.animate = animate        # drift temps gently, for interactive use
        self.online = True            # False: drop every connection unanswered
        self.post_status = 200        # e.g. 500 to simulate a rejected change
        self.latency = 0.0            # seconds to wait before each response
        self.posts = []               # bodies of every POST /settings, in order
        self.requests = []            # "GET /pids" etc., in order
        self.started = time.time()
        self._server = HTTPServer(("127.0.0.1", port), self._handler_class())
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)

    @property
    def url(self):
        return "http://127.0.0.1:%d/" % self._server.server_address[1]

    def start(self):
        self._thread.start()
        return self

    def stop(self):
        self._server.shutdown()
        self._server.server_close()

    def reset(self, pids=None, settings=None):
        with self.lock:
            self.pids = dict(DEFAULT_PIDS, **(pids or {}))
            self.settings = dict(DEFAULT_SETTINGS, **(settings or {}))
            self.online, self.post_status, self.latency = True, 200, 0.0
            self.posts, self.requests = [], []

    def _live_pids(self):
        uptime = time.time() - self.started
        pids = dict(self.pids, uptime=int(uptime), free_ram=123456)
        if self.animate:
            wobble = math.sin(uptime / 4)
            for key in ("ptu", "rdu", "engine", "rdutl", "rdutr"):
                pids[key] = round(pids[key] + 15 * wobble)
            pids["lambda"] = round(1 + 0.3 * math.sin(uptime), 2)
            pids["rdutql"] = max(0, round(400 + 400 * math.sin(uptime / 2)))
            pids["rdutqr"] = max(0, round(400 + 400 * math.cos(uptime / 2)))
        return pids

    def _handler_class(self):
        mock = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, fmt, *args):
                pass  # requests are recorded in mock.requests instead

            def _begin(self):
                with mock.lock:
                    mock.requests.append("%s %s" % (self.command, self.path))
                    online, latency = mock.online, mock.latency
                if latency:
                    time.sleep(latency)
                if not online:
                    self.close_connection = True
                return online

            def _send_json(self, status, body):
                data = json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def do_GET(self):
                if not self._begin():
                    return
                with mock.lock:
                    if self.path == "/pids":
                        body = mock._live_pids()
                    elif self.path == "/settings":
                        body = dict(mock.settings)
                    else:
                        body = None
                if body is None:
                    self._send_json(404, {"error": "not found"})
                else:
                    self._send_json(200, body)

            def do_POST(self):
                if not self._begin():
                    return
                length = int(self.headers.get("Content-Length") or 0)
                try:
                    body = json.loads(self.rfile.read(length) or b"{}")
                except ValueError:
                    self._send_json(400, {"error": "bad json"})
                    return
                with mock.lock:
                    mock.posts.append(body)
                    status = mock.post_status
                    if self.path == "/settings" and status == 200:
                        mock.settings.update(body)
                    settings = dict(mock.settings)
                self._send_json(status, settings)

        return Handler


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run a fake RSdash ESP32.")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--not-alone", action="store_true", help="start with cobbFriendly=1")
    parser.add_argument("--animate", action="store_true", help="drift the live values over time")
    args = parser.parse_args()

    esp = MockEsp32(args.port, settings={"cobbFriendly": int(args.not_alone)}, animate=args.animate).start()
    print("Fake ESP32 at %s  (Ctrl+C to stop)" % esp.url)
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        esp.stop()
