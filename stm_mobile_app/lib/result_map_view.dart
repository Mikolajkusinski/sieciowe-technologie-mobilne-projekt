import 'dart:typed_data';
import 'package:flutter/material.dart';

class ResultMapView extends StatelessWidget {
  static const routeName = '/resultMap';
  const ResultMapView({super.key});

  static const int _imageW = 1000;
  static const int _imageH = 1000;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    Uint8List? imageBytes;
    Offset? tl;
    Offset? br;
    if (args is Map) {
      if (args['imageBytes'] is Uint8List) {
        imageBytes = args['imageBytes'] as Uint8List;
      }
      if (args['rectPx'] is Map) {
        final m = args['rectPx'] as Map;
        tl = m['tl'] as Offset?;
        br = m['br'] as Offset?;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Result Map')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Foreground content
          LayoutBuilder(
        builder: (context, constraints) {
          // If a rectangle is provided, crop to it; otherwise show the full image.
          if (tl != null && br != null) {
            // Normalize tl/br
            final topLeft = Offset(
              tl.dx < br.dx ? tl.dx : br.dx,
              tl.dy < br.dy ? tl.dy : br.dy,
            );
            final bottomRight = Offset(
              tl.dx > br.dx ? tl.dx : br.dx,
              tl.dy > br.dy ? tl.dy : br.dy,
            );

            final cropW = (bottomRight.dx - topLeft.dx).clamp(1.0, _imageW.toDouble());
            final cropH = (bottomRight.dy - topLeft.dy).clamp(1.0, _imageH.toDouble());

            // Scale so that the cropped rect fits the available space with BoxFit.contain
            final sW = constraints.maxWidth / cropW;
            final sH = constraints.maxHeight / cropH;
            final s = sW < sH ? sW : sH;
            final targetW = cropW * s;
            final targetH = cropH * s;

            // Build the image at scaled full size and translate so the crop is visible inside ClipRect
            final Offset translate = Offset(-topLeft.dx * s, -topLeft.dy * s);

            Widget scaledImage;
            if (imageBytes != null) {
              scaledImage = Image.memory(
                imageBytes,
                width: _imageW * s,
                height: _imageH * s,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              );
            } else {
              scaledImage = Image.asset(
                'assets/thumb_map.png',
                width: _imageW * s,
                height: _imageH * s,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              );
            }

            return Center(
              child: SizedBox(
                width: targetW,
                height: targetH,
                child: ClipRect(
                  child: Transform.translate(
                    offset: translate,
                    child: scaledImage,
                  ),
                ),
              ),
            );
          }

          // Fallback: no rectangle → show full image contained
          if (imageBytes != null) {
            return Image.memory(imageBytes, fit: BoxFit.contain);
          } else {
            return Image.asset('assets/thumb_map.png', fit: BoxFit.contain);
          }
        },
      ),
        ],
      ),
    );
  }
}
