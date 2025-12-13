import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'result_map_view.dart';
import 'services/map_service.dart';

class CoordinateMapView extends StatefulWidget {
  static const routeName = '/coordinateMap';
  const CoordinateMapView({super.key});

  @override
  State<CoordinateMapView> createState() => _CoordinateMapViewState();
}

class _CoordinateMapViewState extends State<CoordinateMapView> {
  final _firstController = TextEditingController();
  final _secondController = TextEditingController();
  final _thirdController = TextEditingController();
  final _fourthController = TextEditingController();
  int _selectedIndex = 0; // 0 = A, 1 = B
  bool _firstValid = false;
  bool _secondValid = false;
  bool _thirdValid = false;
  bool _fourthValid = false;

  double? _tryParseDouble(String input) {
    // Allow both comma and dot as decimal separators
    final normalized = input.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  @override
  void dispose() {
    _firstController.dispose();
    _secondController.dispose();
    _thirdController.dispose();
    _fourthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coordinate Map'),
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
            Center(
              child: ToggleButtons(
                isSelected: [_selectedIndex == 0, _selectedIndex == 1],
                onPressed: (index) => setState(() {
                  _selectedIndex = index;
                  // Clear all fields and validation when switching modes
                  _firstController.clear();
                  _secondController.clear();
                  _thirdController.clear();
                  _fourthController.clear();
                  _firstValid = false;
                  _secondValid = false;
                  _thirdValid = false;
                  _fourthValid = false;
                }),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Geographical Coordinates')),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Pixel Coordinates')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Input fields: 4 for Geographical, 4 for Pixel (per backend requirements)
            TextField(
              controller: _firstController,
              decoration: InputDecoration(
                labelText: _selectedIndex == 0 ? 'Latitude (from)' : 'Top Left X',
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: (_firstValid || _firstController.text.isEmpty)
                        ? Colors.grey
                        : Colors.red,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: (_firstValid || _firstController.text.isEmpty)
                        ? Theme.of(context).colorScheme.primary
                        : Colors.red,
                    width: 2,
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                bool valid = false;
                if (value.isNotEmpty) {
                  final parsed = _tryParseDouble(value);
                  if (parsed != null) {
                    // In Pixel mode, require value <= 1000; in Geo mode, numeric is enough
                    valid = _selectedIndex == 1 ? (parsed <= 1000) : true;
                  }
                }
                if (valid != _firstValid) {
                  setState(() => _firstValid = valid);
                } else {
                  // Still trigger rebuild for border update when text empties/fills
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secondController,
              decoration: InputDecoration(
                labelText: _selectedIndex == 0 ? 'Longitude (from)' : 'Top Left Y',
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: (_secondValid || _secondController.text.isEmpty)
                        ? Colors.grey
                        : Colors.red,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: (_secondValid || _secondController.text.isEmpty)
                        ? Theme.of(context).colorScheme.primary
                        : Colors.red,
                    width: 2,
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                bool valid = false;
                if (value.isNotEmpty) {
                  final parsed = _tryParseDouble(value);
                  if (parsed != null) {
                    // In Pixel mode, require value <= 1000; in Geo mode, numeric is enough
                    valid = _selectedIndex == 1 ? (parsed <= 1000) : true;
                  }
                }
                if (valid != _secondValid) {
                  setState(() => _secondValid = valid);
                } else {
                  setState(() {});
                }
              },
            ),
            // Third and fourth fields
            if (_selectedIndex == 0 || _selectedIndex == 1) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _thirdController,
                decoration: InputDecoration(
                  labelText: _selectedIndex == 0 ? 'Latitude (to)' : 'Bottom Right X',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: (_thirdValid || _thirdController.text.isEmpty)
                          ? Colors.grey
                          : Colors.red,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: (_thirdValid || _thirdController.text.isEmpty)
                          ? Theme.of(context).colorScheme.primary
                          : Colors.red,
                      width: 2,
                    ),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  bool valid = false;
                  if (value.isNotEmpty) {
                    final parsed = _tryParseDouble(value);
                    if (parsed != null) {
                      valid = _selectedIndex == 1 ? (parsed <= 1000) : true;
                    }
                  }
                  if (valid != _thirdValid) {
                    setState(() => _thirdValid = valid);
                  } else {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fourthController,
                decoration: InputDecoration(
                  labelText: _selectedIndex == 0 ? 'Longitude (to)' : 'Bottom Right Y',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: (_fourthValid || _fourthController.text.isEmpty)
                          ? Colors.grey
                          : Colors.red,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: (_fourthValid || _fourthController.text.isEmpty)
                          ? Theme.of(context).colorScheme.primary
                          : Colors.red,
                      width: 2,
                    ),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  bool valid = false;
                  if (value.isNotEmpty) {
                    final parsed = _tryParseDouble(value);
                    if (parsed != null) {
                      valid = _selectedIndex == 1 ? (parsed <= 1000) : true;
                    }
                  }
                  if (valid != _fourthValid) {
                    setState(() => _fourthValid = valid);
                  } else {
                    setState(() {});
                  }
                },
              ),
            ],
            const Spacer(),
            Builder(builder: (context) {
              final allValid = (_firstValid && _secondValid && _thirdValid && _fourthValid);
              final anyInvalidTyped = ((_firstController.text.isNotEmpty && !_firstValid) ||
                  (_secondController.text.isNotEmpty && !_secondValid) ||
                  (_thirdController.text.isNotEmpty && !_thirdValid) ||
                  (_fourthController.text.isNotEmpty && !_fourthValid));
              return ElevatedButton(
                onPressed: allValid ? () async {
                  if (_selectedIndex == 1) {
                    // Pixel mode: call backend and navigate with result image bytes
                    try {
                      // Parse values (round to int if needed)
                      final tlx = (_tryParseDouble(_firstController.text) ?? 0).round();
                      final tly = (_tryParseDouble(_secondController.text) ?? 0).round();
                      final brx = (_tryParseDouble(_thirdController.text) ?? 0).round();
                      final bry = (_tryParseDouble(_fourthController.text) ?? 0).round();

                      // Load the base image to send to backend (asset for demo)
                      final raw = await rootBundle.load('assets/thumb_map.png');
                      final bytes = raw.buffer.asUint8List();

                      // Call SOAP service
                      const baseUrl = 'http://10.0.2.2:5265';
                      final client = MapServiceClient(baseUrl: baseUrl);
                      final Uint8List result = await client.getMapByPixelCoordinates(
                        topLeftX: tlx,
                        topLeftY: tly,
                        bottomRightX: brx,
                        bottomRightY: bry,
                        imageBytes: bytes,
                      );

                      if (!context.mounted) return;
                      Navigator.pushNamed(
                        context,
                        ResultMapView.routeName,
                        arguments: {'imageBytes': result},
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to load map: $e')),
                      );
                    }
                  } else {
                    // Geo mode: existing behavior (navigate without call)
                    if (!context.mounted) return;
                    Navigator.pushNamed(context, ResultMapView.routeName);
                  }
                } : null,
                style: ButtonStyle(
                  // Keep background default; only change label color when invalid
                  foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                    if (anyInvalidTyped) return Colors.red;
                    return null; // use default
                  }),
                ),
                child: const Text('Go to Result Map'),
              );
            }),
          ],
        ),
      ),
    );
  }
}
