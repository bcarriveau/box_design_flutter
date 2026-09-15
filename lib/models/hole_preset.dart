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

  static const builtIns = <HolePreset>[
    HolePreset(id: 'screw_m3', name: 'M3 Screw (3.2mm)', type: HoleType.screw, diameter: 3.2),
    HolePreset(id: 'screw_m4', name: 'M4 Screw (4.5mm)', type: HoleType.screw, diameter: 4.5),
    HolePreset(id: 'screw_no4', name: '#4 Screw (2.8mm)', type: HoleType.screw, diameter: 2.8),
    HolePreset(id: 'screw_no6', name: '#6 Screw (3.5mm)', type: HoleType.screw, diameter: 3.5),
    HolePreset(id: 'screw_no8', name: '#8 Screw (4.2mm)', type: HoleType.screw, diameter: 4.2),
    HolePreset(id: 'ziptie_small', name: 'Small Zip Tie (2.5x10mm)', type: HoleType.zipTie, slotLength: 10, slotWidth: 2.5),
    HolePreset(id: 'ziptie_standard', name: 'Standard Zip Tie (4x15mm)', type: HoleType.zipTie, slotLength: 15, slotWidth: 4),
    HolePreset(id: 'ziptie_large', name: 'Large Zip Tie (7x20mm)', type: HoleType.zipTie, slotLength: 20, slotWidth: 7),
    HolePreset(id: 'slot_small', name: 'Small Slot (4x12mm)', type: HoleType.slot, slotLength: 12, slotWidth: 4),
    HolePreset(id: 'slot_standard', name: 'Standard Slot (5x16mm)', type: HoleType.slot, slotLength: 16, slotWidth: 5),
    HolePreset(id: 'slot_large', name: 'Large Slot (6x20mm)', type: HoleType.slot, slotLength: 20, slotWidth: 6),
    HolePreset(id: 'rect_small', name: 'Small Rect Slot (10x6mm)', type: HoleType.rectangle, slotLength: 10, slotWidth: 6),
    HolePreset(id: 'rect_standard', name: 'Standard Rect Slot (16x8mm)', type: HoleType.rectangle, slotLength: 16, slotWidth: 8),
    HolePreset(id: 'rect_large', name: 'Large Rect Slot (24x12mm)', type: HoleType.rectangle, slotLength: 24, slotWidth: 12),
  ];
}
