# Box Design

A tool for laying out controller enclosures (Web + Windows/Linux/macOS): pick a box, drag controller boards / power supplies onto it, add screw holes and zip-tie slots, then export the result as DXF (for CNC/laser cutting), PDF (1:1 scale reference/print), or an STL/3MF solid plate for 3D printing.

**Try it live: [computergeek1507.github.io/box_design_flutter](https://computergeek1507.github.io/box_design_flutter/)**

## Features

- **Box templates**: pick an enclosure from the palette; the canvas resizes to fit it.
- **Controller / power-supply templates**: drag onto the box, move, rotate.
- **Generic hole presets**: drag screw or zip-tie hole presets onto the box; edit size/position/rotation afterward.
- **Measure tool**: toggle it in the toolbar, then click or drag on the canvas to see the distance (in mm) between two points — clicks snap to nearby holes, template origins, or edges.
- **Import DXF**: bring in a real DXF as a new template (box, controller, or power-supply).
- **Export**: DXF (minimal ASCII R12) and PDF (1:1 scale vector) of the assembled design.
- **3D export**: STL and 3MF of the box outline extruded into a solid plate at a chosen thickness (the "Plate mm" field next to the export buttons), with every screw/zip-tie/slot hole — including holes baked into the box template itself and every mounting hole on a placed controller/power-supply template — cut all the way through. Ready to send straight to a 3D printer.
- **Save/Open**: project files as JSON.
- **Auto-updating template set**: the bundled templates work immediately offline, then the app quietly checks this repo's `assets/templates/` for anything newer/added and merges it in — no app update needed to get new boards.
- **Delete / copy / paste**: Delete removes the selected item; Ctrl/Cmd+C and Ctrl/Cmd+V duplicate it (offset so the copy is visible).

Most bundled box/power-supply templates are clearly-labeled placeholders — swap them for real DXFs via the Import button. The bundled Falcon, Kulp, Genius Pixel, and BUD NBF templates vary in accuracy:

- **Genius Pixel** (GLR, GPX16 2023+, GR16, GR4, PRO 16/32-port): outline and primary mounting holes digitized from Experience Lights' published footprint diagrams. The two PRO boards include only the confidently-read primary holes — check the vendor's diagram before fabrication if every hole matters.
- **Kulp** BeagleBone-cape and Raspberry-Pi-HAT controllers: sized to those platforms' official mechanical specs (Kulp doesn't publish board-specific drawings, but its boards conform to these standard form factors).
- **Raspberry Pi** (Model B form factor): outline and holes from a dimensioned drawing that matches the well-documented official spec exactly (85x56mm, 3mm corner radius, 58x49mm hole spacing) — high confidence.
- **BUD NBF-32016 and NBF-32226**: outer footprint and all 4 hole positions taken directly from BUD's own dimensioned drawings (hbnbf32016.pdf, hbnbf32226.pdf) — both have a hole pattern that's horizontally symmetric but vertically offset (closer to one edge than the other, presumably for latch clearance), reproduced exactly rather than approximated.
- **BUD NBF-32022**: outer footprint and corner-hole size/inset taken from a dimensioned drawing of that specific model. The drawing's holes are actually slightly asymmetric (shifted by the lid latches) and it also has a 32-hole lid-gasket screw pattern around the perimeter — both simplified away to a symmetric 4-corner-hole outline like every other bundled template.
- **Mean Well LRS-350 / LRS-600 (top mount)**: outer footprint from each unit's official spec sheet DIMENSION line. Both top hole patterns are confidently read as a uniform inset from every edge (32.5mm for LRS-350, 37.5mm for LRS-600). LRS-150's top/side hole positions, and both LRS-350's and LRS-600's side-mount patterns, weren't legible with confidence and use generic placeholder holes — check the datasheet before fabrication if you're using a side mount or an LRS-150.
- **Falcon F16V3/F16V4, Falcon V2/SRx2/SRx4 Receivers**: hole centers measured directly from real STLs of each board — diameter is Ø4.00mm for all four (the three receivers' STLs actually measured Ø6.00mm; set to 4.00mm per request). Each outline is simplified to a bounding-box rectangle — the real perimeters have notches/tabs that aren't reproduced. The three receivers' STLs share the same 170x80mm *raw* bounding box, but that includes a flared antenna-connector housing that bulges out sideways over a narrow band; each board's actual squarer body was profiled separately (top/bottom sections away from that flare) rather than assumed identical — V2 and SRx2 are both 105.72x80mm, SRx4 is genuinely wider at 145.72x80mm. Each board's holes sit comfortably inside its own correct width.
- **PB_16 Receiver Out SMD and PB_16v2 Controller**: outline and all 4 hole positions read directly from the native KiCad source (Edge.Cuts layer + mounting-hole footprints) — exact, not reverse-engineered from a mesh or drawing. Both are genuinely asymmetric on both axes.
- **TICONN Enclosure Mounting Plate**: outline and its 2 primary mounting holes measured from a personal FreeCAD STL. Despite the name, the plate's real footprint (140.5x191.5mm) doesn't match the "5.9x3.9in" TICONN enclosure it was built for — used as measured rather than reconciled. A cluster of smaller bracket-specific holes and several irregular cutouts on the real plate aren't reproduced.
- **CG-1500**: no clean spec sheet available, only a dense front-panel drawing with no overall-size callout. Outline is derived from the 4 outermost holes of that drawing's hole grid (190.75x147.32mm) plus a 12mm margin to the enclosure wall, giving those 4 corner holes a uniform 12mm inset — an estimate, not a measurement, and hole diameter is assumed (4mm). Every other hole in the real grid (dozens more, plus knockouts, slots, a hinge, a latch) is omitted.
- **Holiday Coro HC-2500** (mounting plate): outline and all 27 mounting-boss positions read directly from a real vendor DXF — exact, not estimated. The outline is simplified to a bounding-box rectangle (the real perimeter has notches), and boss diameter is inferred from a marker symbol rather than an explicit dimension, but the 27 positions themselves are precise.
- **Holiday Coro AlphaPix Flex Receiver (951-61)**: outline, hole spacing, and vertical hole position read from a dimensioned vendor drawing — confident. The drawing doesn't give a left-edge offset for the hole pair, so horizontal placement assumes it's centered; hole diameter isn't dimensioned either and defaults to 3.0mm.
- **Falcon F48 V3/V4 Mount**: two thin flat mounting brackets (not populated PCBs), each measured from a real STL, similar in concept but genuinely different in hole style/layout — not one copied onto the other. V4's 4 holes are counterbored (measured Ø6.0mm) in an irregular quadrilateral; V3 has 4 holes each in its own raised boss (measured Ø3.0mm) — its source STL was originally built for the CG-1500 enclosure specifically, but is used here as the general V3 reference rather than a CG-1500-only variant. Both set to Ø4.0mm per request. Each also has small corner cutouts/slots and an inner relief pocket on the real part that aren't reproduced.
- **Falcon F16v4 Expansion**: outline and its 4 mounting holes (each in its own raised boss) measured from a real STL — clean, confident data forming an exact 127x51mm rectangle. STL measured Ø3.0mm; set to Ø4.0mm to match the other Falcon boards. A set of corner cutouts, an inner relief pocket, and silkscreen text on the real board aren't reproduced.
- **Falcon F16v3 Differential Receiver**: outline and its 4 mounting holes measured from a real STL — a clean 101.75x51.45mm hole rectangle. The real holes are 4.0mm squares, modeled here as Ø4.0mm circles to match this project's usual hole representation.

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

If you have the board's actual KiCad project, `kicad_plugin/box_design_template_exporter.py` skips the DXF round trip entirely: it's a pcbnew Action Plugin (also runnable standalone via KiCad's bundled Python) that reads the Edge.Cuts outline and mounting holes straight from the `.kicad_pcb` file and emits the same template JSON, optionally registering it in `assets/templates/index.json` too. See `kicad_plugin/README.md` for install/usage.

Failing either of those, `tool/pcb_drawing_to_json.py` can extract an outline and mounting holes from a vendor PDF/SVG assembly drawing (printed/exported at 1:1 scale) by finding the board outline's longest straight edges and locating circular, edge-adjacent holes within a diameter range -- a measurement aid, not a certified digitizer, so its report and rendered preview should be checked against the source drawing before fabrication. Same `pip install -r tool/requirements.txt` setup as `dxf_to_json.py`; run with `--help` for options.
