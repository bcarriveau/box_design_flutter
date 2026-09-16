#!/usr/bin/env python3
"""Convert a DXF file into a box_design_flutter template JSON.

Produces the same JSON shape as assets/templates/*.json and tool/
gen_placeholder_templates.dart:

    {
      "id": "...",
      "name": "...",
      "category": "box" | "controller" | "controllerAddon" | "powerSupply" | "powerDistribution" | "receiver",
      "entities": [
        {"type": "line", "start": {"x":.., "y":..}, "end": {"x":.., "y":..}},
        {"type": "circle", "center": {"x":.., "y":..}, "radius": ..},
        {"type": "arc", "center": {...}, "radius": .., "startAngle": .., "endAngle": ..},
        {"type": "polyline", "closed": bool, "vertices": [{"x":.., "y":.., "bulge":..}, ...]}
      ]
    }

The app's own DXF parser (lib/dxf/dxf_parser.dart) only understands LINE,
CIRCLE, ARC and LWPOLYLINE (with bulge) entities in millimeters. This script
uses ezdxf to read any DXF the CAD tool produced (including blocks/inserts,
old-style POLYLINE, and curves), and flattens everything else down to that
same set of four primitive types so the output matches what the app expects.

Usage:
    pip install ezdxf
    python tool/dxf_to_json.py board.dxf --id my_board --name "My Board" \
        --category controller -o assets/templates/my_board.json

Run with --help for all options.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

try:
    import ezdxf
    from ezdxf.entities import DXFGraphic
except ImportError:
    print("This script requires ezdxf: pip install ezdxf", file=sys.stderr)
    raise

# Must match TemplateCategory in lib/models/controller_template.dart.
VALID_CATEGORIES = {
    "box",
    "controller",
    "controllerAddon",
    "powerSupply",
    "powerDistribution",
    "receiver",
}

# DXF entity types we flatten (via ezdxf) instead of translating directly.
FLATTEN_TYPES = {"POLYLINE", "SPLINE", "ELLIPSE", "LWPOLYLINE_WITH_ARCS"}
DIRECT_TYPES = {"LINE", "CIRCLE", "ARC", "LWPOLYLINE"}


def line_entity(e) -> dict:
    start = e.dxf.start
    end = e.dxf.end
    return {
        "type": "line",
        "start": {"x": start.x, "y": start.y},
        "end": {"x": end.x, "y": end.y},
    }


def circle_entity(e) -> dict:
    c = e.dxf.center
    return {
        "type": "circle",
        "center": {"x": c.x, "y": c.y},
        "radius": e.dxf.radius,
    }


def arc_entity(e) -> dict:
    c = e.dxf.center
    return {
        "type": "arc",
        "center": {"x": c.x, "y": c.y},
        "radius": e.dxf.radius,
        # DXF ARC angles are already degrees CCW from +X, same convention the
        # app's DxfArc uses -- no conversion needed.
        "startAngle": e.dxf.start_angle,
        "endAngle": e.dxf.end_angle,
    }


def lwpolyline_entity(e) -> dict:
    vertices = []
    for x, y, _start_w, _end_w, bulge in e.get_points("xyseb"):
        vertices.append({"x": x, "y": y, "bulge": bulge or 0})
    closed = bool(e.closed)
    return {"type": "polyline", "closed": closed, "vertices": vertices}


def flattened_polyline_entity(e, sagitta: float) -> dict | None:
    """Approximate an entity we don't natively support (old-style POLYLINE,
    SPLINE, ELLIPSE, ...) as a straight-segment polyline by sampling its
    flattened point list. Curvature is lost -- bulge is always 0 -- so a
    very tight radius may look faceted; lower --flatten-sagitta if so.
    """
    try:
        points = list(e.flattening(sagitta))
    except AttributeError:
        return None
    if len(points) < 2:
        return None
    vertices = [{"x": p.x, "y": p.y, "bulge": 0} for p in points]
    closed = getattr(e, "closed", False) or getattr(e.dxf, "closed", False)
    if not closed and len(points) > 2 and points[0].distance(points[-1]) < 1e-6:
        closed = True
        vertices = vertices[:-1]
    return {"type": "polyline", "closed": bool(closed), "vertices": vertices}


def convert_entity(e, sagitta: float, warnings: list[str]) -> list[dict]:
    """Returns zero or more JSON entity dicts for one DXF entity."""
    dxftype = e.dxftype()

    if dxftype == "INSERT":
        out = []
        for virtual in e.virtual_entities():
            out.extend(convert_entity(virtual, sagitta, warnings))
        return out

    if dxftype == "LINE":
        return [line_entity(e)]
    if dxftype == "CIRCLE":
        return [circle_entity(e)]
    if dxftype == "ARC":
        return [arc_entity(e)]
    if dxftype == "LWPOLYLINE":
        return [lwpolyline_entity(e)]

    # Everything else: try to flatten to a straight-segment polyline.
    flattened = flattened_polyline_entity(e, sagitta)
    if flattened is not None:
        warnings.append(
            f"{dxftype} flattened to a straight-segment polyline "
            f"(curvature approximated, not exact)"
        )
        return [flattened]

    warnings.append(f"skipped unsupported entity type: {dxftype}")
    return []


def all_points(entities: list[dict]):
    for e in entities:
        if e["type"] == "line":
            yield e["start"]["x"], e["start"]["y"]
            yield e["end"]["x"], e["end"]["y"]
        elif e["type"] == "circle":
            cx, cy, r = e["center"]["x"], e["center"]["y"], e["radius"]
            yield cx - r, cy - r
            yield cx + r, cy + r
        elif e["type"] == "arc":
            # Coarse bound via the full circle -- good enough for normalizing
            # translation, not used for anything precision-critical.
            cx, cy, r = e["center"]["x"], e["center"]["y"], e["radius"]
            yield cx - r, cy - r
            yield cx + r, cy + r
        elif e["type"] == "polyline":
            for v in e["vertices"]:
                yield v["x"], v["y"]


def normalize(entities: list[dict]) -> list[dict]:
    """Translate geometry so the bounding box's min corner sits at ~(0, 0),
    matching the convention every other bundled template follows.
    """
    pts = list(all_points(entities))
    if not pts:
        return entities
    min_x = min(p[0] for p in pts)
    min_y = min(p[1] for p in pts)
    if abs(min_x) < 1e-9 and abs(min_y) < 1e-9:
        return entities

    def shift_point(p):
        return {"x": round(p["x"] - min_x, 6), "y": round(p["y"] - min_y, 6)}

    shifted = []
    for e in entities:
        e = dict(e)
        if e["type"] == "line":
            e["start"] = shift_point(e["start"])
            e["end"] = shift_point(e["end"])
        elif e["type"] in ("circle", "arc"):
            e["center"] = shift_point(e["center"])
        elif e["type"] == "polyline":
            e["vertices"] = [
                {**shift_point(v), "bulge": v["bulge"]} for v in e["vertices"]
            ]
        shifted.append(e)
    return shifted


def scale_entities(entities: list[dict], factor: float) -> list[dict]:
    if factor == 1.0:
        return entities

    def scale_point(p):
        return {"x": p["x"] * factor, "y": p["y"] * factor}

    scaled = []
    for e in entities:
        e = dict(e)
        if e["type"] == "line":
            e["start"] = scale_point(e["start"])
            e["end"] = scale_point(e["end"])
        elif e["type"] in ("circle", "arc"):
            e["center"] = scale_point(e["center"])
            e["radius"] = e["radius"] * factor
        elif e["type"] == "polyline":
            e["vertices"] = [
                {**scale_point(v), "bulge": v["bulge"]} for v in e["vertices"]
            ]
        scaled.append(e)
    return scaled


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dxf_path", type=Path, help="Input DXF file")
    parser.add_argument("--id", required=True, help="Template id (e.g. my_board_controller)")
    parser.add_argument("--name", required=True, help="Display name shown in the palette")
    parser.add_argument("--category", required=True, choices=sorted(VALID_CATEGORIES))
    parser.add_argument(
        "-o", "--output", type=Path, default=None,
        help="Output JSON path (default: assets/templates/<id>.json next to this script's repo root)",
    )
    parser.add_argument(
        "--scale", type=float, default=1.0,
        help="Multiply every coordinate/radius by this factor, e.g. 25.4 to convert inches to mm (default: 1.0, assumes the DXF is already in mm)",
    )
    parser.add_argument(
        "--no-normalize", action="store_true",
        help="Don't translate geometry so its bounding box starts at (0, 0)",
    )
    parser.add_argument(
        "--flatten-sagitta", type=float, default=0.05,
        help="Max deviation (mm, post-scale) allowed when flattening curves the app can't represent natively, e.g. splines/ellipses/old-style POLYLINE (default: 0.05)",
    )
    args = parser.parse_args()

    if not args.dxf_path.exists():
        print(f"No such file: {args.dxf_path}", file=sys.stderr)
        return 1

    doc = ezdxf.readfile(args.dxf_path)
    msp = doc.modelspace()

    warnings: list[str] = []
    entities: list[dict] = []
    for e in msp:
        entities.extend(convert_entity(e, args.flatten_sagitta, warnings))

    if not entities:
        print("No convertible entities found in the DXF's modelspace.", file=sys.stderr)
        return 1

    entities = scale_entities(entities, args.scale)
    if not args.no_normalize:
        entities = normalize(entities)

    template = {
        "id": args.id,
        "name": args.name,
        "category": args.category,
        "entities": entities,
    }

    output_path = args.output
    if output_path is None:
        output_path = Path("assets/templates") / f"{args.id}.json"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(template, indent=2), encoding="utf-8")

    print(f"Wrote {output_path} ({len(entities)} entities)")
    for w in warnings:
        print(f"  warning: {w}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
