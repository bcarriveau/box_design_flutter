# Box Design (Flutter)

A Flutter (Web + Windows/Linux/macOS) rewrite of [box_design](https://github.com/computergeek1507/box_design), a tool for laying out controller enclosures: pick a box, drag controller boards / power supplies onto it, add screw holes and zip-tie slots, then export the result as DXF (for CNC/laser cutting) or PDF (1:1 scale reference/print).

## Features

- **Box templates**: pick an enclosure from the palette; the canvas resizes to fit it.
- **Controller / power-supply templates**: drag onto the box, move, rotate.
- **Generic hole presets**: drag screw or zip-tie hole presets onto the box; edit size/position/rotation afterward.
- **Import DXF**: bring in a real DXF as a new template (box, controller, or power-supply).
- **Remote templates**: fetch a template library from a GitHub repo (`index.json` + per-template JSON files) — not wired to a default repo yet.
- **Export**: DXF (minimal ASCII R12) and PDF (1:1 scale vector) of the assembled design.
- **Save/Open**: project files as JSON.

All bundled templates are clearly-labeled placeholders — swap them for real DXFs via the Import button.

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
