import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'services/map_service.dart';
import 'result_map_view.dart';

class DrawRectangleView extends StatefulWidget {
  static const routeName = '/drawRectangle';
  const DrawRectangleView({super.key});

  @override
  State<DrawRectangleView> createState() => _DrawRectangleViewState();
}

class _DrawRectangleViewState extends State<DrawRectangleView> {
  // Image is always 1000x1000
  static const int _imageW = 1000;
  static const int _imageH = 1000;

  // Drag state in IMAGE PIXELS (top-left origin)
  Offset? _dragStartPx;
  Offset? _dragEndPx;
  bool _loading = false;

  Offset? _localToImagePx(Size boxSize, Offset local) {
    final w = _imageW.toDouble();
    final h = _imageH.toDouble();
    final sW = boxSize.width / w;
    final sH = boxSize.height / h;
    final s = sW < sH ? sW : sH; // BoxFit.contain
    final dispW = w * s;
    final dispH = h * s;
    final offX = (boxSize.width - dispW) / 2;
    final offY = (boxSize.height - dispH) / 2;

    final imgX = ((local.dx - offX) / s).clamp(0.0, w);
    final imgY = ((local.dy - offY) / s).clamp(0.0, h);
    return Offset(imgX, imgY);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Rectangle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          tooltip: 'Back to Main Menu',
        ),
        actions: [
          if (_dragStartPx != null && _dragEndPx != null)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() {
                _dragStartPx = null;
                _dragEndPx = null;
              }),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
          ),
          Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _loading
                          ? null
                          : (details) {
                              final p = _localToImagePx(size, details.localPosition);
                              setState(() {
                                _dragStartPx = p;
                                _dragEndPx = p;
                              });
                            },
                      onPanUpdate: _loading
                          ? null
                          : (details) {
                              final p = _localToImagePx(size, details.localPosition);
                              setState(() => _dragEndPx = p);
                            },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Underlay: the image using BoxFit.contain
                          Image.asset('assets/thumb_map.png', fit: BoxFit.contain),
                          // Overlay: rectangle only
                          CustomPaint(
                            painter: _RectOverlayPainter(
                              imageW: _imageW,
                              imageH: _imageH,
                              dragStartPx: _dragStartPx,
                              dragEndPx: _dragEndPx,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: (_dragStartPx != null && _dragEndPx != null && !_loading)
                  ? () async {
                      // Normalize rectangle corners in image pixel space (top-left origin)
                      final tl = Offset(
                        (_dragStartPx!.dx < _dragEndPx!.dx) ? _dragStartPx!.dx : _dragEndPx!.dx,
                        (_dragStartPx!.dy < _dragEndPx!.dy) ? _dragStartPx!.dy : _dragEndPx!.dy,
                      );
                      final br = Offset(
                        (_dragStartPx!.dx > _dragEndPx!.dx) ? _dragStartPx!.dx : _dragEndPx!.dx,
                        (_dragStartPx!.dy > _dragEndPx!.dy) ? _dragStartPx!.dy : _dragEndPx!.dy,
                      );

                      // Convert to ints and clamp to [0..imageSize]
                      int left = tl.dx.floor().clamp(0, _imageW);
                      int top = tl.dy.floor().clamp(0, _imageH);
                      int right = br.dx.ceil().clamp(0, _imageW);
                      int bottom = br.dy.ceil().clamp(0, _imageH);

                      // Ensure minimum size of 1x1 and correct ordering
                      if (right <= left) right = (left + 1).clamp(0, _imageW);
                      if (bottom <= top) bottom = (top + 1).clamp(0, _imageH);

                      setState(() => _loading = true);
                      try {
                        // Load base image bytes from assets
                        final raw = await rootBundle.load('assets/thumb_map.png');
                        final Uint8List baseImageBytes = raw.buffer.asUint8List();

                        // Call backend (same as pixel mode in CoordinateMapView)
                        const baseUrl = 'http://10.0.2.2:5265';
                        final client = MapServiceClient(baseUrl: baseUrl);
                        final Uint8List result = await client.getMapByPixelCoordinates(
                          topLeftX: left,
                          topLeftY: top,
                          bottomRightX: right,
                          bottomRightY: bottom,
                          imageBytes: baseImageBytes,
                        );

                        if (!mounted) return;
                        Navigator.pushNamed(
                          context,
                          ResultMapView.routeName,
                          arguments: {'imageBytes': result},
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to load map: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    }
                  : null,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Go to Result Map'),
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }
}

class _RectOverlayPainter extends CustomPainter {
  _RectOverlayPainter({
    required this.imageW,
    required this.imageH,
    required this.dragStartPx,
    required this.dragEndPx,
  });

  final int imageW;
  final int imageH;
  final Offset? dragStartPx;
  final Offset? dragEndPx;

  @override
  void paint(Canvas canvas, Size size) {
    // Compute BoxFit.contain geometry for the image
    final w = imageW.toDouble();
    final h = imageH.toDouble();
    final sW = size.width / w;
    final sH = size.height / h;
    final s = sW < sH ? sW : sH;
    final dispW = w * s;
    final dispH = h * s;
    final offX = (size.width - dispW) / 2;
    final offY = (size.height - dispH) / 2;

    if (dragStartPx != null && dragEndPx != null) {
      final tl = Offset(
        dragStartPx!.dx < dragEndPx!.dx ? dragStartPx!.dx : dragEndPx!.dx,
        dragStartPx!.dy < dragEndPx!.dy ? dragStartPx!.dy : dragEndPx!.dy,
      );
      final br = Offset(
        dragStartPx!.dx > dragEndPx!.dx ? dragStartPx!.dx : dragEndPx!.dx,
        dragStartPx!.dy > dragEndPx!.dy ? dragStartPx!.dy : dragEndPx!.dy,
      );

      // Convert image pixel → screen
      final tlScr = Offset(offX + tl.dx * s, offY + tl.dy * s);
      final brScr = Offset(offX + br.dx * s, offY + br.dy * s);
      final r = Rect.fromPoints(tlScr, brScr);

      final fill = Paint()
        ..color = Colors.blue.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _RectOverlayPainter oldDelegate) {
    return oldDelegate.dragStartPx != dragStartPx ||
        oldDelegate.dragEndPx != dragEndPx ||
        oldDelegate.imageW != imageW ||
        oldDelegate.imageH != imageH;
  }
}
