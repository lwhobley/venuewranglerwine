import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

Future<({Uint8List bytes, int width, int height})?> readFloorReference(
  String name,
  Uint8List bytes,
  Future<int?> Function(int count) choosePage,
) async {
  if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
    throw const FormatException('Choose a picture or PDF under 20 MB.');
  }
  if (name.toLowerCase().endsWith('.pdf')) {
    await pdfrxFlutterInitialize();
    final doc = await PdfDocument.openData(bytes);
    try {
      if (doc.pages.isEmpty || doc.pages.length > 200) {
        throw const FormatException('Choose a PDF with 1 to 200 pages.');
      }
      final pageNumber = doc.pages.length == 1
          ? 1
          : await choosePage(doc.pages.length);
      if (pageNumber == null) return null;
      final page = doc.pages[pageNumber - 1];
      final scale = math.min(2048 / page.width, 2048 / page.height);
      final rendered = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (rendered == null) {
        throw const FormatException('This PDF page could not be rendered.');
      }
      try {
        final image = await rendered.createImage();
        try {
          return await _png(image);
        } finally {
          image.dispose();
        }
      } finally {
        rendered.dispose();
      }
    } finally {
      doc.dispose();
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      if (descriptor.width * descriptor.height > 20000000) {
        throw const FormatException(
          'Resize this picture to under 20 megapixels.',
        );
      }
      final scale = math.min(
        1.0,
        2048 / math.max(descriptor.width, descriptor.height),
      );
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round(),
        targetHeight: (descriptor.height * scale).round(),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          return await _png(frame.image);
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

Future<({Uint8List bytes, int width, int height})> _png(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null || data.lengthInBytes > 8 * 1024 * 1024) {
    throw const FormatException('Resize this diagram to a smaller image.');
  }
  return (
    bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    width: image.width,
    height: image.height,
  );
}
