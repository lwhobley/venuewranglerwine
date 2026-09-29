import 'dart:typed_data';

class FloorTableLabel {
  const FloorTableLabel(this.text, this.x, this.y, this.width, this.height);
  final String text;
  final double x, y, width, height;
}

Future<List<FloorTableLabel>> floorTableLabels(
  Uint8List png,
  int width,
  int height,
) async => [];
