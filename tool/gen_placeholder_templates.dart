// Run with: dart run tool/gen_placeholder_templates.dart
// Regenerates the bundled placeholder template JSON assets.
import 'dart:convert';
import 'dart:io';

import 'package:box_design_flutter/dxf/dxf_json_codec.dart';
import 'package:box_design_flutter/models/dxf_entity.dart';
import 'package:box_design_flutter/models/vec2.dart';

/// A rectangle outline with [cornerRadius] rounded corners (0 = sharp),
/// plus a circular hole at each of [holeCenters] (all sharing [holeDiameter]).
List<DxfEntity> roundedRectWithHoles({
  required double width,
  required double height,
  required List<Vec2> holeCenters,
  required double holeDiameter,
  double cornerRadius = 0,
}) {
  const bulge90 = 0.4142135623730951; // tan(90deg / 4), quarter-circle bulge
  final List<PolyVertex> outline;
  if (cornerRadius <= 0) {
    outline = [
      const PolyVertex(Vec2(0, 0)),
      PolyVertex(Vec2(width, 0)),
      PolyVertex(Vec2(width, height)),
      PolyVertex(Vec2(0, height)),
    ];
  } else {
    final r = cornerRadius;
    outline = [
      PolyVertex(Vec2(r, 0)),
      PolyVertex(Vec2(width - r, 0), bulge: bulge90),
      PolyVertex(Vec2(width, r)),
      PolyVertex(Vec2(width, height - r), bulge: bulge90),
      PolyVertex(Vec2(width - r, height)),
      PolyVertex(Vec2(r, height), bulge: bulge90),
      PolyVertex(Vec2(0, height - r)),
      PolyVertex(Vec2(0, r), bulge: bulge90),
    ];
  }
  return [
    DxfPolyline(outline, closed: true),
    for (final c in holeCenters) DxfCircle(c, holeDiameter / 2),
  ];
}

/// A rectangle with a rectangular notch cut out of the top edge (used by
/// several Genius Pixel boards), rounded corners on the 6 outer corners,
/// plus circular holes.
List<DxfEntity> notchedTopRectWithHoles({
  required double width,
  required double height,
  required double notchLeftWidth,
  required double notchDepth,
  required double notchWidth,
  required List<Vec2> holeCenters,
  required double holeDiameter,
  double cornerRadius = 0,
}) {
  const bulge90 = 0.4142135623730951;
  final r = cornerRadius;
  final notchRight = notchLeftWidth + notchWidth;
  final outline = [
    PolyVertex(Vec2(r, 0)),
    PolyVertex(Vec2(width - r, 0), bulge: bulge90),
    PolyVertex(Vec2(width, r)),
    PolyVertex(Vec2(width, height - r), bulge: bulge90),
    PolyVertex(Vec2(width - r, height)),
    PolyVertex(Vec2(notchRight, height)),
    PolyVertex(Vec2(notchRight, height - notchDepth)),
    PolyVertex(Vec2(notchLeftWidth, height - notchDepth)),
    PolyVertex(Vec2(notchLeftWidth, height)),
    PolyVertex(Vec2(r, height), bulge: bulge90),
    PolyVertex(Vec2(0, height - r)),
    PolyVertex(Vec2(0, r), bulge: bulge90),
  ];
  return [
    DxfPolyline(outline, closed: true),
    for (final c in holeCenters) DxfCircle(c, holeDiameter / 2),
  ];
}

List<DxfEntity> rectangleWithCornerHoles({
  required double width,
  required double height,
  required double holeInset,
  required double holeDiameter,
}) {
  final outline = DxfPolyline([
    const PolyVertex(Vec2(0, 0)),
    PolyVertex(Vec2(width, 0)),
    PolyVertex(Vec2(width, height)),
    PolyVertex(Vec2(0, height)),
  ], closed: true);

  final holeCenters = [
    Vec2(holeInset, holeInset),
    Vec2(width - holeInset, holeInset),
    Vec2(width - holeInset, height - holeInset),
    Vec2(holeInset, height - holeInset),
  ];

  return [
    outline,
    for (final c in holeCenters) DxfCircle(c, holeDiameter / 2),
  ];
}

final _indexEntries = <Map<String, String>>[];

void writeTemplate(String fileName, String id, String name, String category, List<DxfEntity> entities) {
  final json = {
    'id': id,
    'name': name,
    'category': category,
    'entities': entitiesToJson(entities),
  };
  final file = File('assets/templates/$fileName');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  stdout.writeln('Wrote ${file.path}');
  _indexEntries.add({'id': id, 'file': fileName});
}

/// Writes assets/templates/index.json -- the manifest [TemplateLibrary.
/// fetchRemoteTemplates] reads to discover this repo's templates over
/// HTTP. Not a template itself: [TemplateLibrary.loadBuiltIns] explicitly
/// skips this filename when scanning bundled assets.
void writeIndex() {
  final file = File('assets/templates/index.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_indexEntries));
  stdout.writeln('Wrote ${file.path} (${_indexEntries.length} entries)');
}

void main() {
  // All PLACEHOLDER geometry — replace by importing real DXFs over these
  // ids once available; everything downstream treats them like any other
  // template.
  //
  // CG-1500: no clean spec sheet available, only a dense front-panel
  // drawing (dozens of small mounting holes, two knockouts, slots, hinges,
  // a latch, cable-tie tabs) with no explicit overall width/height
  // callout. Transcribing every hole isn't practical, so instead the
  // outline is derived from the 4 outermost holes of that grid: leftmost/
  // topmost at (0,0)in, rightmost/bottommost at (7.51,5.80)in -- a
  // 190.75 x 147.32mm grid -- plus a 12mm margin added on every side to
  // reach the enclosure wall, giving those same 4 corner holes a uniform
  // 12mm inset. Hole diameter isn't legible in the drawing; 4mm assumed to
  // match the other bundled placeholders. Still an estimate, not a
  // measurement -- and every other hole in the real grid is omitted.
  writeTemplate(
    'cg1500_placeholder.json',
    'cg1500_placeholder',
    'CG-1500 Enclosure (estimated, placeholder)',
    'box',
    rectangleWithCornerHoles(width: 214.75, height: 171.32, holeInset: 12, holeDiameter: 4.0),
  );

  // --- Genius Pixel (Experience Lights) -----------------------------------
  // Dimensions digitized from official vendor footprint diagrams
  // (store.experiencelights.com); notch/hole coordinates are direct edge
  // insets read off those drawings. The two "PRO" boards include only the
  // primary/confidently-read mounting holes (outline is exact; some minor
  // interior holes visible on the diagram are omitted) — check the vendor
  // diagram before fabrication if every hole matters.

  writeTemplate(
    'genius_gpx16_2023_controller.json',
    'genius_gpx16_2023_controller',
    'Genius Pixel GPX16 Controller (2023+)',
    'controller',
    notchedTopRectWithHoles(
      width: 203.55,
      height: 119.00,
      notchLeftWidth: 141.00,
      notchDepth: 12.00,
      notchWidth: 28.00,
      cornerRadius: 2.5,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(22.60, 109.00),
        Vec2(175.00, 109.00),
        Vec2(22.60, 7.40),
        Vec2(175.00, 7.40),
      ],
    ),
  );

  writeTemplate(
    'genius_glr_controller.json',
    'genius_glr_controller',
    'Genius Long Range Controller (GLR)',
    'controller',
    notchedTopRectWithHoles(
      width: 180.00,
      height: 114.00,
      notchLeftWidth: 123.00,
      notchDepth: 12.00,
      notchWidth: 28.00,
      cornerRadius: 2.5,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(22.00, 109.00),
        Vec2(175.00, 109.00),
        Vec2(22.00, 5.00),
        Vec2(175.00, 5.00),
      ],
    ),
  );

  writeTemplate(
    'genius_gr16_receiver.json',
    'genius_gr16_receiver',
    'Genius Pixel GR16 Receiver (16 Port)',
    'receiver',
    roundedRectWithHoles(
      width: 180.00,
      height: 114.00,
      cornerRadius: 2.5,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(22.00, 109.00),
        Vec2(175.00, 109.00),
        Vec2(22.00, 5.00),
        Vec2(175.00, 5.00),
      ],
    ),
  );

  writeTemplate(
    'genius_gr4_receiver.json',
    'genius_gr4_receiver',
    'Genius Pixel GR4 Receiver (2024 Edition)',
    'receiver',
    roundedRectWithHoles(
      width: 91.00,
      height: 75.00,
      cornerRadius: 2.5,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(5.00, 70.00),
        Vec2(86.00, 70.00),
        Vec2(5.00, 5.00),
        Vec2(86.00, 5.00),
      ],
    ),
  );

  writeTemplate(
    'genius_pro32_controller.json',
    'genius_pro32_controller',
    'Genius PRO 32-Port Controller',
    'controller',
    roundedRectWithHoles(
      width: 334.00,
      height: 238.00,
      cornerRadius: 3.0,
      holeDiameter: 5.0,
      holeCenters: const [
        // 10 perimeter mounting holes
        Vec2(4.116, 4.116),
        Vec2(112.654, 4.116),
        Vec2(221.087, 4.116),
        Vec2(329.52, 4.116),
        Vec2(4.116, 233.916),
        Vec2(112.654, 233.916),
        Vec2(221.087, 233.916),
        Vec2(329.52, 233.916),
        Vec2(4.35, 119.016),
        Vec2(329.65, 119.016),
      ],
    )
      ..addAll([
        // 8 interior Ø4.50 holes (slightly smaller than the perimeter Ø5.00)
        for (final p in const [
          Vec2(59.782, 164.916),
          Vec2(209.782, 164.916),
          Vec2(59.782, 139.916),
          Vec2(209.782, 139.916),
          Vec2(59.782, 89.916),
          Vec2(209.782, 89.916),
          Vec2(59.782, 64.916),
          Vec2(209.782, 64.916),
        ])
          DxfCircle(p, 4.5 / 2),
      ]),
  );

  writeTemplate(
    'genius_pro16_controller.json',
    'genius_pro16_controller',
    'Genius PRO 16-Port Controller',
    'controller',
    roundedRectWithHoles(
      width: 241.00,
      height: 208.00,
      cornerRadius: 3.0,
      holeDiameter: 4.3,
      holeCenters: const [
        Vec2(49.50, 160.00),
        Vec2(199.50, 160.00),
        Vec2(49.50, 110.00),
        Vec2(199.50, 110.00),
      ],
    ),
  );

  writeTemplate(
    'genius_pro_receiver.json',
    'genius_pro_receiver',
    'Genius PRO Receiver (4/8/16 Port)',
    'receiver',
    roundedRectWithHoles(
      width: 241.00,
      height: 208.00,
      cornerRadius: 3.0,
      holeDiameter: 4.3,
      holeCenters: const [
        Vec2(49.50, 160.00),
        Vec2(199.50, 160.00),
        Vec2(49.50, 110.00),
        Vec2(199.50, 110.00),
      ],
    ),
  );

  // --- Falcon (PixelController / FalconChristmas) -------------------------
  // No official mechanical drawings or hole coordinates are published for
  // any Falcon board (checked pixelcontroller.com, falconchristmas.com,
  // community wikis/forums) — these are generic placeholders only. Falcon
  // also has no distinct "receiver" product line (expansion boards instead);
  // the receiver placeholder below is a generic small-board stand-in.

  writeTemplate(
    'falcon_controller_placeholder.json',
    'falcon_controller_placeholder',
    'Falcon Controller (placeholder)',
    'controller',
    rectangleWithCornerHoles(width: 170, height: 105, holeInset: 6, holeDiameter: 3.5),
  );

  // Falcon F16V4: outline and hole positions measured directly from a
  // user-supplied STL (16v4_Controller.stl) via mesh analysis -- the 4
  // mounting holes are exact (perfectly circular, identical Ø4.00mm, found
  // with high confidence). The board's real perimeter is NOT a plain
  // rectangle (it has notches/tabs the STL analysis didn't reconstruct);
  // this uses its 195.5 x 139.52mm bounding box as a simplified rectangular
  // outline instead. Hole placement is genuinely asymmetric on the right
  // side (22.2mm vs 35.2mm inset from the right edge) -- that's real,
  // not an approximation.
  writeTemplate(
    'falcon_16v4_controller.json',
    'falcon_16v4_controller',
    'Falcon F16V4 Controller',
    'controller',
    roundedRectWithHoles(
      width: 195.5,
      height: 139.52,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(33.27, 125.16),
        Vec2(173.27, 125.16),
        Vec2(33.27, 23.16),
        Vec2(160.27, 23.16),
      ],
    ),
  );

  // Falcon F16V3: same 195.5 x 139.52mm bounding box and non-rectangular
  // real perimeter as the F16V4 (measured from a separate user-supplied
  // STL, 16v3_Controller.stl) -- shares the F16V4's left column and
  // bottom-right hole exactly, but its top-right hole sits at a different
  // x, making V3's pattern a clean, nearly-symmetric rectangle (33.27mm vs
  // 35.23mm inset) rather than V4's more asymmetric one. STL measured
  // Ø4.00mm already; no adjustment needed.
  writeTemplate(
    'falcon_16v3_controller.json',
    'falcon_16v3_controller',
    'Falcon F16V3 Controller',
    'controller',
    roundedRectWithHoles(
      width: 195.5,
      height: 139.52,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(33.27, 125.16),
        Vec2(160.27, 125.16),
        Vec2(33.27, 23.16),
        Vec2(160.27, 23.16),
      ],
    ),
  );

  // Falcon V2 Receiver: outline and hole positions measured directly from a
  // user-supplied STL (MW350_-_VM_-_v2_Smart_Receiver.stl) via mesh
  // analysis. The STL's raw bounding box is 170mm wide, but that includes a
  // flared antenna-connector housing that bulges out sideways over a
  // narrow vertical band -- the actual board body (profiled above and
  // below that band) is a consistent 105.72mm wide on both sides. Width
  // here uses that squarer body measurement, not the flared bounding box.
  // The 4 mounting-hole centers are exact (full board-thickness
  // through-holes, perfectly circular) -- the STL measured them at
  // Ø6.00mm, but the hole diameter here is set to 4.00mm per request. A
  // second pair of stepped/countersunk holes near the left/right edges
  // (Ø5.0mm widening to Ø7.05mm, not spanning the full thickness) was
  // excluded -- almost certainly antenna/RF connector cutouts, not
  // mounting holes. As with the F16V4, the real perimeter isn't a plain
  // rectangle; this uses a simplified bounding-box rectangle instead. Hole
  // placement is vertically symmetric but genuinely asymmetric
  // horizontally (17.71mm vs 12.26mm inset from the left/right edges).
  writeTemplate(
    'falcon_v2_receiver.json',
    'falcon_v2_receiver',
    'Falcon V2 Receiver (105.7x80mm bounding box)',
    'receiver',
    roundedRectWithHoles(
      width: 105.72,
      height: 80.0,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(17.71, 68.6),
        Vec2(93.46, 68.6),
        Vec2(17.71, 11.6),
        Vec2(93.46, 11.6),
      ],
    ),
  );

  // Falcon SRx2 Receiver: same board body (105.72 x 80mm, squarer-body
  // width per the V2 Receiver comment above) as the V2 Receiver (measured
  // from a separate user-supplied STL,
  // MW350_-_VM_-_SRx2_Smart_Receiver.stl) and the same excluded pair of
  // stepped/countersunk antenna-style holes -- but a genuinely different
  // mounting-hole pattern: horizontally symmetric (12.86mm/12.88mm inset
  // from both edges) and near-symmetric vertically (8.08mm top vs 8.45mm
  // bottom). STL measured Ø6.00mm; set to 4.00mm to match the other Falcon
  // boards.
  writeTemplate(
    'falcon_srx2_receiver.json',
    'falcon_srx2_receiver',
    'Falcon SRx2 Receiver (105.7x80mm bounding box)',
    'receiver',
    roundedRectWithHoles(
      width: 105.72,
      height: 80.0,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(12.86, 71.92),
        Vec2(92.86, 71.92),
        Vec2(12.88, 8.45),
        Vec2(92.88, 8.45),
      ],
    ),
  );

  // Falcon SRx4 Receiver: same squarer-body measurement approach as V2/SRx2
  // (see comment above) and the same excluded antenna-style hole pair, but
  // this board's own squarer body is genuinely wider -- 145.72mm, not
  // 105.72mm -- profiled the same way (top/bottom sections away from the
  // antenna-housing flare, both sides agreeing precisely). With its own
  // correct width, all 4 mounting holes sit comfortably inside the
  // outline (roughly symmetric, ~9.36mm inset from each edge), unlike the
  // mismatch that came from reusing V2/SRx2's narrower width.
  writeTemplate(
    'falcon_srx4_receiver.json',
    'falcon_srx4_receiver',
    'Falcon SRx4 Receiver (145.7x80mm bounding box)',
    'receiver',
    roundedRectWithHoles(
      width: 145.72,
      height: 80.0,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(9.36, 68.33),
        Vec2(136.36, 68.57),
        Vec2(9.38, 13.55),
        Vec2(136.38, 13.73),
      ],
    ),
  );

  // Holiday Coro AlphaPix Flex Differential Receiver (PART #951-61 REV 1.5):
  // outline (80.963 x 60.0mm), hole spacing (25.385mm), and vertical hole
  // position (24.441mm up from the bottom) all read directly from a
  // dimensioned vendor drawing -- confident. The drawing gives no offset
  // from the left edge to the hole pair, only their spacing and the overall
  // width, so horizontal placement here assumes the pair is centered
  // left-right (a common convention, not confirmed). Hole diameter also
  // isn't dimensioned in the drawing; 3.0mm assumed to match the other
  // small receiver placeholders.
  writeTemplate(
    'holidaycoro_951_61_receiver.json',
    'holidaycoro_951_61_receiver',
    'Holiday Coro AlphaPix Flex Receiver 951-61 (81x60mm)',
    'receiver',
    roundedRectWithHoles(
      width: 80.963,
      height: 60.0,
      holeDiameter: 3.0,
      holeCenters: const [
        Vec2(27.789, 24.441),
        Vec2(53.174, 24.441),
      ],
    ),
  );

  // --- Kulp (KulpLights) ---------------------------------------------------
  // No Kulp-specific mechanical drawings are published. Kulp's BeagleBone-
  // based boards (K16/K32/K8 families) do conform to the official BeagleBone
  // "cape" envelope, and the Pi-based boards (K8-Pi/K2-Pi) to the official
  // Raspberry Pi HAT spec — those two are real standards, not guesses.
  // Kulp has no distinct "receiver" product line; placeholder only.

  writeTemplate(
    'kulp_beaglebone_controller.json',
    'kulp_beaglebone_controller',
    'Kulp Controller – BeagleBone Cape (K16/K32/K8)',
    'controller',
    rectangleWithCornerHoles(width: 86.4, height: 53.3, holeInset: 4, holeDiameter: 3.2),
  );

  writeTemplate(
    'kulp_pi_hat_controller.json',
    'kulp_pi_hat_controller',
    'Kulp Controller – Raspberry Pi HAT (K8-Pi/K2-Pi)',
    'controller',
    roundedRectWithHoles(
      width: 65.0,
      height: 56.5,
      holeDiameter: 2.75,
      holeCenters: const [
        // Official Raspberry Pi HAT mounting-hole spec: 58 x 49mm spacing.
        Vec2(3.5, 3.5),
        Vec2(61.5, 3.5),
        Vec2(3.5, 52.5),
        Vec2(61.5, 52.5),
      ],
    ),
  );

  // Raspberry Pi (Model B form factor: 2B/3B/3B+/4B): outline and hole
  // positions from a dimensioned drawing (SeenGreat wiki) that matches the
  // well-documented official spec exactly -- 85 x 56mm board, 3mm corner
  // radius, 4x holes on the standard 58 x 49mm pattern. Unlike the Kulp Pi
  // HAT template above (which only covers the narrower 65mm-wide HAT
  // footprint that stacks on top), this is the full Pi board itself,
  // extending further right for the USB/Ethernet ports -- both share the
  // same 4 mounting-hole positions since HATs stack on the same standoffs.
  writeTemplate(
    'raspberry_pi_model_b.json',
    'raspberry_pi_model_b',
    'Raspberry Pi (Model B form factor)',
    'controller',
    roundedRectWithHoles(
      width: 85.0,
      height: 56.0,
      cornerRadius: 3.0,
      holeDiameter: 2.7,
      holeCenters: const [
        Vec2(3.5, 3.5),
        Vec2(61.5, 3.5),
        Vec2(3.5, 52.5),
        Vec2(61.5, 52.5),
      ],
    ),
  );

  // --- BUD Industries NBF-Series NEMA economy enclosures ------------------
  // Outer footprint (A x B) for each model taken directly from BUD's NBF
  // datasheet nominal-dimensions table. Corner mounting-hole inset/diameter
  // for NBF-32022 came from a dimensioned drawing published on its Amazon
  // listing (ASIN B005UPAPD2): Ø0.157" (~4.0mm) holes at a 0.984"
  // (~25mm) typical inset -- the drawing's holes are actually slightly
  // asymmetric (shifted by the lid latches on one edge) and it also shows a
  // 32-hole lid-gasket screw pattern around the perimeter; both are
  // simplified away here to the same symmetric 4-corner-hole convention
  // used by every other bundled template.
  writeTemplate(
    'bud_nbf32022.json',
    'bud_nbf32022',
    'BUD NBF-32022 NEMA Enclosure',
    'box',
    rectangleWithCornerHoles(width: 350, height: 250, holeInset: 25, holeDiameter: 4.0),
  );

  // Official BUD dimensioned drawing (hbnbf32016.pdf): outer 304.50 x
  // 203.00mm; 4x Ø4.00mm M5 self-tapping holes on a 225.00 x 127.50mm
  // pattern, horizontally centered but vertically asymmetric -- the bottom
  // row sits 45.68mm from the bottom edge (leaving 29.82mm at the top).
  writeTemplate(
    'bud_nbf32016.json',
    'bud_nbf32016',
    'BUD NBF-32016 NEMA Enclosure',
    'box',
    roundedRectWithHoles(
      width: 304.50,
      height: 203.00,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(39.75, 45.68),
        Vec2(264.75, 45.68),
        Vec2(39.75, 173.18),
        Vec2(264.75, 173.18),
      ],
    ),
  );

  // Official BUD dimensioned drawing (hbnbf32226.pdf): outer 400.0 x
  // 300.0mm; 4x Ø5.0mm M5x0.8 threaded-insert corner holes on a 325.3 x
  // 229.8mm pattern, horizontally centered but vertically asymmetric (same
  // bottom-edge-referenced pattern as NBF-32016) -- bottom row 50.0mm from
  // the bottom edge, leaving 20.2mm at the top.
  writeTemplate(
    'bud_nbf32226.json',
    'bud_nbf32226',
    'BUD NBF-32226 NEMA Enclosure',
    'box',
    roundedRectWithHoles(
      width: 400.0,
      height: 300.0,
      holeDiameter: 5.0,
      holeCenters: const [
        Vec2(37.35, 50.0),
        Vec2(362.65, 50.0),
        Vec2(37.35, 279.8),
        Vec2(362.65, 279.8),
      ],
    ),
  );

  // --- PB_16 (Scott's own KiCad project) -----------------------------------
  // Outline and hole positions read directly from the native KiCad source
  // (Receiver_Out.kicad_pcb, Edge.Cuts layer + MountingHole_3.7mm
  // footprints) rather than reverse-engineered from a mesh or drawing --
  // exact, not approximated. 4x Ø3.7mm non-plated mounting holes, genuinely
  // asymmetric on both axes (left/right inset differs by ~0.6mm, top/bottom
  // by ~1.4mm) -- confirmed real from the source file.
  writeTemplate(
    'pb16_receiver_out.json',
    'pb16_receiver_out',
    'PB_16 Receiver Out SMD (59.3x71.4mm)',
    'receiver',
    roundedRectWithHoles(
      width: 59.33,
      height: 71.40,
      holeDiameter: 3.7,
      holeCenters: const [
        Vec2(54.783, 60.422),
        Vec2(3.983, 60.422),
        Vec2(54.783, 9.622),
        Vec2(3.983, 9.622),
      ],
    ),
  );

  // PB_16v2: same source approach as pb16_receiver_out above (native KiCad
  // Edge.Cuts + MountingHole_3.7mm footprints from PB_16.kicad_pcb) -- the
  // main 16-channel PocketBeagle-based controller board. Hole spacing lands
  // on exact imperial values (127.0mm = 5.00in, 50.8mm = 2.00in), but
  // placement is genuinely asymmetric on both axes -- notably 13.32mm from
  // the bottom edge vs 35.77mm from the top, since the PocketBeagle SBC and
  // its headers occupy the top portion of the board.
  writeTemplate(
    'pb16_controller.json',
    'pb16_controller',
    'PB_16v2 Controller',
    'controller',
    roundedRectWithHoles(
      width: 142.10,
      height: 99.89,
      holeDiameter: 3.7,
      holeCenters: const [
        Vec2(135.999, 64.122),
        Vec2(8.999, 64.122),
        Vec2(135.999, 13.322),
        Vec2(8.999, 13.322),
      ],
    ),
  );

  // --- Mean Well LRS enclosed power supplies -------------------------------
  // Outer footprint from each unit's official spec sheet DIMENSION line
  // (LRS-350-SPEC / LRS-150-SPEC, meanwell.com): 215x115x30mm and
  // 159x97x30mm (L*W*H). Each unit ships with two usable mounting-hole
  // patterns -- through the top/bottom face, or through one of the end
  // (side) faces -- so both get a "top" and "side" footprint template.
  //
  // LRS-350 (Case 207A) top holes: confidently read as 4x M4 (tapped, no
  // through-diameter given -- 4.0mm used as a stand-in) at a uniform 32.5mm
  // inset from every edge on both axes (i.e. a 150.0 x 50.0mm hole
  // pattern) -- the three "32.5" callouts on the drawing agree with each
  // other and with the outer size, which is why this one is high-confidence.
  writeTemplate(
    'meanwell_lrs350_top.json',
    'meanwell_lrs350_top',
    'Mean Well LRS-350 (top mount, 215x115mm)',
    'powerSupply',
    roundedRectWithHoles(
      width: 215.0,
      height: 115.0,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(32.5, 32.5),
        Vec2(182.5, 32.5),
        Vec2(32.5, 82.5),
        Vec2(182.5, 82.5),
      ],
    ),
  );

  // LRS-350 side-mount footprint: outer size (length x case height) is
  // exact, but the drawing's "4-M4(Both Sides)" side holes couldn't be read
  // with confidence beyond their horizontal position (reusing the same
  // 32.5mm end inset as the top pattern seems likely but isn't verified) --
  // shown as a single hole at each end, vertically centered, as a
  // placeholder for the real 4-hole pattern. Check the datasheet before
  // fabrication if the side mount is actually being used.
  writeTemplate(
    'meanwell_lrs350_side_placeholder.json',
    'meanwell_lrs350_side_placeholder',
    'Mean Well LRS-350 (side mount, 215x30mm, placeholder holes)',
    'powerSupply',
    roundedRectWithHoles(
      width: 215.0,
      height: 30.0,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(32.5, 15.0),
        Vec2(182.5, 15.0),
      ],
    ),
  );

  // LRS-150 (Case 241A): outer size is exact (official DIMENSION line), but
  // its top view shows only 2x M3 holes and the side view only 3x M3 --
  // neither count nor exact offsets could be read with confidence from the
  // drawing. Hole positions below are generic corner placeholders (not
  // measured) until a clearer drawing or real DXF is available.
  writeTemplate(
    'meanwell_lrs150_top_placeholder.json',
    'meanwell_lrs150_top_placeholder',
    'Mean Well LRS-150 (top mount, 159x97mm, placeholder holes)',
    'powerSupply',
    rectangleWithCornerHoles(width: 159.0, height: 97.0, holeInset: 10.0, holeDiameter: 3.0),
  );

  writeTemplate(
    'meanwell_lrs150_side_placeholder.json',
    'meanwell_lrs150_side_placeholder',
    'Mean Well LRS-150 (side mount, 159x30mm, placeholder holes)',
    'powerSupply',
    rectangleWithCornerHoles(width: 159.0, height: 30.0, holeInset: 10.0, holeDiameter: 3.0),
  );

  // LRS-600 (Case 292): outer 225 x 124 x 41mm from the official spec
  // sheet DIMENSION line. Top holes resolved the same way as LRS-350's --
  // a uniform 37.5mm inset from every edge (the drawing's two flanking
  // "37.5" callouts agree with each other and with its explicit "150"
  // hole-spacing label: 225 - 2*37.5 = 150) -- giving a 150 x 49mm hole
  // rectangle. High confidence, like LRS-350's top pattern.
  writeTemplate(
    'meanwell_lrs600_top.json',
    'meanwell_lrs600_top',
    'Mean Well LRS-600 (top mount, 225x124mm)',
    'powerSupply',
    roundedRectWithHoles(
      width: 225.0,
      height: 124.0,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(37.5, 37.5),
        Vec2(187.5, 37.5),
        Vec2(37.5, 86.5),
        Vec2(187.5, 86.5),
      ],
    ),
  );

  // LRS-600 side-mount footprint: outer size (length x case height) is
  // exact, but the drawing's "8-M4(Both Sides)" side holes -- twice as
  // many as LRS-350's side pattern -- couldn't be read with confidence.
  // Placeholder holes only, like LRS-350's side mount.
  writeTemplate(
    'meanwell_lrs600_side_placeholder.json',
    'meanwell_lrs600_side_placeholder',
    'Mean Well LRS-600 (side mount, 225x41mm, placeholder holes)',
    'powerSupply',
    rectangleWithCornerHoles(width: 225.0, height: 41.0, holeInset: 12.0, holeDiameter: 4.0),
  );

  // --- Misc / personal projects ---------------------------------------------
  // TICONN mounting plate: outline and hole positions measured directly
  // from a personal FreeCAD project's STL (mounting plate2-Body.stl) --
  // real, not a published spec. Despite the "5.9x3.9in" TICONN enclosure
  // this plate was built for, the plate's own footprint is 140.5 x
  // 191.5mm, not 149.9 x 99.1mm; used as-is per request rather than
  // reconciled to the enclosure's nominal size. Only the plate's 2 large
  // Ø6.25mm mounting holes (symmetric, centered horizontally, 15.25mm
  // inset from the top/bottom edges) are included here -- a separate
  // cluster of 4 small Ø2.56mm holes for a specific bracket, plus several
  // irregular rectangular cutouts/pockets elsewhere on the plate, were left
  // out as not generically useful on a bundled template.
  writeTemplate(
    'ticonn_mounting_plate.json',
    'ticonn_mounting_plate',
    'TICONN Enclosure Mounting Plate',
    'box',
    roundedRectWithHoles(
      width: 140.5,
      height: 191.5,
      holeDiameter: 6.25,
      holeCenters: const [
        Vec2(70.25, 15.25),
        Vec2(70.25, 176.25),
      ],
    ),
  );

  // Holiday Coro HC-2500: outline and all 27 mounting-boss locations read
  // directly from a real vendor DXF (629-MountingLocationsDrawing.dxf,
  // HC-2500_MOUNTING_PLATE + HC-2500_BOSSES layers) -- exact, not
  // estimated. The DXF's plate-outline layer also has ~130 other shapes
  // (connector/component cutouts) that aren't reproduced here, and its
  // real perimeter has notches this simplifies away to a 243.84 x
  // 290.87mm bounding-box rectangle. Boss diameter (Ø2.78mm) is inferred
  // from each boss's identical marker-square size in the drawing, not an
  // explicit dimension -- treat it as approximate even though the 27
  // positions themselves are exact.
  writeTemplate(
    'holidaycoro_hc2500.json',
    'holidaycoro_hc2500',
    'Holiday Coro HC-2500 Mounting Plate',
    'box',
    roundedRectWithHoles(
      width: 243.84,
      height: 290.8735,
      holeDiameter: 2.78,
      holeCenters: const [
        Vec2(7.620, 283.252),
        Vec2(236.220, 283.252),
        Vec2(20.320, 265.980),
        Vec2(121.920, 265.980),
        Vec2(147.320, 265.980),
        Vec2(160.020, 265.980),
        Vec2(223.520, 265.980),
        Vec2(83.820, 227.880),
        Vec2(160.020, 227.880),
        Vec2(121.920, 189.780),
        Vec2(223.520, 189.780),
        Vec2(223.520, 164.380),
        Vec2(7.620, 151.680),
        Vec2(83.820, 151.680),
        Vec2(160.020, 151.680),
        Vec2(20.320, 138.980),
        Vec2(121.920, 138.980),
        Vec2(147.320, 138.980),
        Vec2(223.520, 138.980),
        Vec2(7.620, 61.002),
        Vec2(83.820, 61.002),
        Vec2(160.020, 61.002),
        Vec2(236.220, 61.002),
        Vec2(7.620, 11.002),
        Vec2(83.820, 11.002),
        Vec2(160.020, 11.002),
        Vec2(236.220, 11.002),
      ],
    ),
  );

  // Falcon F48 V4 Mount: outline and its 4 counterbored mounting holes
  // measured from a user-supplied STL (f48_V4_Mount_v1.stl) via mesh
  // analysis. This is a thin (8mm) flat bracket, not a populated PCB --
  // the drawing also has 4 small square corner cutouts and a large inner
  // relief pocket that aren't reproduced here, per request. The 4 holes
  // are stepped (Ø3.0mm through-hole widening to Ø6.0mm counterbore for a
  // flush screw head) -- STL measured Ø6.0mm at the counterbore; set to
  // 4.0mm per request. Their layout is a slightly irregular quadrilateral,
  // not a plain rectangle -- two holes share an x-coordinate (the right
  // side), the other two don't.
  writeTemplate(
    'falcon_f48_v4_mount.json',
    'falcon_f48_v4_mount',
    'Falcon F48 V4 Mount',
    'controller',
    roundedRectWithHoles(
      width: 207.0,
      height: 119.0,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(28.0, 12.08),
        Vec2(180.0, 12.0),
        Vec2(180.0, 113.0),
        Vec2(40.0, 113.0),
      ],
    ),
  );

  // Falcon F48 V3 Mount: outline and its 4 mounting holes measured from a
  // user-supplied STL (Falcon_F48_CG1500_Mount_v6.stl, originally built
  // for the CG-1500 enclosure specifically, but used here as the general
  // reference for the F48 V3 mount shape/holes rather than a CG-1500-only
  // variant). Similar concept to the F48 V4 mount above (a thin flat
  // bracket with primary mounting holes plus features skipped here), but
  // a genuinely different hole style and layout, not just a copy -- each
  // hole here is a Ø3.0mm through-hole in its own raised Ø7.0mm boss (STL
  // measured Ø3.0mm; set to 4.0mm to match the sibling template). Also has
  // 4 elongated (9.5 x 3.5mm) corner slots and a large inner relief pocket
  // (173 x 104.6mm) that aren't reproduced, same as the V4 mount's
  // omissions.
  writeTemplate(
    'falcon_f48_v3_mount.json',
    'falcon_f48_v3_mount',
    'Falcon F48 V3 Mount',
    'controller',
    roundedRectWithHoles(
      width: 193.0,
      height: 134.644,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(20.05, 9.644),
        Vec2(172.05, 9.644),
        Vec2(33.05, 111.144),
        Vec2(160.05, 111.144),
      ],
    ),
  );

  // Falcon F16v4 Expansion addon board: outline and its 4 mounting holes
  // measured from a user-supplied STL (Falcon_F16v4_Expansion_v1_v1.stl).
  // Clean, confident data -- each hole is a Ø3.0mm through-hole in its own
  // raised Ø6.0mm boss, at 4 positions forming an exact rectangle (127.0 x
  // 51.0mm spacing; 127.0mm = precisely 5.0in). STL measured Ø3.0mm; set
  // to 4.0mm to match the other bundled Falcon boards. A set of 4 corner
  // cutouts, a large inner relief pocket, and engraved silkscreen text are
  // on the real board but aren't reproduced here.
  writeTemplate(
    'falcon_f16v4_expansion.json',
    'falcon_f16v4_expansion',
    'Falcon F16v4 Expansion',
    'controller',
    roundedRectWithHoles(
      width: 207.0,
      height: 70.0,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(39.0, 13.0),
        Vec2(39.0, 64.0),
        Vec2(166.0, 13.0),
        Vec2(166.0, 64.0),
      ],
    ),
  );

  // Falcon F16v3 Differential Receiver (standing/vertical mount variant):
  // outline and its 4 mounting holes measured from a user-supplied STL
  // (Falcon_F16v3_Diff_-_Standing.stl). Clean rectangle: 101.75 x 51.45mm
  // hole spacing. The real holes are 4.0mm SQUARES, not round -- modeled
  // here as Ø4.0mm circles to match this project's usual hole
  // representation. Everything else in the mesh is engraved silkscreen
  // text, not reproduced.
  writeTemplate(
    'falcon_f16v3_diff_receiver.json',
    'falcon_f16v3_diff_receiver',
    'Falcon F16v3 Differential Receiver',
    'receiver',
    roundedRectWithHoles(
      width: 140.87,
      height: 100.08,
      holeDiameter: 4.0,
      holeCenters: const [
        Vec2(18.335, 83.779),
        Vec2(120.085, 83.779),
        Vec2(18.335, 32.329),
        Vec2(120.085, 32.329),
      ],
    ),
  );

  writeIndex();
}
