import json
import os
import re
import sqlite3
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import deepseek


PLAYER_PATH = re.compile(r"/api/players/([a-f0-9]{32})/save")
DATABASE = Path(os.environ.get("CORRIDOR_DB", Path(__file__).parent / "data" / "players.sqlite3"))


def connect():
    return sqlite3.connect(DATABASE, timeout=5)


def initialize():
    DATABASE.parent.mkdir(parents=True, exist_ok=True)
    with closing(connect()) as db, db:
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("""
            CREATE TABLE IF NOT EXISTS saves (
                player TEXT PRIMARY KEY,
                rev INTEGER NOT NULL,
                state TEXT NOT NULL,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """)


def valid_int(value, minimum, maximum):
    return type(value) is int and minimum <= value <= maximum


def valid_save(payload):
    state = payload.get("state")
    if not isinstance(state, dict) or not valid_int(payload.get("rev"), 0, 2**53 - 1):
        return False
    evidence = state.get("evidence")
    return (
        valid_int(state.get("chapter"), 0, 4)
        and valid_int(state.get("laps"), 1, 2**31 - 1)
        and isinstance(evidence, list) and len(evidence) == 3
        and all(type(item) is bool for item in evidence)
        and type(state.get("solved")) is bool and type(state.get("cleared")) is bool
    )


def tactic_for(payload):
    lap = payload.get("lap")
    gates = payload.get("gates")
    sprint = payload.get("sprint_heard")
    if (
        not valid_int(lap, 1, 2**31 - 1) or not isinstance(gates, list) or len(gates) != 2
        or not all(valid_int(count, 0, 2**31 - 1) for count in gates)
        or not valid_int(sprint, 0, 1)
    ):
        return None

    gate = int(gates[1] >= gates[0])
    if max(gates) >= 2:
        strategy = "ambush"
    elif max(gates) == 1:
        strategy = "cutoff"
    elif sprint:
        strategy = "guard"
    else:
        strategy = "patrol"
    return {"lap": lap, "strategy": strategy, "gate": gate, "source": "rules"}


class API(BaseHTTPRequestHandler):
    def respond(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def payload(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 1 <= length <= 8192:
                return None
            data = json.loads(self.rfile.read(length))
        except (ValueError, UnicodeError):
            return None
        return data if isinstance(data, dict) else None

    def do_GET(self):
        if self.path == "/health":
            return self.respond(200, {"ok": True, "deepseek_configured": bool(os.environ.get("DEEPSEEK_API_KEY", "").strip())})
        match = PLAYER_PATH.fullmatch(self.path)
        if not match:
            return self.respond(404, {"error": "unknown_route"})
        player = match[1]
        with closing(connect()) as db:
            row = db.execute("SELECT rev, state FROM saves WHERE player = ?", (player,)).fetchone()
        if row is None:
            return self.respond(404, {"error": "save_not_found"})
        self.respond(200, {"player": player, "rev": row[0], "state": json.loads(row[1])})

    def do_PUT(self):
        match = PLAYER_PATH.fullmatch(self.path)
        if not match:
            return self.respond(404, {"error": "unknown_route"})
        payload = self.payload()
        if payload is None or not valid_save(payload):
            return self.respond(400, {"error": "invalid_save"})
        state = json.dumps(payload["state"], sort_keys=True, separators=(",", ":"))
        with closing(connect()) as db, db:
            db.execute("""
                INSERT INTO saves (player, rev, state) VALUES (?, ?, ?)
                ON CONFLICT(player) DO UPDATE SET
                    rev = excluded.rev, state = excluded.state, updated_at = CURRENT_TIMESTAMP
                WHERE excluded.rev > saves.rev
            """, (match[1], payload["rev"], state))
            revision, stored = db.execute("SELECT rev, state FROM saves WHERE player = ?", (match[1],)).fetchone()
        if revision != payload["rev"] or stored != state:
            return self.respond(409, {"error": "revision_conflict", "rev": revision})
        self.respond(200, {"rev": revision})

    def do_POST(self):
        if self.path != "/api/tactics":
            return self.respond(404, {"error": "unknown_route"})
        payload = self.payload()
        result = tactic_for(payload) if payload is not None else None
        if result is None:
            return self.respond(400, {"error": "invalid_observations"})
        self.respond(200, deepseek.choose(payload, result))

    def log_message(self, format, *args):
        # Player tokens are stored on the device and kept out of the access log.
        pass


if __name__ == "__main__":
    initialize()
    port = int(os.environ.get("CORRIDOR_PORT", "8765"))
    with ThreadingHTTPServer(("127.0.0.1", port), API) as server:
        print(f"Corridor backend at http://127.0.0.1:{port}", flush=True)
        server.serve_forever()
