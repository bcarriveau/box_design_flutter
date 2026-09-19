import 'dart:math' as math;
import 'dart:typed_data';

/// Board outline found in a reference image, in image pixels (Y down).
class DetectedOutline {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const DetectedOutline(this.left, this.top, this.right, this.bottom);

  double get width => right - left;
  double get height => bottom - top;
}

enum DetectedHoleShape { round, slot, rect }

/// A hole found inside the outline, in image pixels (Y down). For [round],
/// [length] is the diameter and [width] the same; for slots/rects [length]
/// is the long side and [rotationDeg] the long axis' angle, counter-clockwise
/// as seen on screen (already in Y-up math convention), snapped to 0/90.
class DetectedHole {
  final DetectedHoleShape shape;
  final double cx;
  final double cy;
  final double length;
  final double width;
  final double rotationDeg;

  const DetectedHole(this.shape, this.cx, this.cy, this.length, this.width, this.rotationDeg);
}

class ImageDetection {
  final DetectedOutline outline;
  final List<DetectedHole> holes;

  const ImageDetection(this.outline, this.holes);
}

const int _fillThreshold = 24;
const int _inkThreshold = 70;

/// Finds the board outline and its holes in a screenshot/drawing: the board
/// is the biggest blob that differs from the page background, and holes are
/// the compact background-coloured regions fully enclosed by it. Holes are
/// classified round / slot / rectangle from how much of their bounding box
/// they fill. [outlineWidthMm]/[outlineHeightMm] (the template's outline) set
/// the size limits for what counts as a hole. Returns null when no board
/// could be found.
ImageDetection? detectBoardAndHoles(Uint8List rgba, int w, int h, {double outlineWidthMm = 100, double outlineHeightMm = 100}) {
  if (w < 8 || h < 8 || rgba.length < w * h * 4) return null;

  final bg = _backgroundColor(rgba, w, h);
  // Two views of the image: "ink" (strongly different from the page --
  // outline and hole strokes) and "fill" (anything even slightly different,
  // e.g. a tinted board face). Drawings with stroked outlines use the ink
  // view, which ignores tinted fills, grid lines and soft UI shadows; a
  // stroke-less picture falls back to the fill view.
  final inkMask = Uint8List(w * h);
  final fillMask = Uint8List(w * h);
  for (var i = 0; i < w * h; i++) {
    final o = i * 4;
    if (rgba[o + 3] <= 40) continue; // transparent = background
    final d = math.max(
      (rgba[o] - bg[0]).abs(),
      math.max((rgba[o + 1] - bg[1]).abs(), (rgba[o + 2] - bg[2]).abs()),
    );
    if (d > _fillThreshold) fillMask[i] = 1;
    if (d > _inkThreshold) inkMask[i] = 1;
  }

  final ink = _largestComponent(inkMask, 1, w, h, Int32List(w * h));
  final fill = _largestComponent(fillMask, 1, w, h, Int32List(w * h));
  final _Component? board;
  final Uint8List fg;
  if (ink != null && (fill == null || ink.bboxArea >= 0.25 * fill.bboxArea)) {
    board = ink;
    fg = inkMask;
  } else {
    board = fill;
    fg = fillMask;
  }
  if (board == null) return null;

  // Inset by ~1px: the outline stroke is a couple of pixels thick and the
  // real edge is its centre.
  final outline = DetectedOutline(
    board.minX + 1.0,
    board.minY + 1.0,
    board.maxX + 1.0 - 1.0,
    board.maxY + 1.0 - 1.0,
  );
  if (outline.width < 10 || outline.height < 10) return null;

  // Label background regions inside the board's bounding box.
  final x0 = board.minX, x1 = board.maxX, y0 = board.minY, y1 = board.maxY;
  final bw = x1 - x0 + 1, bh = y1 - y0 + 1;
  final bgLabels = Int32List(bw * bh); // 0 = unvisited/foreground, >0 label
  final stack = Int32List(bw * bh);
  final holes = <DetectedHole>[];
  var nextLabel = 0;

  // Rough px-per-mm using the board bounding box, only for size gating.
  final pxPerMmX = bw / outlineWidthMm;
  final pxPerMmY = bh / outlineHeightMm;
  final pxPerMm = math.sqrt(pxPerMmX * pxPerMmY);
  final outlineAreaMm2 = outlineWidthMm * outlineHeightMm;

  for (var sy = 0; sy < bh; sy++) {
    for (var sx = 0; sx < bw; sx++) {
      final si = sy * bw + sx;
      if (bgLabels[si] != 0) continue;
      final gi = (y0 + sy) * w + (x0 + sx);
      if (fg[gi] == 1) continue;
      nextLabel++;
      var sp = 0;
      stack[sp++] = si;
      bgLabels[si] = nextLabel;
      var area = 0, touchesEdge = false;
      var minX = sx, maxX = sx, minY = sy, maxY = sy;
      var sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumYY = 0.0, sumXY = 0.0;
      final pixels = <int>[];
      while (sp > 0) {
        final p = stack[--sp];
        final px = p % bw, py = p ~/ bw;
        area++;
        pixels.add(p);
        sumX += px;
        sumY += py;
        sumXX += px * px;
        sumYY += py * py;
        sumXY += px * py;
        if (px < minX) minX = px;
        if (px > maxX) maxX = px;
        if (py < minY) minY = py;
        if (py > maxY) maxY = py;
        if (px == 0 || py == 0 || px == bw - 1 || py == bh - 1) touchesEdge = true;
        void visit(int nx, int ny) {
          if (nx < 0 || ny < 0 || nx >= bw || ny >= bh) return;
          final ni = ny * bw + nx;
          if (bgLabels[ni] != 0) return;
          if (fg[(y0 + ny) * w + (x0 + nx)] == 1) return;
          bgLabels[ni] = nextLabel;
          stack[sp++] = ni;
        }

        visit(px - 1, py);
        visit(px + 1, py);
        visit(px, py - 1);
        visit(px, py + 1);
      }
      if (touchesEdge) continue;

      // Holes are enclosed by an outline stroke about 1px thick on each side
      // that isn't part of the region itself: grow the measured extent by 1px.
      final cw = maxX - minX + 1 + 2.0, ch = maxY - minY + 1 + 2.0;
      final areaGrown = area + 2.0 * (cw + ch - 2) * 0.5;
      final mmW = cw / pxPerMm, mmH = ch / pxPerMm;
      if (math.min(mmW, mmH) < 1.2) continue;
      if (areaGrown / (pxPerMm * pxPerMm) > outlineAreaMm2 * 0.012) continue;

      final cx = sumX / area + x0 + 0.5, cy = sumY / area + y0 + 0.5;
      final fill = areaGrown / (cw * ch);

      // Second moments (about the centroid) for elongation / orientation.
      final mx = sumX / area, my = sumY / area;
      final vxx = sumXX / area - mx * mx, vyy = sumYY / area - my * my, vxy = sumXY / area - mx * my;
      final tr = vxx + vyy, det = vxx * vyy - vxy * vxy;
      final disc = math.sqrt(math.max(tr * tr / 4 - det, 0));
      final l1 = tr / 2 + disc, l2 = math.max(tr / 2 - disc, 1e-9);
      final elong = math.sqrt(l1 / l2);

      if (elong < 1.18) {
        // Roughly equal sides: a circle or a square.
        if (fill >= 0.86) {
          holes.add(DetectedHole(DetectedHoleShape.rect, cx, cy, math.max(cw, ch), math.min(cw, ch), 0));
        } else if (fill >= 0.70) {
          final d = math.sqrt(4 * areaGrown / math.pi);
          holes.add(DetectedHole(DetectedHoleShape.round, cx, cy, d, d, 0));
        }
        continue;
      }

      // Elongated: measure along the principal axis.
      final theta = 0.5 * math.atan2(2 * vxy, vxx - vyy); // long axis, image coords
      final ct = math.cos(theta), st = math.sin(theta);
      var minU = double.infinity, maxU = -double.infinity, minV = double.infinity, maxV = -double.infinity;
      for (final p in pixels) {
        final dx = p % bw - mx, dy = p ~/ bw - my;
        final u = dx * ct + dy * st, v = -dx * st + dy * ct;
        if (u < minU) minU = u;
        if (u > maxU) maxU = u;
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      final len = maxU - minU + 1 + 2.0, wid = maxV - minV + 1 + 2.0;
      final rectFill = areaGrown / (len * wid);
      if (rectFill < 0.74) continue;
      var deg = -theta * 180 / math.pi; // image Y is down -> math angle
      while (deg > 90) {
        deg -= 180;
      }
      while (deg <= -90) {
        deg += 180;
      }
      if (deg.abs() < 4) deg = 0;
      if ((deg.abs() - 90).abs() < 4) deg = 90;
      holes.add(DetectedHole(
        rectFill >= 0.94 ? DetectedHoleShape.rect : DetectedHoleShape.slot,
        cx,
        cy,
        len,
        wid,
        deg,
      ));
    }
  }

  return ImageDetection(outline, holes);
}

List<int> _backgroundColor(Uint8List rgba, int w, int h) {
  final counts = <int, int>{};
  void sample(int x, int y) {
    final o = (y * w + x) * 4;
    if (rgba[o + 3] < 40) return;
    final key = ((rgba[o] >> 3) << 10) | ((rgba[o + 1] >> 3) << 5) | (rgba[o + 2] >> 3);
    counts[key] = (counts[key] ?? 0) + 1;
  }

  const t = 3;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (x < t || y < t || x >= w - t || y >= h - t) sample(x, y);
    }
  }
  if (counts.isEmpty) return [255, 255, 255];
  final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  // Average the actual pixels in that bucket for a precise colour.
  var r = 0, g = 0, b = 0, n = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!(x < t || y < t || x >= w - t || y >= h - t)) continue;
      final o = (y * w + x) * 4;
      final key = ((rgba[o] >> 3) << 10) | ((rgba[o + 1] >> 3) << 5) | (rgba[o + 2] >> 3);
      if (key != best) continue;
      r += rgba[o];
      g += rgba[o + 1];
      b += rgba[o + 2];
      n++;
    }
  }
  return [r ~/ n, g ~/ n, b ~/ n];
}

class _Component {
  final int label;
  final int minX, minY, maxX, maxY;
  final int area;

  const _Component(this.label, this.minX, this.minY, this.maxX, this.maxY, this.area);

  int get bboxArea => (maxX - minX + 1) * (maxY - minY + 1);
}

_Component? _largestComponent(Uint8List mask, int value, int w, int h, Int32List labels) {
  final stack = Int32List(w * h);
  var next = 0;
  _Component? best;
  for (var s = 0; s < w * h; s++) {
    if (mask[s] != value || labels[s] != 0) continue;
    next++;
    var sp = 0;
    stack[sp++] = s;
    labels[s] = next;
    var area = 0;
    var minX = w, minY = h, maxX = 0, maxY = 0;
    while (sp > 0) {
      final p = stack[--sp];
      final x = p % w, y = p ~/ w;
      area++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      if (x > 0 && mask[p - 1] == value && labels[p - 1] == 0) {
        labels[p - 1] = next;
        stack[sp++] = p - 1;
      }
      if (x < w - 1 && mask[p + 1] == value && labels[p + 1] == 0) {
        labels[p + 1] = next;
        stack[sp++] = p + 1;
      }
      if (y > 0 && mask[p - w] == value && labels[p - w] == 0) {
        labels[p - w] = next;
        stack[sp++] = p - w;
      }
      if (y < h - 1 && mask[p + w] == value && labels[p + w] == 0) {
        labels[p + w] = next;
        stack[sp++] = p + w;
      }
    }
    if (best == null || area > best.area) best = _Component(next, minX, minY, maxX, maxY, area);
  }
  return best;
}
