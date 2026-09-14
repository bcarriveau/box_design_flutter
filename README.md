# Box Design (Flutter)

A Flutter (Web + Windows/Linux/macOS) rewrite of [box_design](https://github.com/computergeek1507/box_design), a tool for laying out controller enclosures: pick a box, drag controller boards / power supplies onto it, add screw holes and zip-tie slots, then export the result as DXF (for CNC/laser cutting) or PDF (1:1 scale reference/print).

**Try it live: [computergeek1507.github.io/box_design_flutter](https://computergeek1507.github.io/box_design_flutter/)**

## Features

- **Box templates**: pick an enclosure from the palette; the canvas resizes to fit it.
- **Controller / power-supply templates**: drag onto the box, move, rotate.
- **Generic hole presets**: drag screw or zip-tie hole presets onto the box; edit size/position/rotation afterward.
- **Import DXF**: bring in a real DXF as a new template (box, controller, or power-supply).
- **Remote templates**: fetch a template library from a GitHub repo (`index.json` + per-template JSON files) — not wired to a default repo yet.
- **Export**: DXF (minimal ASCII R12) and PDF (1:1 scale vector) of the assembled design.
- **Save/Open**: project files as JSON.

Most bundled box/power-supply templates are clearly-labeled placeholders — swap them for real DXFs via the Import button. The bundled Falcon, Kulp, Genius Pixel, and BUD NBF templates vary in accuracy:

- **Genius Pixel** (GLR, GPX16 2023+, GR16, GR4, PRO 16/32-port): outline and primary mounting holes digitized from Experience Lights' published footprint diagrams. The two PRO boards include only the confidently-read primary holes — check the vendor's diagram before fabrication if every hole matters.
- **Kulp** BeagleBone-cape and Raspberry-Pi-HAT controllers: sized to those platforms' official mechanical specs (Kulp doesn't publish board-specific drawings, but its boards conform to these standard form factors).
- **BUD NBF-32016 and NBF-32226**: outer footprint and all 4 hole positions taken directly from BUD's own dimensioned drawings (hbnbf32016.pdf, hbnbf32226.pdf) — both have a hole pattern that's horizontally symmetric but vertically offset (closer to one edge than the other, presumably for latch clearance), reproduced exactly rather than approximated.
- **BUD NBF-32022**: outer footprint and corner-hole size/inset taken from a dimensioned drawing of that specific model. The drawing's holes are actually slightly asymmetric (shifted by the lid latches) and it also has a 32-hole lid-gasket screw pattern around the perimeter — both simplified away to a symmetric 4-corner-hole outline like every other bundled template.
- **Mean Well LRS-350 / LRS-150 (top mount)**: outer footprint from each unit's official spec sheet DIMENSION line. LRS-350's top hole pattern is confidently read (uniform 32.5mm inset from every edge); LRS-150's top/side hole positions weren't legible with confidence, so those two plus the LRS-350 side-mount template use generic placeholder holes — check the datasheet before fabrication if you're using the side mount or an LRS-150.
- **Falcon controllers/receivers, Kulp receivers, and Genius receivers not listed above**: generic placeholders — no official dimensions are published for these; replace via Import once you have a real DXF or measurement.

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
