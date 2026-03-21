#!/usr/bin/env python3
"""sprint-status — git-status-style dashboard for ai-sprint-workflow projects.

Usage:
    sprint-status                        # CLI summary (snapshot)
    sprint-status -w                     # CLI watch mode (live, auto-refreshes)
    sprint-status --serve                # Web dashboard (live, http://127.0.0.1:8384)
    sprint-status --json                 # Machine-readable JSON output
    sprint-status /path/to/project       # Explicit project root

This is the thin entry point.  Data collection and CLI rendering live in
dashboard_render; the HTML template and HTTP server live in dashboard_web.
"""

import argparse
import json
import sys
import time
from pathlib import Path

from dashboard_render import collect_data, find_project_root, render_cli, C
from dashboard_web import find_watched_files, LiveServer


def main():
    parser = argparse.ArgumentParser(description="Sprint status dashboard for ai-sprint-workflow projects")
    parser.add_argument("project_dir", nargs="?", default=".", help="Project root directory")
    parser.add_argument("--serve", action="store_true", help="Start live dashboard server")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--no-color", action="store_true", help="Disable colors")
    parser.add_argument("-o", "--output", default=None, help="Output file path")
    parser.add_argument("-p", "--port", type=int, default=8384, help="Server port (default: 8384)")
    parser.add_argument("-w", "--watch", action="store_true", help="Watch mode: refresh CLI on file changes")

    args = parser.parse_args()
    if args.no_color or not sys.stdout.isatty():
        C.off()

    root = find_project_root(args.project_dir)
    if not root:
        print(f"Error: No TRACKING.md found in {args.project_dir} or parent directories.", file=sys.stderr)
        sys.exit(1)

    if args.serve:
        server = LiveServer(root, args.port)
        server.serve()
    elif args.json:
        data = collect_data(root)
        output = json.dumps(data, indent=2, default=str)
        if args.output:
            Path(args.output).write_text(output, encoding="utf-8")
            print(f"JSON written to {args.output}", file=sys.stderr)
        else:
            print(output)
    elif args.watch:
        print(f"{C.D}Watching {root} for changes (Ctrl+C to stop)...{C.R}\n")
        # Initial render
        data = collect_data(root)
        print(render_cli(data))
        # Watch loop — only monitor workflow-relevant files, not all *.md
        watched_files = find_watched_files(root)
        mtimes = {str(f): f.stat().st_mtime for f in watched_files if f.exists()}
        try:
            while True:
                time.sleep(1)
                new_watched = find_watched_files(root)
                changed = False
                new_mtimes = {}
                for f in new_watched:
                    if not f.exists():
                        continue
                    key = str(f)
                    mt = f.stat().st_mtime
                    new_mtimes[key] = mt
                    if key not in mtimes or mtimes[key] != mt:
                        changed = True
                if changed:
                    mtimes = new_mtimes
                    # Clear screen and re-render
                    print("\033[2J\033[H", end="")
                    data = collect_data(root)
                    print(render_cli(data))
                else:
                    mtimes = new_mtimes
        except KeyboardInterrupt:
            print(f"\n{C.D}Stopped.{C.R}")
    else:
        data = collect_data(root)
        print(render_cli(data))


if __name__ == "__main__":
    main()
