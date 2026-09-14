import 'package:flutter_test/flutter_test.dart';
import 'package:box_design_flutter/models/dxf_entity.dart';
import 'package:box_design_flutter/models/vec2.dart';
import 'package:box_design_flutter/dxf/dxf_parser.dart';
import 'package:box_design_flutter/dxf/dxf_writer.dart';
import 'package:box_design_flutter/dxf/dxf_json_codec.dart';

void main() {
  group('Vec2', () {
    test('rotated 90 degrees around origin', () {
      final p = const Vec2(1, 0).rotated(90);
      expect(p.x, closeTo(0, 1e-9));
      expect(p.y, closeTo(1, 1e-9));
    });

    test('rotated around a pivot then translated matches transformed()', () {
      const line = DxfLine(Vec2(0, 0), Vec2(10, 0));
      final t = line.transformed(delta: const Vec2(5, 5), rotationDeg: 90);
      expect(t.start.x, closeTo(5, 1e-9));
      expect(t.start.y, closeTo(5, 1e-9));
      expect(t.end.x, closeTo(5, 1e-9));
      expect(t.end.y, closeTo(15, 1e-9));
    });
  });

  group('DXF write/parse round-trip', () {
    test('LINE, CIRCLE, ARC, LWPOLYLINE survive a round trip', () {
      final entities = <DxfEntity>[
        const DxfLine(Vec2(0, 0), Vec2(100, 0)),
        const DxfCircle(Vec2(50, 25), 5),
        const DxfArc(Vec2(50, 25), 10, 0, 180),
        const DxfPolyline([
          PolyVertex(Vec2(0, 0)),
          PolyVertex(Vec2(100, 0)),
          PolyVertex(Vec2(100, 50)),
          PolyVertex(Vec2(0, 50)),
        ], closed: true),
      ];

      final dxfText = writeDxf(entities);
      expect(dxfText, contains('SECTION'));
      expect(dxfText, contains('ENTITIES'));
      expect(dxfText, contains('EOF'));

      final parsed = parseDxf(dxfText);
      expect(parsed.length, entities.length);

      final line = parsed[0] as DxfLine;
      expect(line.start.x, closeTo(0, 1e-6));
      expect(line.end.x, closeTo(100, 1e-6));

      final circle = parsed[1] as DxfCircle;
      expect(circle.center.x, closeTo(50, 1e-6));
      expect(circle.radius, closeTo(5, 1e-6));

      final arc = parsed[2] as DxfArc;
      expect(arc.radius, closeTo(10, 1e-6));
      expect(arc.startAngleDeg, closeTo(0, 1e-6));
      expect(arc.endAngleDeg, closeTo(180, 1e-6));

      final poly = parsed[3] as DxfPolyline;
      expect(poly.closed, isTrue);
      expect(poly.vertices.length, 4);
      expect(poly.vertices[2].point.y, closeTo(50, 1e-6));
    });

    test('LWPOLYLINE with a bulge round-trips the bulge value', () {
      final entities = <DxfEntity>[
        const DxfPolyline([
          PolyVertex(Vec2(0, 0), bulge: 1.0),
          PolyVertex(Vec2(10, 0)),
        ]),
      ];
      final parsed = parseDxf(writeDxf(entities));
      final poly = parsed.single as DxfPolyline;
      expect(poly.vertices[0].bulge, closeTo(1.0, 1e-6));
    });

    test('a bulge of 1.0 (semicircle) tessellates through the expected midpoint', () {
      const poly = DxfPolyline([
        PolyVertex(Vec2(0, 0), bulge: 1.0),
        PolyVertex(Vec2(2, 0)),
      ]);
      final points = poly.toPoints(arcSegments: 64);
      final mid = points[points.length ~/ 2];
      // Semicircle bulging from (0,0) to (2,0) passes near (1, +/-1).
      expect(mid.x, closeTo(1, 0.05));
      expect(mid.y.abs(), closeTo(1, 0.05));
    });
  });

  group('JSON codec round-trip', () {
    test('entitiesToJson / entitiesFromJson preserve geometry', () {
      final entities = <DxfEntity>[
        const DxfLine(Vec2(1, 2), Vec2(3, 4)),
        const DxfCircle(Vec2(5, 6), 7),
        const DxfArc(Vec2(1, 1), 2, 10, 200),
        const DxfPolyline([
          PolyVertex(Vec2(0, 0), bulge: 0.5),
          PolyVertex(Vec2(10, 10)),
        ], closed: false),
      ];

      final json = entitiesToJson(entities);
      final restored = entitiesFromJson(json);

      expect(restored.length, entities.length);
      final restoredArc = restored[2] as DxfArc;
      expect(restoredArc.endAngleDeg, closeTo(200, 1e-9));
      final restoredPoly = restored[3] as DxfPolyline;
      expect(restoredPoly.vertices[0].bulge, closeTo(0.5, 1e-9));
      expect(restoredPoly.closed, isFalse);
    });
  });
}
