import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'menu_models.dart';

/// Menu-specific OCR. Unlike the label scanner it keeps each line's bounding
/// box so the segmenter can resolve multi-column layouts and right-aligned
/// prices. The label OCR path is left untouched.
class MenuOCR {
  static Future<MenuPage> recognize(String imagePath, int pageIndex) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final raw = <(String, Rect)>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          if (line.text.trim().isEmpty) continue;
          raw.add((line.text, line.boundingBox));
        }
      }
      if (raw.isEmpty) throw StateError('No text found');
      // Normalize against the union of all boxes: ML Kit boxes are in image
      // pixels (top-left origin) and the segmenter wants 0…1 bottom-left.
      var l = raw.first.$2.left, t = raw.first.$2.top, r = raw.first.$2.right, b = raw.first.$2.bottom;
      for (final (_, rect) in raw) {
        if (rect.left < l) l = rect.left;
        if (rect.top < t) t = rect.top;
        if (rect.right > r) r = rect.right;
        if (rect.bottom > b) b = rect.bottom;
      }
      final w = (r - l) <= 0 ? 1.0 : (r - l);
      final h = (b - t) <= 0 ? 1.0 : (b - t);
      final lines = [
        for (final (text, rect) in raw)
          MenuOCRLine(
            text,
            Rect.fromLTRB(
              (rect.left - l) / w,
              1.0 - (rect.bottom - t) / h,
              (rect.right - l) / w,
              1.0 - (rect.top - t) / h,
            ),
          )
      ];
      return MenuPage(pageIndex, lines);
    } finally {
      await recognizer.close();
    }
  }
}
