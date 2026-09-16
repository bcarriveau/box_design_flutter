import 'hole.dart';

/// A named, pre-sized hole definition shown in the "Generic Holes" palette
/// section and dropped onto the canvas to create a matching [Hole].
class HolePreset {
  final String id;
  final String name;
  final HoleType type;
  final double diameter;
  final double slotLength;
  final double slotWidth;

  const HolePreset({
    required this.id,
    required this.name,
    required this.type,
    this.diameter = 4.5,
    this.slotLength = 12,
    this.slotWidth = 4,
  });

  factory HolePreset.fromJson(Map<String, dynamic> json) => HolePreset(
        id: json['id'] as String,
        name: json['name'] as String,
        type: HoleType.values.byName(json['type'] as String),
        diameter: (json['diameter'] as num?)?.toDouble() ?? 4.5,
        slotLength: (json['slotLength'] as num?)?.toDouble() ?? 12,
        slotWidth: (json['slotWidth'] as num?)?.toDouble() ?? 4,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'diameter': diameter,
        'slotLength': slotLength,
        'slotWidth': slotWidth,
      };

  static const builtIns = <HolePreset>[
    HolePreset(id: 'screw_m3', name: 'M3 Screw (3.2mm)', type: HoleType.screw, diameter: 3.2),
    HolePreset(id: 'screw_m4', name: 'M4 Screw (4.5mm)', type: HoleType.screw, diameter: 4.5),
    HolePreset(id: 'screw_m5', name: 'M5 Screw (5.5mm)', type: HoleType.screw, diameter: 5.5),
    HolePreset(id: 'screw_m6', name: 'M6 Screw (6.5mm)', type: HoleType.screw, diameter: 6.5),
    HolePreset(id: 'screw_m8', name: 'M8 Screw (9.0mm)', type: HoleType.screw, diameter: 9.0),
    HolePreset(id: 'screw_no4', name: '#4 Screw (2.8mm)', type: HoleType.screw, diameter: 2.8),
    HolePreset(id: 'screw_no6', name: '#6 Screw (3.5mm)', type: HoleType.screw, diameter: 3.5),
    HolePreset(id: 'screw_no8', name: '#8 Screw (4.2mm)', type: HoleType.screw, diameter: 4.2),
    HolePreset(id: 'screw_1_4in', name: '1/4" Screw (6.4mm)', type: HoleType.screw, diameter: 6.4),
    HolePreset(id: 'screw_5_16in', name: '5/16" Screw (7.9mm)', type: HoleType.screw, diameter: 7.9),
    HolePreset(id: 'screw_3_8in', name: '3/8" Screw (9.5mm)', type: HoleType.screw, diameter: 9.5),
    HolePreset(id: 'ziptie_small', name: 'Small Zip Tie (2.5x10mm)', type: HoleType.zipTie, slotLength: 10, slotWidth: 2.5),
    HolePreset(id: 'ziptie_standard', name: 'Standard Zip Tie (4x15mm)', type: HoleType.zipTie, slotLength: 15, slotWidth: 4),
    HolePreset(id: 'ziptie_large', name: 'Large Zip Tie (7x20mm)', type: HoleType.zipTie, slotLength: 20, slotWidth: 7),
    HolePreset(id: 'slot_small', name: 'Small Slot (4x12mm)', type: HoleType.slot, slotLength: 12, slotWidth: 4),
    HolePreset(id: 'slot_standard', name: 'Standard Slot (5x16mm)', type: HoleType.slot, slotLength: 16, slotWidth: 5),
    HolePreset(id: 'slot_large', name: 'Large Slot (6x20mm)', type: HoleType.slot, slotLength: 20, slotWidth: 6),
    HolePreset(id: 'rect_small', name: 'Small Rect Slot (10x6mm)', type: HoleType.rectangle, slotLength: 10, slotWidth: 6),
    HolePreset(id: 'rect_standard', name: 'Standard Rect Slot (16x8mm)', type: HoleType.rectangle, slotLength: 16, slotWidth: 8),
    HolePreset(id: 'rect_large', name: 'Large Rect Slot (24x12mm)', type: HoleType.rectangle, slotLength: 24, slotWidth: 12),
    // 0.1"/2.54mm pitch 2-row shrouded box headers (ribbon/IDC connectors),
    // sized to the header body's overall footprint plus a little cutout
    // clearance so the shroud passes through a panel.
    HolePreset(id: 'idc_24', name: '24-Pin IDC Slot (37x10mm)', type: HoleType.rectangle, slotLength: 37, slotWidth: 10),
    HolePreset(id: 'idc_40', name: '40-Pin IDC Slot (57x10mm)', type: HoleType.rectangle, slotLength: 57, slotWidth: 10),
  ];
}
