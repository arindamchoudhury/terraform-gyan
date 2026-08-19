"""A complete Terraform `http` backend, in one file, with no dependencies.

The point of this lab is that the `http` backend is a *protocol*, not a product.
HashiCorp's reference page describes it in four sentences; this file is those
sentences as code, and it is enough for a real `terraform apply` to store state
against it. GitLab's Terraform state feature is this same contract implemented
inside a Rails application.

The protocol:

    GET     <address>   -> 200 with the state document, or 404 if there is none
    POST    <address>   -> store the body as the new state          (update_method)
    DELETE  <address>   -> purge the state
    LOCK    <address>   -> 200 if the lock was free, 423 if it was already held,
                           with the *holding* lock info in the body
    UNLOCK  <address>   -> release it

Terraform appends the lock ID as a query parameter (`?ID=...`) to state updates
while a lock is held, which is how the server can reject a write from a client
that does not hold it.

Run it:

    python state_server.py                 # locking enabled, port 8080
    python state_server.py --no-lock       # answers 405 to LOCK/UNLOCK
    python state_server.py --port 9000

Every request is logged as one line so you can watch the conversation Terraform
has with its backend, which is normally invisible.
"""

import argparse
import json
import pathlib
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

STATE_FILE = pathlib.Path(__file__).parent / "server-state.json"

_guard = threading.Lock()  # protects the two globals below
_lock_info = None  # the lock info document Terraform sent, or None


class Handler(BaseHTTPRequestHandler):
    server_version = "lab-http-backend/1.0"
    locking_enabled = True

    # -- helpers ---------------------------------------------------------

    def _body(self):
        length = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(length) if length else b""

    def _respond(self, code, payload=b"", content_type="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if payload:
            self.wfile.write(payload)

    def _query_lock_id(self):
        return (parse_qs(urlparse(self.path).query).get("ID") or [None])[0]

    # -- the protocol ----------------------------------------------------

    def do_GET(self):
        if not STATE_FILE.exists():
            # 404 is how Terraform learns "this backend is empty", which is what
            # makes the very first `apply` against a fresh address work.
            return self._respond(404)
        self._respond(200, STATE_FILE.read_bytes())

    def do_POST(self):
        body = self._body()
        with _guard:
            held = _lock_info
        if held is not None:
            # A write while a lock is held must carry that lock's ID. Terraform
            # supplies it as ?ID=... automatically.
            if self._query_lock_id() != held.get("ID"):
                return self._respond(
                    423, json.dumps(held).encode()
                )
        STATE_FILE.write_bytes(body)
        self._respond(200)

    def do_DELETE(self):
        STATE_FILE.unlink(missing_ok=True)
        self._respond(200)

    def do_LOCK(self):
        if not self.locking_enabled:
            return self._respond(405)
        incoming = json.loads(self._body() or b"{}")
        global _lock_info
        with _guard:
            if _lock_info is not None:
                # 423 Locked, with the *holder's* info in the body. Terraform
                # prints that document back to the user as the "Lock Info" block,
                # which is why the second run can name who holds it.
                return self._respond(423, json.dumps(_lock_info).encode())
            _lock_info = incoming
        self._respond(200, json.dumps(incoming).encode())

    def do_UNLOCK(self):
        if not self.locking_enabled:
            return self._respond(405)
        global _lock_info
        with _guard:
            _lock_info = None
        self._respond(200)

    # -- logging ---------------------------------------------------------

    def log_message(self, fmt, *args):
        print(f"  {self.command:<7} {self.path:<28} {args[1] if len(args) > 1 else ''}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument(
        "--no-lock",
        action="store_true",
        help="answer 405 to LOCK/UNLOCK, to show what an unlocked backend feels like",
    )
    args = ap.parse_args()

    Handler.locking_enabled = not args.no_lock
    print(f"state file : {STATE_FILE}")
    print(f"locking    : {'enabled' if Handler.locking_enabled else 'DISABLED'}")
    print(f"listening  : http://127.0.0.1:{args.port}/state/lab\n")
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
