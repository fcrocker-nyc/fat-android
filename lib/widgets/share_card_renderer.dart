import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/fat_models.dart';
import 'disclosure_share_card.dart';

/// Renders a [DisclosureShareCard] for [result] off-screen into a PNG and hands
/// it to the platform share sheet via `share_plus` — the Android analogue of the
/// iOS `UIView.snapshot()` + `ShareSheet` flow.
///
/// The card is mounted in a temporary [OverlayEntry] positioned far off-screen
/// (so it lays out and paints without ever being visible), captured through a
/// [RenderRepaintBoundary], written to the temp directory, and shared.
///
/// Returns `true` if the image was rendered and the share sheet invoked;
/// `false` on any failure so callers can fall back to the text share.
Future<bool> shareDisclosureCard(
  BuildContext context,
  FATResult result, {
  String? shareText,
}) async {
  OverlayEntry? entry;
  try {
    final overlay = Overlay.of(context, rootOverlay: true);
    final boundaryKey = GlobalKey();

    entry = OverlayEntry(
      builder: (_) => Positioned(
        // Far off the visible viewport — still laid out and painted.
        left: -10000,
        top: 0,
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(
            key: boundaryKey,
            child: DisclosureShareCard(result: result),
          ),
        ),
      ),
    );
    overlay.insert(entry);

    // Let the overlay lay out and paint before we snapshot it.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await WidgetsBinding.instance.endOfFrame;

    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      entry.remove();
      return false;
    }
    // Ensure the boundary has actually painted.
    var boundary = renderObject;
    var tries = 0;
    while (boundary.debugNeedsPaint && tries < 5) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      tries++;
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    entry.remove();
    entry = null;

    if (byteData == null) return false;
    final bytes = byteData.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/fat_disclosure_card_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: shareText,
      subject: 'FAT Label Analysis',
    );
    return true;
  } catch (_) {
    entry?.remove();
    return false;
  }
}
