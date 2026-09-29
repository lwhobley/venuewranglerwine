import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'floor_labels_stub.dart' show FloorTableLabel;
export 'floor_labels_stub.dart' show FloorTableLabel;

Future<List<FloorTableLabel>> floorTableLabels(
  Uint8List png,
  int width,
  int height,
) async {
  if (!Platform.isAndroid && !Platform.isIOS) return [];
  final folder = await getTemporaryDirectory();
  final file = File('${folder.path}/floor-label-${const Uuid().v4()}.png');
  final reader = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    await file.writeAsBytes(png, flush: true);
    final result = await reader.processImage(
      InputImage.fromFilePath(file.path),
    );
    final labels = <FloorTableLabel>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final match = RegExp(
          r'^(?:T(?:able)?\s*[-:# ]*)?(\d{1,3}[a-zA-Z]?)$',
          caseSensitive: false,
        ).firstMatch(line.text.trim());
        if (match == null) continue;
        final b = line.boundingBox;
        labels.add(
          FloorTableLabel(
            'T${match.group(1)}',
            (b.left + b.width / 2) / width,
            (b.top + b.height / 2) / height,
            b.width / width,
            b.height / height,
          ),
        );
      }
    }
    return labels;
  } catch (_) {
    return [];
  } finally {
    await reader.close();
    if (await file.exists()) await file.delete();
  }
}
