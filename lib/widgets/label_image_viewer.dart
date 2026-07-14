import 'dart:io';
import 'package:flutter/material.dart';

// Full-screen viewer for scanned label panels — Flutter port of iOS
// LabelImageViewer. Pinch-zoom (1x–6x) + drag-pan (InteractiveViewer),
// double-tap toggle 1x <-> 2.5x, rotate left/right 90°, reset, and page
// swipe between panels. Each page keeps its own rotation/zoom.
class LabelImageViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const LabelImageViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  static Future<void> open(BuildContext context, List<String> paths,
      {int initialIndex = 0}) {
    if (paths.isEmpty) return Future.value();
    return Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) =>
          LabelImageViewer(imagePaths: paths, initialIndex: initialIndex),
    ));
  }

  @override
  State<LabelImageViewer> createState() => _LabelImageViewerState();
}

class _LabelImageViewerState extends State<LabelImageViewer> {
  late final PageController _page;
  late int _index;
  final Map<int, int> _quarterTurns = {}; // page -> 90° steps
  final Map<int, TransformationController> _tc = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex
        .clamp(0, widget.imagePaths.length - 1);
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    for (final c in _tc.values) {
      c.dispose();
    }
    super.dispose();
  }

  TransformationController _ctrl(int i) =>
      _tc.putIfAbsent(i, () => TransformationController());

  void _rotate(int delta) =>
      setState(() => _quarterTurns[_index] = (_quarterTurns[_index] ?? 0) + delta);

  void _reset() => setState(() {
        _quarterTurns[_index] = 0;
        _ctrl(_index).value = Matrix4.identity();
      });

  void _toggleZoom(int i) {
    final c = _ctrl(i);
    final zoomed = c.value.getMaxScaleOnAxis() > 1.01;
    c.value = zoomed ? Matrix4.identity() : Matrix4.diagonal3Values(2.5, 2.5, 1);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.imagePaths.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: n,
            itemBuilder: (_, i) => GestureDetector(
              onDoubleTap: () => _toggleZoom(i),
              child: InteractiveViewer(
                transformationController: _ctrl(i),
                minScale: 1,
                maxScale: 6,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: _quarterTurns[i] ?? 0,
                    child: Image.file(File(widget.imagePaths[i]),
                        fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x8C000000), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                  Expanded(
                    child: Text(
                      n > 1 ? '${_index + 1} / $n' : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
                  _iconBtn(Icons.rotate_left, () => _rotate(-1)),
                  _iconBtn(Icons.rotate_right, () => _rotate(1)),
                  _iconBtn(Icons.restart_alt, _reset),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
      );
}
