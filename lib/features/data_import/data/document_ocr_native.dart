import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/import_parser.dart';

Future<String> recognizeImportImage(Uint8List bytes, String extension) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw const FormatException(
      'Photo and scanned-PDF recognition is available in the Android and iOS app.',
    );
  }
  final directory = await getTemporaryDirectory();
  final file = File(
    '${directory.path}/venue-import-${const Uuid().v4()}.$extension',
  );
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    await file.writeAsBytes(bytes, flush: true);
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(file.path),
    );
    final atoms = <PositionedImportText>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final box = element.boundingBox;
          atoms.add(
            PositionedImportText(
              element.text,
              box.left,
              box.top,
              box.right,
              box.height,
            ),
          );
        }
      }
    }
    final result = positionedImportText(atoms);
    if (result.trim().isEmpty) {
      throw const FormatException(
        'No readable text found. Use a sharper, straight-on photo.',
      );
    }
    return result;
  } finally {
    await recognizer.close();
    if (await file.exists()) await file.delete();
  }
}
