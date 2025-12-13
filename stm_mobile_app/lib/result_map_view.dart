import 'dart:typed_data';
import 'package:flutter/material.dart';

class ResultMapView extends StatelessWidget {
  static const routeName = '/resultMap';
  const ResultMapView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    Uint8List? imageBytes;
    if (args is Map && args['imageBytes'] is Uint8List) {
      imageBytes = args['imageBytes'] as Uint8List;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Result Map')),
      body: SizedBox.expand(
        child: imageBytes != null
            ? Image.memory(imageBytes, fit: BoxFit.contain)
            : Image.asset('assets/thumb_map.png', fit: BoxFit.cover),
      ),
    );
  }
}
