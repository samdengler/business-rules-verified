#!/usr/bin/env python3
"""Serve site/ on localhost, answering range requests.

  python3 scripts/serve_site.py [port]

Python's http.server sends whole files only, so a browser cannot seek in the
film on the History tab; its step buttons and seek bar need to.  GitHub Pages
answers range requests, and this server does too, for one range at a time.
"""

import functools
import http.server
import os
import re
import sys
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent / "site"


class Handler(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        self.remaining = None
        m = re.fullmatch(r"bytes=(\d*)-(\d*)", self.headers.get("Range", ""))
        path = self.translate_path(self.path)
        if not m or not os.path.isfile(path):
            return super().send_head()
        size = os.path.getsize(path)
        first, last = m.groups()
        if first:
            start, end = int(first), min(int(last) if last else size - 1, size - 1)
        else:
            start, end = max(0, size - int(last or 0)), size - 1
        if start > end:
            self.send_error(416, "Range Not Satisfiable")
            return None
        f = open(path, "rb")
        f.seek(start)
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(end - start + 1))
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        self.remaining = end - start + 1
        return f

    def copyfile(self, source, outputfile):
        n = self.remaining
        if n is None:
            return super().copyfile(source, outputfile)
        while n > 0:
            chunk = source.read(min(n, 64 * 1024))
            if not chunk:
                break
            outputfile.write(chunk)
            n -= len(chunk)

    def end_headers(self):
        if not self.headers.get("Range"):
            self.send_header("Accept-Ranges", "bytes")
        super().end_headers()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    handler = functools.partial(Handler, directory=str(SITE))
    with http.server.ThreadingHTTPServer(("localhost", port), handler) as server:
        server.serve_forever()
