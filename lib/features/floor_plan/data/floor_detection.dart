import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'floor_labels.dart';

class FloorSuggestion {
  const FloorSuggestion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.shape,
    required this.confidence,
    this.label,
  });

  /// Coordinates are fractions of the reference image, not device pixels.
  final double x, y, width, height, confidence;
  final String shape;
  final String? label;
  FloorSuggestion withLabel(String value) => FloorSuggestion(
    x: x,
    y: y,
    width: width,
    height: height,
    shape: shape,
    confidence: confidence,
    label: value,
  );
}

Future<List<FloorSuggestion>> suggestFloorTables(Uint8List png) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(png);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final scale = math.min(
        1.0,
        900 / math.max(descriptor.width, descriptor.height),
      );
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final raw = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (raw == null) return [];
          final detected = await compute(findFloorOutlines, (
            pixels: raw.buffer.asUint8List(
              raw.offsetInBytes,
              raw.lengthInBytes,
            ),
            width: frame.image.width,
            height: frame.image.height,
          ));
          final labels = await floorTableLabels(
            png,
            descriptor.width,
            descriptor.height,
          );
          final suggestions = <FloorSuggestion>[];
          for (final candidate in detected) {
            final label = labels
                .where(
                  (l) =>
                      l.x >= candidate.x &&
                      l.x <= candidate.x + candidate.width &&
                      l.y >= candidate.y &&
                      l.y <= candidate.y + candidate.height,
                )
                .firstOrNull;
            suggestions.add(
              label == null ? candidate : candidate.withLabel(label.text),
            );
          }
          // A connected room outline can hide table boundaries. Numbered labels provide review-only estimates.
          for (final label in labels) {
            if (suggestions.any(
              (c) =>
                  label.x >= c.x &&
                  label.x <= c.x + c.width &&
                  label.y >= c.y &&
                  label.y <= c.y + c.height,
            )) {
              continue;
            }
            final w = math.max(.045, label.width * 3).clamp(.025, .2),
                h = math.max(.035, label.height * 4).clamp(.025, .2);
            suggestions.add(
              FloorSuggestion(
                x: (label.x - w / 2).clamp(0, 1 - w),
                y: (label.y - h / 2).clamp(0, 1 - h),
                width: w,
                height: h,
                shape: 'rectangle',
                confidence: .35,
                label: label.text,
              ),
            );
          }
          return suggestions.take(50).toList();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

/// Conservative outline/surface proposals. Every result requires human review.
List<FloorSuggestion> findFloorOutlines(
  ({Uint8List pixels, int width, int height}) input,
) {
  final w = input.width, h = input.height;
  if (w < 40 || h < 40 || input.pixels.length != w * h * 4) return [];
  final gray = Uint8List(w * h), hist = List<int>.filled(256, 0);
  for (var i = 0; i < gray.length; i++) {
    final o = i * 4, a = input.pixels[o + 3] / 255;
    final value =
        ((input.pixels[o] * .299 +
                        input.pixels[o + 1] * .587 +
                        input.pixels[o + 2] * .114) *
                    a +
                255 * (1 - a))
            .round();
    gray[i] = value;
    hist[value]++;
  }
  var sum = 0, background = 255;
  for (var i = 255; i >= 0; i--) {
    sum += hist[i];
    if (sum >= gray.length * .4) {
      background = i;
      break;
    }
  }
  final threshold = (background - 35).clamp(35, 210);
  final seen = Uint8List(w * h), queue = Int32List(w * h);
  final candidates = <FloorSuggestion>[];
  for (var seed = 0; seed < gray.length; seed++) {
    if (seen[seed] != 0 || gray[seed] > threshold) continue;
    var head = 0,
        tail = 1,
        minX = seed % w,
        maxX = minX,
        minY = seed ~/ w,
        maxY = minY;
    queue[0] = seed;
    seen[seed] = 1;
    while (head < tail) {
      final i = queue[head++], x = i % w, y = i ~/ w;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final ni = ny * w + nx;
          if (seen[ni] == 0 && gray[ni] <= threshold) {
            seen[ni] = 1;
            queue[tail++] = ni;
          }
        }
      }
    }
    final bw = maxX - minX + 1,
        bh = maxY - minY + 1,
        area = bw * bh,
        ratio = bw / bh,
        fill = tail / area;
    if (bw < math.max(20, w * .02) ||
        bh < math.max(20, h * .02) ||
        area > w * h * .16 ||
        bw > w * .55 ||
        bh > h * .55 ||
        ratio < .28 ||
        ratio > 3.6 ||
        tail < 40 ||
        fill < .025) {
      continue;
    }
    // Long wall segments and tiny chair outlines should not become dining tables.
    final edgeX = math.max(1, (bw * .12).round()),
        edgeY = math.max(1, (bh * .12).round());
    var top = 0, bottom = 0, left = 0, right = 0, corner = 0;
    for (var j = 0; j < tail; j++) {
      final x = queue[j] % w, y = queue[j] ~/ w;
      if (y < minY + edgeY) top++;
      if (y > maxY - edgeY) bottom++;
      if (x < minX + edgeX) left++;
      if (x > maxX - edgeX) right++;
      if ((x < minX + edgeX || x > maxX - edgeX) &&
          (y < minY + edgeY || y > maxY - edgeY)) {
        corner++;
      }
    }
    final balanced =
        math.min(math.min(top, bottom), math.min(left, right)) / tail;
    if (balanced < .04) continue;
    final round =
        fill < .9 && ratio > .72 && ratio < 1.38 && corner / tail < .08;
    final confidence =
        (.45 + math.min(.3, balanced * 1.5) + (fill < .45 ? .12 : 0)).clamp(
          0.0,
          .9,
        );
    candidates.add(
      FloorSuggestion(
        x: minX / w,
        y: minY / h,
        width: bw / w,
        height: bh / h,
        shape: round
            ? 'round'
            : ratio > 2.3
            ? 'bar'
            : 'rectangle',
        confidence: confidence,
      ),
    );
  }
  candidates.sort((a, b) {
    final y = a.y.compareTo(b.y);
    return y == 0 ? a.x.compareTo(b.x) : y;
  });
  return candidates.take(50).toList();
}
