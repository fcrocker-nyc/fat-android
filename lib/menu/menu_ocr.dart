import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show Rect;

import 'package:flutter/painting.dart' show Paint;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'menu_interpreter.dart';
import 'menu_models.dart';

/// Menu-specific OCR (port of iOS MenuOCRService). Keeps each line's box so
/// the segmenter can resolve columns and right-aligned prices.
///
/// 1. A Latin pass of the whole page.
/// 2. Large or dense pages are re-read in pieces cut at column and row gaps,
///    so small print ("Filet Mignon", "Tenderloin") isn't garbled.
/// 3. Korean and Japanese passes, so subtitles in those scripts come back as
///    real characters (which the reader drops) instead of Latin junk. They only
///    replace lines that actually contain those scripts.
class MenuOCR {
  static Future<MenuPage> recognize(String imagePath, int pageIndex) async {
    final bytes = await File(imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    final w = image.width, h = image.height;

    var latin = await _pass(imagePath, TextRecognitionScript.latin, w.toDouble(), h.toDouble());
    if (latin.isEmpty) throw StateError('No text found');

    final tiles = MenuOCRMerge.tiles(latin, w, h);
    if (tiles.length > 1) {
      final tiled = <MenuOCRLine>[];
      final dir = await getTemporaryDirectory();
      for (var i = 0; i < tiles.length; i++) {
        final t = tiles[i];
        // Normalized bottom-left tile → pixel top-left crop.
        final px = Rect.fromLTRB(t.left * w, (1 - t.bottom) * h, t.right * w, (1 - t.top) * h);
        final path = '${dir.path}/menu_tile_${pageIndex}_$i.png';
        await _crop(image, px, path);
        final tw = t.right - t.left, th = t.bottom - t.top;
        for (final l in await _pass(path, TextRecognitionScript.latin, px.width, px.height)) {
          tiled.add(MenuOCRLine(
              l.text,
              Rect.fromLTRB(t.left + l.minX * tw, t.top + l.minY * th, t.left + l.maxX * tw, t.top + l.maxY * th)));
        }
        try {
          await File(path).delete();
        } catch (_) {}
      }
      latin = MenuOCRMerge.preferTiled(latin, tiled, tiles);
    }

    final cjk = <MenuOCRLine>[];
    for (final script in [TextRecognitionScript.korean, TextRecognitionScript.japanese]) {
      try {
        cjk.addAll(await _pass(imagePath, script, w.toDouble(), h.toDouble()));
      } catch (_) {/* model unavailable on this device: Latin only */}
    }
    image.dispose();
    return MenuPage(pageIndex, MenuOCRMerge.merge(latin, cjk));
  }

  /// One ML Kit pass, boxes normalized to the image (0…1, bottom-left origin).
  static Future<List<MenuOCRLine>> _pass(String path, TextRecognitionScript script, double w, double h) async {
    final recognizer = TextRecognizer(script: script);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      return [
        for (final block in result.blocks)
          for (final line in block.lines)
            if (line.text.trim().isNotEmpty)
              MenuOCRLine(
                line.text,
                Rect.fromLTRB(line.boundingBox.left / w, 1.0 - line.boundingBox.bottom / h,
                    line.boundingBox.right / w, 1.0 - line.boundingBox.top / h),
              )
      ];
    } finally {
      await recognizer.close();
    }
  }

  static Future<void> _crop(ui.Image image, Rect px, String path) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(image, px, Rect.fromLTWH(0, 0, px.width, px.height), Paint());
    final cropped = await recorder.endRecording().toImage(px.width.round(), px.height.round());
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    await File(path).writeAsBytes(data!.buffer.asUint8List());
  }
}
