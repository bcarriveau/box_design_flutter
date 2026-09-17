#!/usr/bin/env python3
"""Extract a board outline + mounting holes from a vendor PDF/SVG assembly
drawing (assumed printed/exported at 1:1 scale) and emit a box_design_flutter
template JSON -- the same shape as assets/templates/*.json:

    {
      "id": "...",
      "name": "...",
      "category": "controller" | "controllerAddon" | "receiver" |
                   "powerSupply" | "powerDistribution" | "box",
      "entities": [
        {"type": "polyline", "closed": true, "vertices": [{"x":.., "y":.., "bulge":0.0}, ...]},
        {"type": "circle", "center": {"x":.., "y":..}, "radius": ..},
        ...
      ]
    }

How it works: PyMuPDF's page.get_drawings() returns every vector path on the
page in points (1/72in), in a top-left-origin/Y-down space. This script:

  1. Finds the board OUTLINE as the four longest straight line segments on
     the page that close into a rectangle (the Edge.Cuts/board-outline lines
     in a KiCad-style assembly plot are typically far longer than any trace,
     silkscreen glyph, or component outline). If they don't close cleanly,
     it prints the top candidate lines instead of guessing.
  2. Finds mounting HOLES as circular paths (four Bezier curves each, near-
     square bounding box) filled solid, within [--min-hole-mm, --max-hole-mm]
     diameter, whose center sits within [--edge-inset] mm of at least one
     outline edge -- distinguishing them from same-sized pads/vias that sit
     in the board interior. Near-duplicate concentric circles (a drawing
     tool's stroke rendered as two filled shapes) are collapsed to one,
     keeping the larger diameter.
  3. Converts everything into the app's own coordinate convention: origin at
     the outline's bottom-left corner, Y-up, in millimeters.

This is a measurement aid, not a certified digitizer -- always sanity-check
the printed report (and the rendered board image) against the source drawing
before trusting the output for fabrication.

Usage:
    pip install -r tool/requirements.txt
    python tool/pcb_drawing_to_json.py <path-or-url-to-pdf-or-svg> \
        --id my_board --name "My Board" --category controller \
        -o assets/templates/my_board.json

Run with no --id/--name/-o to just print the measurement report (dry run).
Run with --help for every option.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import tempfile
import urllib.request
from pathlib import Path

try:
    import fitz  # PyMuPDF
except ImportError:
    print("This script needs PyMuPDF: pip install pymupdf", file=sys.stderr)
    raise

PT_TO_MM = 25.4 / 72.0
VALID_CATEGORIES = ("controller", "controllerAddon", "receiver", "powerSupply", "powerDistribution", "box")


def _fetch(path_or_url: str) -> Path:
    if not path_or_url.startswith(("http://", "https://")):
        return Path(path_or_url)
    suffix = Path(path_or_url.split("?")[0]).suffix or ".pdf"
    tmp = Path(tempfile.gettempdir()) / f"pcb_drawing_download{suffix}"
    with urllib.request.urlopen(path_or_url) as resp:
        tmp.write_bytes(resp.read())
    return tmp


def _line_length(p1, p2) -> float:
    return math.hypot(p2.x - p1.x, p2.y - p1.y)


def find_outline_rect(drawings, page_rect, max_page_fraction: float = 0.9):
    """Fallback for a drawing that plots the outline as a single rectangle
    primitive instead of four line segments (seen from SVG exports of the
    same boards whose PDF exports use lines) -- the largest 're' item that
    isn't essentially the full page (a drafting border, as seen in some of
    this vendor's PDFs, would otherwise win by being the biggest rect on
    the page). Returns None if nothing plausible is found.
    """
    best = None
    for d in drawings:
        for item in d["items"]:
            if item[0] != "re":
                continue
            r = item[1]
            if r.width > page_rect.width * max_page_fraction or r.height > page_rect.height * max_page_fraction:
                continue
            if best is None or r.width * r.height > (best[2] - best[0]) * (best[3] - best[1]):
                best = (r.x0, r.y0, r.x1, r.y1)
    return best


def find_outline(drawings, min_length_mm: float = 40.0):
    """Returns (x0, y0, x1, y1) in points for the board outline.

    Finds the two longest horizontal lines (giving the outline's y0/y1 and,
    from their own span, a candidate x0/x1) and the two longest vertical
    lines (giving x0/x1 and a candidate y0/y1), then cross-checks each pair
    against the other axis's span -- a lone decoy line (a dimension/leader
    line, or a drafting border further out than the real edge) can tie or
    beat a true edge on raw length alone, but it won't also line up with
    where the *other* axis's lines say the edge should be, so it loses the
    tie-break to whichever candidate both axes agree on.

    Returns None (instead of raising) if it can't find two distinct edges
    per axis, so the caller can fall back to [find_outline_rect].
    """
    horiz, vert = [], []
    for d in drawings:
        for item in d["items"]:
            if item[0] != "l":
                continue
            p1, p2 = item[1], item[2]
            length = _line_length(p1, p2)
            if length * PT_TO_MM < min_length_mm:
                continue
            if abs(p1.y - p2.y) < 0.01:
                horiz.append((length, p1.y, min(p1.x, p2.x), max(p1.x, p2.x)))
            elif abs(p1.x - p2.x) < 0.01:
                vert.append((length, p1.x, min(p1.y, p2.y), max(p1.y, p2.y)))

    # Sort by length only -- reverse=True on the whole tuple would break
    # length ties by comparing position next, silently reordering same-
    # length candidates (e.g. a board edge tying with a dimension line).
    horiz.sort(key=lambda t: t[0], reverse=True)
    vert.sort(key=lambda t: t[0], reverse=True)

    def two_longest_distinct_positions(lines):
        seen = []
        for length, pos, lo, hi in lines:
            if all(abs(pos - p) > 0.5 for p in seen):
                seen.append(pos)
                if len(seen) == 2:
                    return sorted(seen)
        return None

    def longest_line_near(lines, target_pos, tol=3.0):
        best = None
        for length, pos, lo, hi in lines:
            if abs(pos - target_pos) < tol and (best is None or length > best[0]):
                best = (length, pos, lo, hi)
        return best

    h_ys = two_longest_distinct_positions(horiz)
    v_xs = two_longest_distinct_positions(vert)
    if h_ys is None or v_xs is None:
        return None

    y0, y1 = h_ys
    # x-span implied by the two horizontal edges themselves.
    h_x_lo = min(longest_line_near(horiz, y0)[2], longest_line_near(horiz, y1)[2])
    h_x_hi = max(longest_line_near(horiz, y0)[3], longest_line_near(horiz, y1)[3])

    # Prefer vertical lines that actually land at that x-span over whatever
    # merely tied/won on raw length -- see the docstring above.
    x0 = (longest_line_near(vert, h_x_lo) or (None, min(v_xs)))[1]
    x1 = (longest_line_near(vert, h_x_hi) or (None, max(v_xs)))[1]

    tol = 2.0  # pt
    if abs(h_x_lo - x0) > tol or abs(h_x_hi - x1) > tol:
        print(
            f"Warning: outline edges don't close cleanly (horizontal span {h_x_lo:.2f}-{h_x_hi:.2f}pt "
            f"vs closest vertical lines at {x0:.2f}/{x1:.2f}pt) -- double check the result.",
            file=sys.stderr,
        )
    return x0, y0, x1, y1


def find_circles(drawings):
    """Every near-circular filled path: (center_x, center_y, diameter_pt, fill)."""
    circles = []
    for d in drawings:
        items = d["items"]
        curves = [it for it in items if it[0] == "c"]
        if len(curves) < 4 or len(curves) != len(items):
            continue
        r = d["rect"]
        if abs(r.width - r.height) > 0.3 or r.width <= 0:
            continue
        circles.append((r.x0 + r.width / 2, r.y0 + r.height / 2, r.width, d.get("fill")))
    return circles


def find_mounting_holes(circles, outline, min_dia_mm, max_dia_mm, edge_inset_mm):
    """A genuine drilled mounting hole is usually drawn with a white-filled
    (1, 1, 1) circle at its center (the "knockout" showing the actual round
    opening), companioned by some other shape (a solid black annulus, or an
    unfilled outer ring) representing a pad/keepout around it. A same-sized
    courtyard/pad with no drill (e.g. a multi-pin connector footprint) never
    gets that white knockout, which is what distinguishes a real hole from
    same-diameter, similarly edge-close decoys. So: cluster circles by
    center, and prefer a cluster with a white-filled circle in the target
    diameter range, reporting *that* white circle's own diameter.

    Some drawings skip the white knockout entirely and draw a hole as a
    single plain black-filled circle instead -- but still only ever draw a
    non-hole pad/courtyard as *multiple* concentric circles at one center
    (e.g. a ring plus its own outline). So as a fallback (only used when the
    whole drawing has no white knockouts at all, since otherwise this would
    also catch every solid single-ring glyph/pad elsewhere), a cluster with
    exactly one black-filled circle in range also counts.
    """
    x0, y0, x1, y1 = outline

    def dist_to_nearest_edge(cx, cy):
        return min(abs(cx - x0), abs(cx - x1), abs(cy - y0), abs(cy - y1))

    # Cluster every circle (regardless of fill) by center proximity.
    clusters: list[dict] = []
    for cx, cy, dia_pt, fill in circles:
        for c in clusters:
            if math.hypot(cx - c["cx"], cy - c["cy"]) * PT_TO_MM < 0.5:
                c["members"].append((dia_pt, fill))
                break
        else:
            clusters.append({"cx": cx, "cy": cy, "members": [(dia_pt, fill)]})

    has_any_white_knockout = any(
        fill == (1.0, 1.0, 1.0) for c in clusters for _, fill in c["members"]
    )

    holes = []
    for c in clusters:
        if dist_to_nearest_edge(c["cx"], c["cy"]) * PT_TO_MM > edge_inset_mm:
            continue
        white = [dia for dia, fill in c["members"] if fill == (1.0, 1.0, 1.0)]
        if white:
            dia_pt = max(white)
        elif not has_any_white_knockout:
            black = [dia for dia, fill in c["members"] if fill == (0.0, 0.0, 0.0)]
            if len(black) != 1:
                continue
            dia_pt = black[0]
        else:
            continue
        if not (min_dia_mm <= dia_pt * PT_TO_MM <= max_dia_mm):
            continue
        holes.append((c["cx"], c["cy"], dia_pt))
    return holes


def to_app_space(cx, cy, outline):
    """PyMuPDF's drawing space is top-left-origin/Y-down; the app's mm-space
    is bottom-left-origin/Y-up (matching DXF convention)."""
    x0, y0, x1, y1 = outline
    return (cx - x0) * PT_TO_MM, (y1 - cy) * PT_TO_MM


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", help="Path or URL to a PDF/SVG assembly drawing")
    parser.add_argument("--page", type=int, default=0, help="Page index for multi-page PDFs (default: 0)")
    parser.add_argument("--min-hole-mm", type=float, default=2.8, help="Smallest hole diameter to consider a mounting hole (default: 2.8)")
    parser.add_argument("--max-hole-mm", type=float, default=3.4, help="Largest hole diameter to consider a mounting hole (default: 3.4 -- tuned for this vendor's common M3/3.2mm holes; widen it if a board uses bigger fasteners, but expect more false positives from same-sized connector pads)")
    parser.add_argument("--edge-inset-mm", type=float, default=6.0, help="Max distance from an outline edge to count as a mounting hole (default: 6)")
    parser.add_argument("--min-outline-line-mm", type=float, default=40.0, help="Ignore lines shorter than this when hunting for the outline (default: 40)")
    parser.add_argument("--id", dest="id_", help="Template id -- also triggers writing the JSON")
    parser.add_argument("--name", help="Display name shown in the palette")
    parser.add_argument("--category", choices=VALID_CATEGORIES, help="Template category")
    parser.add_argument("-o", "--output", type=Path, help="Output JSON path (required with --id)")
    args = parser.parse_args()

    local_path = _fetch(args.source)
    doc = fitz.open(local_path)
    page = doc[args.page]
    drawings = page.get_drawings()

    outline = find_outline(drawings, args.min_outline_line_mm)
    if outline is None:
        outline = find_outline_rect(drawings, page.rect)
    if outline is None:
        print("Could not find an outline (no closing 4-line rectangle, and no plausible 're' primitive).", file=sys.stderr)
        return 1
    x0, y0, x1, y1 = outline
    width_mm = (x1 - x0) * PT_TO_MM
    height_mm = (y1 - y0) * PT_TO_MM
    print(f"Outline: {width_mm:.2f} x {height_mm:.2f} mm (assuming the drawing is 1:1)")

    circles = find_circles(drawings)
    holes = find_mounting_holes(circles, outline, args.min_hole_mm, args.max_hole_mm, args.edge_inset_mm)
    holes_app = sorted(
        (*to_app_space(cx, cy, outline), dia_pt * PT_TO_MM) for cx, cy, dia_pt in holes
    )
    print(f"\n{len(holes_app)} mounting hole(s) found (x, y from bottom-left, diameter):")
    for x, y, dia in holes_app:
        print(f"  ({x:7.2f}, {y:7.2f}) mm   dia {dia:.2f} mm")

    if args.id_ is None:
        return 0
    if not (args.name and args.category and args.output):
        print("\n--id also needs --name, --category, and -o/--output to write a template.", file=sys.stderr)
        return 1

    entities = [
        {
            "type": "polyline",
            "closed": True,
            "vertices": [
                {"x": 0.0, "y": 0.0, "bulge": 0.0},
                {"x": round(width_mm, 2), "y": 0.0, "bulge": 0.0},
                {"x": round(width_mm, 2), "y": round(height_mm, 2), "bulge": 0.0},
                {"x": 0.0, "y": round(height_mm, 2), "bulge": 0.0},
            ],
        }
    ]
    for x, y, dia in holes_app:
        entities.append({"type": "circle", "center": {"x": round(x, 2), "y": round(y, 2)}, "radius": round(dia / 2, 2)})

    template = {"id": args.id_, "name": args.name, "category": args.category, "entities": entities}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(template, indent=2) + "\n", encoding="utf-8")
    print(f"\nWrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
