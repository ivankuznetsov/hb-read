#!/usr/bin/env python3
import base64
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from socketserver import TCPServer
from urllib.parse import parse_qs, urlparse


EXPECTED_AUTH = "Basic " + base64.b64encode(b"test-token:").decode("ascii")


class MockServer(ThreadingHTTPServer):
    def server_bind(self):
        TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, _format, *_args):
        return

    def send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.headers.get("Authorization") != EXPECTED_AUTH:
            self.send_json(401, {"error": "unauthorized", "api_key": "leaked-api-key"})
            return

        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)

        if parsed.path == "/v2/projects":
            if query.get("account_id") not in (None, ["7"]):
                self.send_json(400, {"error": "bad account"})
                return
            self.send_json(
                200,
                {
                    "results": [
                        {
                            "id": 1,
                            "name": "Demo",
                            "token": "project-token",
                            "nested": {"api_key": "nested-key", "cookie": "session"},
                        }
                    ],
                    "links": {},
                },
            )
            return

        if parsed.path == "/v2/projects/1/faults":
            expected = {
                "q": ["Timeout"],
                "order": ["frequent"],
                "limit": ["3"],
                "page": ["2"],
                "occurred_after": ["1700000000"],
            }
            if any(query.get(key) != value for key, value in expected.items()):
                self.send_json(400, {"error": "bad query", "query": query})
                return
            self.send_json(
                200,
                {
                    "results": [{"id": 2, "klass": "TimeoutError", "secret": "hidden"}],
                    "links": {},
                },
            )
            return

        if parsed.path == "/v2/projects/1/faults/2":
            self.send_json(200, {"id": 2, "klass": "TimeoutError", "password": "hidden"})
            return

        if parsed.path == "/v2/projects/1/faults/2/notices":
            if query.get("limit") != ["2"]:
                self.send_json(400, {"error": "bad limit"})
                return
            self.send_json(
                200,
                {
                    "results": [
                        {"id": "n1", "context": {"authorization": "Bearer secret"}},
                        {"id": "n2"},
                    ],
                    "links": {},
                },
            )
            return

        self.send_json(404, {"error": "not found", "token": "error-token"})


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: mock_server.py PORT_FILE")

    server = MockServer(("127.0.0.1", 0), Handler)
    Path(sys.argv[1]).write_text(f"{server.server_port}\n", encoding="utf-8")
    server.serve_forever()


if __name__ == "__main__":
    main()
