import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/features/floor_plan/data/floor_detection.dart';

Uint8List raster(int width, int height, bool Function(int x, int y) dark) {
  final pixels = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      pixels[i] = pixels[i + 1] = pixels[i + 2] = dark(x, y) ? 0 : 255;
      pixels[i + 3] = 255;
    }
  }
  return pixels;
}

void main() {
  test('diagram finds rectangular and round tables, excludes room walls and tiny text', () {
    final pixels = raster(400, 300, (x, y) {
      final rectangle =
          x >= 40 &&
          x <= 120 &&
          y >= 50 &&
          y <= 110 &&
          (x <= 43 || x >= 117 || y <= 53 || y >= 107);
      final radius = (x - 250) * (x - 250) + (y - 100) * (y - 100);
      final circle = radius >= 27 * 27 && radius <= 30 * 30;
      final wall = x < 3 || y < 3 || x > 396 || y > 296;
      final text = x >= 180 && x <= 185 && y >= 190 && y <= 197;
      return rectangle || circle || wall || text;
    });
    final results = findFloorOutlines((
      pixels: pixels,
      width: 400,
      height: 300,
    ));
    expect(results, hasLength(2));
    expect(results.first.shape, 'rectangle');
    expect(results.last.shape, 'round');
    expect(results.first.x, closeTo(.1, .005));
    expect(results.first.width, closeTo(.2, .005));
  });
  test(
    'filled square is rectangular and blank pictures have no suggestions',
    () {
      final pixels = raster(
        400,
        300,
        (x, y) => x >= 50 && x <= 110 && y >= 50 && y <= 110,
      );
      expect(
        findFloorOutlines((pixels: pixels, width: 400, height: 300))
            .single
            .shape,
        'rectangle',
      );
      expect(
        findFloorOutlines((
          pixels: raster(400, 300, (_, _) => false),
          width: 400,
          height: 300,
        )),
        isEmpty,
      );
    },
  );
  testWidgets(
    'PNG decoding and background isolate return reviewable proposals',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(Colors.white, BlendMode.src);
        canvas.drawRect(
          const Rect.fromLTWH(50, 50, 80, 60),
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(400, 300);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final results = await suggestFloorTables(bytes!.buffer.asUint8List());
          expect(results, hasLength(1));
          expect(results.single.shape, 'rectangle');
          expect(results.single.confidence, greaterThan(.5));
        } finally {
          image.dispose();
          picture.dispose();
        }
      });
    },
  );
}
