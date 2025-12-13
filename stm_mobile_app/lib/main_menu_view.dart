import 'package:flutter/material.dart';
import 'coordinate_map_view.dart';
import 'draw_rectangle_view.dart';

class MainMenuView extends StatelessWidget {
  const MainMenuView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Main Menu')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, DrawRectangleView.routeName),
              child: const Text('Draw Rectangle'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, CoordinateMapView.routeName),
              child: const Text('Coordinate Map'),
            ),
          ],
        ),
      ),
    );
  }
}
