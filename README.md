# Box Design (Flutter)

A Flutter (Web + Windows/Linux/macOS) rewrite of [box_design](https://github.com/computergeek1507/box_design), a tool for laying out controller enclosures: pick a box, drag controller boards / power supplies onto it, add screw holes and zip-tie slots, then export the result as DXF (for CNC/laser cutting) or PDF (1:1 scale reference/print).

**Try it live: [computergeek1507.github.io/box_design_flutter](https://computergeek1507.github.io/box_design_flutter/)**

## Features

- **Box templates**: pick an enclosure from the palette; the canvas resizes to fit it.
- **Controller / power-supply templates**: drag onto the box, move, rotate.
- **Generic hole presets**: drag screw or zip-tie hole presets onto the box; edit size/position/rotation afterward.
- **Measure tool**: toggle it in the toolbar, then click or drag on the canvas to see the distance (in mm) between two points — clicks snap to nearby holes, template origins, or edges.
- **Import DXF**: bring in a real DXF as a new template (box, controller, or power-supply).
- **Export**: DXF (minimal ASCII R12) and PDF (1:1 scale vector) of the assembled design.
- **Save/Open**: project files as JSON.
- **Auto-updating template set**: the bundled templates work immediately offline, then the app quietly checks this repo's `assets/templates/` for anything newer/added and merges it in — no app update needed to get new boards.
- **Delete / copy / paste**: Delete removes the selected item; Ctrl/Cmd+C and Ctrl/Cmd+V duplicate it (offset so the copy is visible).

Most bundled box/power-supply templates are clearly-labeled placeholders — swap them for real DXFs via the Import button. The bundled Falcon, Kulp, Genius Pixel, and BUD NBF templates vary in accuracy:

- **Genius Pixel** (GLR, GPX16 2023+, GR16, GR4, PRO 16/32-port): outline and primary mounting holes digitized from Experience Lights' published footprint diagrams. The two PRO boards include only the confidently-read primary holes — check the vendor's diagram before fabrication if every hole matters.
- **Kulp** BeagleBone-cape and Raspberry-Pi-HAT controllers: sized to those platforms' official mechanical specs (Kulp doesn't publish board-specific drawings, but its boards conform to these standard form factors).
- **Raspberry Pi** (Model B form factor): outline and holes from a dimensioned drawing that matches the well-documented official spec exactly (85x56mm, 3mm corner radius, 58x49mm hole spacing) — high confidence.
- **BUD NBF-32016 and NBF-32226**: outer footprint and all 4 hole positions taken directly from BUD's own dimensioned drawings (hbnbf32016.pdf, hbnbf32226.pdf) — both have a hole pattern that's horizontally symmetric but vertically offset (closer to one edge than the other, presumably for latch clearance), reproduced exactly rather than approximated.
- **BUD NBF-32022**: outer footprint and corner-hole size/inset taken from a dimensioned drawing of that specific model. The drawing's holes are actually slightly asymmetric (shifted by the lid latches) and it also has a 32-hole lid-gasket screw pattern around the perimeter — both simplified away to a symmetric 4-corner-hole outline like every other bundled template.
- **Mean Well LRS-350 / LRS-150 (top mount)**: outer footprint from each unit's official spec sheet DIMENSION line. LRS-350's top hole pattern is confidently read (uniform 32.5mm inset from every edge); LRS-150's top/side hole positions weren't legible with confidence, so those two plus the LRS-350 side-mount template use generic placeholder holes — check the datasheet before fabrication if you're using the side mount or an LRS-150.
- **Falcon F16V3/F16V4, Falcon V2/SRx2/SRx4 Receivers**: hole centers measured directly from real STLs of each board — diameter is Ø4.00mm for all four (the three receivers' STLs actually measured Ø6.00mm; set to 4.00mm per request). Each outline is simplified to a bounding-box rectangle — the real perimeters have notches/tabs that aren't reproduced. The three receivers' STLs share the same 170x80mm *raw* bounding box, but that includes a flared antenna-connector housing that bulges out sideways over a narrow band; each board's actual squarer body was profiled separately (top/bottom sections away from that flare) rather than assumed identical — V2 and SRx2 are both 105.72x80mm, SRx4 is genuinely wider at 145.72x80mm. Each board's holes sit comfortably inside its own correct width.
- **PB_16 Receiver Out SMD and PB_16v2 Controller**: outline and all 4 hole positions read directly from the native KiCad source (Edge.Cuts layer + mounting-hole footprints) — exact, not reverse-engineered from a mesh or drawing. Both are genuinely asymmetric on both axes.
- **TICONN Enclosure Mounting Plate**: outline and its 2 primary mounting holes measured from a personal FreeCAD STL. Despite the name, the plate's real footprint (140.5x191.5mm) doesn't match the "5.9x3.9in" TICONN enclosure it was built for — used as measured rather than reconciled. A cluster of smaller bracket-specific holes and several irregular cutouts on the real plate aren't reproduced.
- **CG-1500**: no clean spec sheet available, only a dense front-panel drawing with no overall-size callout. Outline is derived from the 4 outermost holes of that drawing's hole grid (190.75x147.32mm) plus a 12mm margin to the enclosure wall, giving those 4 corner holes a uniform 12mm inset — an estimate, not a measurement, and hole diameter is assumed (4mm). Every other hole in the real grid (dozens more, plus knockouts, slots, a hinge, a latch) is omitted.
- **Holiday Coro HC-2500** (mounting plate): outline and all 27 mounting-boss positions read directly from a real vendor DXF — exact, not estimated. The outline is simplified to a bounding-box rectangle (the real perimeter has notches), and boss diameter is inferred from a marker symbol rather than an explicit dimension, but the 27 positions themselves are precise.
- **Holiday Coro AlphaPix Flex Receiver (951-61)**: outline, hole spacing, and vertical hole position read from a dimensioned vendor drawing — confident. The drawing doesn't give a left-edge offset for the hole pair, so horizontal placement assumes it's centered; hole diameter isn't dimensioned either and defaults to 3.0mm.
- **Falcon controllers/receivers not listed above, Kulp receivers, and Genius receivers not listed above**: generic placeholders — no official dimensions are published for these; replace via Import once you have a real DXF or measurement.

Only BUD NBF sizes backed by an actual dimensioned drawing (32016, 32022, 32226) are bundled — sizes with no drawing on hand were left out rather than guessed.

## Getting started

Requires the Flutter SDK (3.x).

```
flutter pub get
flutter run -d chrome    # or: -d windows / -d linux / -d macos
```

## Testing

```
flutter test
flutter analyze
```

`tool/gen_placeholder_templates.dart` regenerates the bundled placeholder templates under `assets/templates/`.

To turn a real DXF into a bundled template JSON (rather than importing it at runtime via the app's Import button), use `tool/dxf_to_json.py`:

```
pip install -r tool/requirements.txt
python tool/dxf_to_json.py board.dxf --id my_board --name "My Board" --category controller -o assets/templates/my_board.json
```

It reads LINE/CIRCLE/ARC/LWPOLYLINE directly, explodes block INSERTs, and flattens anything else (old-style POLYLINE, SPLINE, ELLIPSE) to a straight-segment polyline approximation. Pass `--scale 25.4` if the source DXF is in inches. Run with `--help` for all options.
