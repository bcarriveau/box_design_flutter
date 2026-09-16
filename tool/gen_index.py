#!/usr/bin/env python3
"""Regenerate assets/templates/index.json from the template JSON files
actually present in that folder, sorted by each template's display name.

Usage:
    python tool/gen_index.py [templates_dir]

templates_dir defaults to assets/templates next to this script's repo root.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

DEFAULT_TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "assets" / "templates"


def main() -> int:
    templates_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_TEMPLATES_DIR
    if not templates_dir.is_dir():
        print(f"No such directory: {templates_dir}", file=sys.stderr)
        return 1

    entries = []
    for path in sorted(templates_dir.glob("*.json")):
        if path.name == "index.json":
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            print(f"skipping {path.name}: invalid JSON ({exc})", file=sys.stderr)
            continue

        template_id = data.get("id")
        name = data.get("name")
        if not template_id or not name:
            print(f"skipping {path.name}: missing 'id' or 'name'", file=sys.stderr)
            continue

        entries.append((name, {"id": template_id, "file": path.name}))

    entries.sort(key=lambda e: e[0].casefold())

    ids = [e["id"] for _, e in entries]
    duplicates = {i for i in ids if ids.count(i) > 1}
    if duplicates:
        print(f"warning: duplicate template ids: {sorted(duplicates)}", file=sys.stderr)

    index_path = templates_dir / "index.json"
    index_path.write_text(
        json.dumps([e for _, e in entries], indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wrote {index_path} ({len(entries)} entries)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
