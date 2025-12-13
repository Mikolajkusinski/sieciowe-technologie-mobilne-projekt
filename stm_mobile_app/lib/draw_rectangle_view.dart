import 'package:flutter/material.dart';
import 'result_map_view.dart';

class DrawRectangleView extends StatelessWidget {
  static const routeName = '/drawRectangle';
  const DrawRectangleView({super.key});

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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/thumb_map.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, ResultMapView.routeName),
              child: const Text('Go to Result Map'),
            ),
          ],
        ),
      ),
    );
  }
}
