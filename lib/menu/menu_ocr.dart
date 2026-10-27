import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Offset, Rect;

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
    var image = (await codec.getNextFrame()).image;
    var w = image.width, h = image.height;
    var path = imagePath;
    final dir = await getTemporaryDirectory();
    String? levelPath;

    try {
      final quads = <(Offset, Offset, Offset)>[];
      var latin = await _pass(path, TextRecognitionScript.latin, w.toDouble(), h.toDouble(), quads);
      if (latin.isEmpty) throw StateError('No text found');

      // A tilted photo: level the page and read it again, so line boxes, dish
      // gaps and the tiles below all line up.
      final theta = MenuOCRDeskew.tilt(quads, w.toDouble(), h.toDouble());
      if (theta != null) {
        final level = await _rotated(image, theta);
        image.dispose();
        image = level;
        w = image.width;
        h = image.height;
        levelPath = '${dir.path}/menu_level_$pageIndex.png';
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(levelPath).writeAsBytes(data!.buffer.asUint8List());
        path = levelPath;
        latin = await _pass(path, TextRecognitionScript.latin, w.toDouble(), h.toDouble());
      }

      final tiles = MenuOCRMerge.tiles(latin, w, h);
      if (tiles.length > 1) {
        final tiled = <MenuOCRLine>[];
        for (var i = 0; i < tiles.length; i++) {
          final t = tiles[i];
          // Normalized bottom-left tile → pixel top-left crop.
          final px = Rect.fromLTRB(t.left * w, (1 - t.bottom) * h, t.right * w, (1 - t.top) * h);
          final tilePath = '${dir.path}/menu_tile_${pageIndex}_$i.png';
          await _crop(image, px, tilePath);
          final tw = t.right - t.left, th = t.bottom - t.top;
          for (final l in await _pass(tilePath, TextRecognitionScript.latin, px.width, px.height)) {
            tiled.add(MenuOCRLine(
                l.text,
                Rect.fromLTRB(t.left + l.minX * tw, t.top + l.minY * th, t.left + l.maxX * tw, t.top + l.maxY * th)));
          }
          try {
            await File(tilePath).delete();
          } catch (_) {}
        }
        latin = MenuOCRMerge.preferTiled(latin, tiled, tiles);
      }

      final cjk = <MenuOCRLine>[];
      for (final script in [TextRecognitionScript.korean, TextRecognitionScript.japanese]) {
        try {
          cjk.addAll(await _pass(path, script, w.toDouble(), h.toDouble()));
        } catch (_) {/* model unavailable on this device: Latin only */}
      }
      return MenuPage(pageIndex, MenuOCRMerge.merge(latin, cjk));
    } finally {
      image.dispose();
      if (levelPath != null) {
        try {
          await File(levelPath).delete();
        } catch (_) {}
      }
    }
  }

  /// [image] rotated by [radians] (clockwise on screen) on a canvas big enough
  /// to keep the corners, with a white background.
  static Future<ui.Image> _rotated(ui.Image image, double radians) async {
    final w = image.width.toDouble(), h = image.height.toDouble();
    final nw = (w * math.cos(radians).abs() + h * math.sin(radians).abs()).ceilToDouble();
    final nh = (w * math.sin(radians).abs() + h * math.cos(radians).abs()).ceilToDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, nw, nh), Paint()..color = const ui.Color(0xFFFFFFFF));
    canvas.translate(nw / 2, nh / 2);
    canvas.rotate(radians);
    canvas.drawImage(image, Offset(-w / 2, -h / 2), Paint()..filterQuality = ui.FilterQuality.high);
    return recorder.endRecording().toImage(nw.toInt(), nh.toInt());
  }

  /// One ML Kit pass, boxes normalized to the image (0…1, bottom-left origin).
  /// [quads] receives each line's (topLeft, topRight, bottomLeft) corners in
  /// the same frame, for measuring tilt.
  static Future<List<MenuOCRLine>> _pass(String path, TextRecognitionScript script, double w, double h,
      [List<(Offset, Offset, Offset)>? quads]) async {
    final recognizer = TextRecognizer(script: script);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      final lines = <MenuOCRLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          if (line.text.trim().isEmpty) continue;
          lines.add(MenuOCRLine(
            line.text,
            Rect.fromLTRB(line.boundingBox.left / w, 1.0 - line.boundingBox.bottom / h,
                line.boundingBox.right / w, 1.0 - line.boundingBox.top / h),
          ));
          // Corner points run clockwise from the top-left, in pixels, y down.
          final c = line.cornerPoints;
          if (quads != null && c.length == 4) {
            Offset n(math.Point<int> p) => Offset(p.x / w, 1.0 - p.y / h);
            quads.add((n(c[0]), n(c[1]), n(c[3])));
          }
        }
      }
      return lines;
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
