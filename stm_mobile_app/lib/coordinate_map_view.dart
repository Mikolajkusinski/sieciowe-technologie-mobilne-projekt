import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  // New geo bounds based on the provided real-world coordinates of the image
  // Top-Left:  Lat = 54.188424, Lon = 19.387526
  // Bottom-Right: Lat = 54.164336, Lon = 19.428238
  static const double _geoMaxLatitude = 54.188424; // northernmost
  static const double _geoMinLatitude = 54.164336; // southernmost
  static const double _geoMinLongitude = 19.387526; // westernmost
  static const double _geoMaxLongitude = 19.428238; // easternmost

  final _firstController = TextEditingController();
  final _secondController = TextEditingController();
  final _thirdController = TextEditingController();
  final _fourthController = TextEditingController();
  int _selectedIndex = 0; // 0 = A, 1 = B
  bool _firstValid = false;
  bool _secondValid = false;
  bool _thirdValid = false;
  bool _fourthValid = false;

  // Cached base image bytes and dimensions used for pixel mode validation and Y inversion
  Uint8List? _baseImageBytes;
  int? _imageWidth;
  int? _imageHeight;

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
  void initState() {
    super.initState();
    // Preload the base image and determine its dimensions for validation and coordinate transform
    _loadBaseImage();
  }

  Future<void> _loadBaseImage() async {
    try {
      final raw = await rootBundle.load('assets/thumb_map.png');
      final bytes = raw.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _baseImageBytes = bytes;
        _imageWidth = frame.image.width;
        _imageHeight = frame.image.height;
      });
    } catch (_) {
      // Keep nulls; validation will be lenient without bounds if image not available
    }
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
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
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
            ),
            const SizedBox(height: 16),
            // Input fields layout depends on mode
            if (_selectedIndex == 0) ...[
              // GEO MODE LAYOUT
              // Row 1: Latitude [N] centered
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: TextField(
                        controller: _firstController,
                        decoration: InputDecoration(
                          labelText: 'Latitude (N)',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
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
                        textAlign: TextAlign.center,
                        onChanged: (value) {
                          bool valid = false;
                          if (value.isNotEmpty) {
                            final parsed = _tryParseDouble(value);
                            if (parsed != null) {
                              // Geo mode Latitude bounds
                              valid = parsed >= _geoMinLatitude && parsed <= _geoMaxLatitude;
                            }
                          }
                          if (valid != _firstValid) {
                            setState(() => _firstValid = valid);
                          } else {
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Longitude [W] & Longitude [E]
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _secondController,
                      decoration: InputDecoration(
                        labelText: 'Longitude (W)',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
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
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        bool valid = false;
                        if (value.isNotEmpty) {
                          final parsed = _tryParseDouble(value);
                          if (parsed != null) {
                            // Geo mode Longitude bounds (W)
                            valid = parsed >= _geoMinLongitude && parsed <= _geoMaxLongitude;
                          }
                        }
                        if (valid != _secondValid) {
                          setState(() => _secondValid = valid);
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _fourthController,
                      decoration: InputDecoration(
                        labelText: 'Longitude (E)',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
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
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        bool valid = false;
                        if (value.isNotEmpty) {
                          final parsed = _tryParseDouble(value);
                          if (parsed != null) {
                            // Geo mode Longitude bounds (E)
                            valid = parsed >= _geoMinLongitude && parsed <= _geoMaxLongitude;
                          }
                        }
                        if (valid != _fourthValid) {
                          setState(() => _fourthValid = valid);
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 3: Latitude [S] centered
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: TextField(
                        controller: _thirdController,
                        decoration: InputDecoration(
                          labelText: 'Latitude (S)',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
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
                        textAlign: TextAlign.center,
                        onChanged: (value) {
                          bool valid = false;
                          if (value.isNotEmpty) {
                            final parsed = _tryParseDouble(value);
                            if (parsed != null) {
                              // Geo mode Latitude bounds
                              valid = parsed >= _geoMinLatitude && parsed <= _geoMaxLatitude;
                            }
                          }
                          if (valid != _thirdValid) {
                            setState(() => _thirdValid = valid);
                          } else {
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // PIXEL MODE LAYOUT (unchanged): two rows TL(X,Y) then BR(X,Y)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstController,
                      decoration: InputDecoration(
                        labelText: 'TopLeft.X',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        bool valid = false;
                        if (value.isNotEmpty) {
                          final parsed = _tryParseDouble(value);
                          if (parsed != null) {
                            if (_imageWidth != null) {
                              valid = parsed >= 0 && parsed <= _imageWidth!;
                            } else {
                              valid = true;
                            }
                          }
                        }
                        if (valid != _firstValid) {
                          setState(() => _firstValid = valid);
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _secondController,
                      decoration: InputDecoration(
                        labelText: 'TopLeft.Y',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        bool valid = false;
                        if (value.isNotEmpty) {
                          final parsed = _tryParseDouble(value);
                          if (parsed != null) {
                            if (_imageHeight != null) {
                              valid = parsed >= 0 && parsed <= _imageHeight!;
                            } else {
                              valid = true;
                            }
                          }
                        }
                        if (valid != _secondValid) {
                          setState(() => _secondValid = valid);
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _thirdController,
                      decoration: InputDecoration(
                        labelText: 'BottomRight.X',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        bool valid = false;
                        if (value.isNotEmpty) {
                          final parsed = _tryParseDouble(value);
                          if (parsed != null) {
                            if (_imageWidth != null) {
                              valid = parsed >= 0 && parsed <= _imageWidth!;
                            } else {
                              valid = true;
                            }
                          }
                        }
                        if (valid != _thirdValid) {
                          setState(() => _thirdValid = valid);
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _fourthController,
                      decoration: InputDecoration(
                        labelText: 'BottomRight.Y',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        bool valid = false;
                        if (value.isNotEmpty) {
                          final parsed = _tryParseDouble(value);
                          if (parsed != null) {
                            if (_imageHeight != null) {
                              valid = parsed >= 0 && parsed <= _imageHeight!;
                            } else {
                              valid = true;
                            }
                          }
                        }
                        if (valid != _fourthValid) {
                          setState(() => _fourthValid = valid);
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
            const Spacer(),
            Builder(builder: (context) {
              // Base field-level validation
              bool allValid = (_firstValid && _secondValid && _thirdValid && _fourthValid);
              // Additional rectangle relationship checks
              if (allValid && _selectedIndex == 1) {
                final tlx = (_tryParseDouble(_firstController.text) ?? double.nan);
                final tly = (_tryParseDouble(_secondController.text) ?? double.nan);
                final brx = (_tryParseDouble(_thirdController.text) ?? double.nan);
                final bry = (_tryParseDouble(_fourthController.text) ?? double.nan);
                // UI semantics requested: X grows left→right; Y grows bottom→top
                // Therefore require tlx < brx and tly > bry
                if (tlx.isNaN || tly.isNaN || brx.isNaN || bry.isNaN) {
                  allValid = false;
                } else {
                  allValid = (tlx < brx) && (tly > bry);
                }
              } else if (allValid && _selectedIndex == 0) {
                // Geo mode: validate ranges and rectangle relation
                final latFrom = (_tryParseDouble(_firstController.text) ?? double.nan);
                final lonFrom = (_tryParseDouble(_secondController.text) ?? double.nan);
                final latTo = (_tryParseDouble(_thirdController.text) ?? double.nan);
                final lonTo = (_tryParseDouble(_fourthController.text) ?? double.nan);
                if (latFrom.isNaN || lonFrom.isNaN || latTo.isNaN || lonTo.isNaN) {
                  allValid = false;
                } else {
                  // Apply new provided bounds
                  final latRangeOk =
                      latFrom >= _geoMinLatitude && latFrom <= _geoMaxLatitude &&
                      latTo >= _geoMinLatitude && latTo <= _geoMaxLatitude;
                  final lonRangeOk =
                      lonFrom >= _geoMinLongitude && lonFrom <= _geoMaxLongitude &&
                      lonTo >= _geoMinLongitude && lonTo <= _geoMaxLongitude;
                  // TopLeft should be north-west of BottomRight: higher latitude and lower longitude
                  final rectOk = latFrom > latTo && lonFrom < lonTo;
                  allValid = latRangeOk && lonRangeOk && rectOk;
                }
              }
              final anyInvalidTyped = ((_firstController.text.isNotEmpty && !_firstValid) ||
                  (_secondController.text.isNotEmpty && !_secondValid) ||
                  (_thirdController.text.isNotEmpty && !_thirdValid) ||
                  (_fourthController.text.isNotEmpty && !_fourthValid));
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ).copyWith(
                  // Change label color: red when any field invalidly typed, else onPrimary
                  foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                    if (anyInvalidTyped) return Colors.red;
                    return Theme.of(context).colorScheme.onPrimary;
                  }),
                ),
                onPressed: allValid ? () async {
                  if (_selectedIndex == 1) {
                    // Pixel mode: call backend and navigate with result image bytes
                    try {
                      // Parse values (round to int if needed)
                      final tlx = (_tryParseDouble(_firstController.text) ?? 0).round();
                      final tly = (_tryParseDouble(_secondController.text) ?? 0).round();
                      final brx = (_tryParseDouble(_thirdController.text) ?? 0).round();
                      final bry = (_tryParseDouble(_fourthController.text) ?? 0).round();
                      // Ensure we have base image and dimensions
                      if (_baseImageBytes == null || _imageHeight == null) {
                        // Fallback: try loading on demand
                        await _loadBaseImage();
                      }
                      if (_baseImageBytes == null || _imageHeight == null) {
                        throw Exception('Base image not available');
                      }

                      // Call SOAP service
                      const baseUrl = 'http://10.0.2.2:5265';
                      final client = MapServiceClient(baseUrl: baseUrl);
                      // Transform UI Y (bottom-origin) to backend Y (top-origin)
                      final tlyBackend = _imageHeight! - tly;
                      final bryBackend = _imageHeight! - bry;
                      final Uint8List result = await client.getMapByPixelCoordinates(
                        topLeftX: tlx,
                        topLeftY: tlyBackend,
                        bottomRightX: brx,
                        bottomRightY: bryBackend,
                        imageBytes: _baseImageBytes!,
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
                    // Geo mode: convert on client to pixels and call pixel endpoint
                    try {
                      final latFrom = (_tryParseDouble(_firstController.text) ?? 0);
                      final lonFrom = (_tryParseDouble(_secondController.text) ?? 0);
                      final latTo = (_tryParseDouble(_thirdController.text) ?? 0);
                      final lonTo = (_tryParseDouble(_fourthController.text) ?? 0);

                      if (_baseImageBytes == null || _imageWidth == null || _imageHeight == null) {
                        await _loadBaseImage();
                      }
                      if (_baseImageBytes == null || _imageWidth == null || _imageHeight == null) {
                        throw Exception('Base image not available');
                      }

                      const baseUrl = 'http://10.0.2.2:5265';
                      final client = MapServiceClient(baseUrl: baseUrl);
                      final Uint8List result = await client.getMapByGeoViaPixel(
                        topLeftLat: latFrom,
                        topLeftLon: lonFrom,
                        bottomRightLat: latTo,
                        bottomRightLon: lonTo,
                        imageBytes: _baseImageBytes!,
                        imageWidth: _imageWidth!,
                        imageHeight: _imageHeight!,
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
                  }
                } : null,
                child: const Text('Go to Result Map'),
              );
            }),
          ],
        ),
      ),
        ],
      ),
    );
  }
}
