import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
// Extracted views
import 'main_menu_view.dart';
import 'draw_rectangle_view.dart';
import 'coordinate_map_view.dart';
import 'result_map_view.dart';

void main() {
  runApp(const MapSoapApp());
}

class MapSoapApp extends StatelessWidget {
  const MapSoapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOAP Map Client',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Set the new Main Menu as the entry point
      home: const MainMenuView(),
      routes: {
        DrawRectangleView.routeName: (_) => const DrawRectangleView(),
        CoordinateMapView.routeName: (_) => const CoordinateMapView(),
        ResultMapView.routeName: (_) => const ResultMapView(),
      },
    );
  }
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  // Pixel coordinates controllers
  final topLeftXController = TextEditingController();
  final topLeftYController = TextEditingController();
  final bottomRightXController = TextEditingController();
  final bottomRightYController = TextEditingController();

  // Geo coordinates controllers
  final topLeftLatController = TextEditingController();
  final topLeftLonController = TextEditingController();
  final bottomRightLatController = TextEditingController();
  final bottomRightLonController = TextEditingController();

  Uint8List? imageBytes; // tutaj przechowamy wynikowy obraz

  // Mini-map variables
  Offset? rectStart;
  Offset? rectEnd;

  // --- Wysyłanie SOAP request ---
  Future<String> sendSoap(String url, String soapAction, String envelope) async {
    final headers = {
      'Content-Type': 'text/xml; charset=utf-8',
      'SOAPAction': soapAction,
    };
    final resp = await http.post(Uri.parse(url), headers: headers, body: envelope);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.body;
    } else {
      throw Exception('SOAP request failed: ${resp.statusCode}');
    }
  }

  // --- Parsowanie ImageData z SOAP response ---
  Uint8List extractImageFromSoap(String soapBody) {
    final document = xml.XmlDocument.parse(soapBody);
    final node = document.findAllElements('ImageData').first;
    return base64.decode(node.text);
  }

  // --- Wywołanie Ping ---
  Future<void> doPing() async {
    try {
      final envelope = '''<?xml version="1.0"?>
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
        xmlns:map="http://mapservice.soap.api/2024">
        <soapenv:Body>
          <map:Ping/>
        </soapenv:Body>
      </soapenv:Envelope>''';

      final response = await sendSoap('http://10.0.2.2:5265/MapService.svc',
          'http://mapservice.soap.api/2024/IMapService/Ping', envelope);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(content: Text(response)),
      );
    } catch (e) {
      debugPrint('Ping failed: $e');
    }
  }

  // --- Wywołanie GetMapByPixelCoordinates ---
  Future<void> getMapByPixel() async {
    try {
      final envelope = '''<?xml version="1.0"?>
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
        xmlns:map="http://mapservice.soap.api/2024">
        <soapenv:Body>
          <map:GetMapByPixelCoordinates>
            <map:request>
              <map:TopLeft>
                <map:X>${topLeftXController.text}</map:X>
                <map:Y>${topLeftYController.text}</map:Y>
              </map:TopLeft>
              <map:BottomRight>
                <map:X>${bottomRightXController.text}</map:X>
                <map:Y>${bottomRightYController.text}</map:Y>
              </map:BottomRight>
            </map:request>
          </map:GetMapByPixelCoordinates>
        </soapenv:Body>
      </soapenv:Envelope>''';

      final response = await sendSoap('http://10.0.2.2:5265/MapService.svc',
          'http://mapservice.soap.api/2024/IMapService/GetMapByPixelCoordinates', envelope);
      setState(() {
        imageBytes = extractImageFromSoap(response);
      });
    } catch (e) {
      debugPrint('GetMapByPixel failed: $e');
    }
  }

  // --- Wywołanie GetMapByGeoCoordinates ---
  Future<void> getMapByGeo() async {
    try {
      final envelope = '''<?xml version="1.0"?>
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
        xmlns:map="http://mapservice.soap.api/2024">
        <soapenv:Body>
          <map:GetMapByGeoCoordinates>
            <map:request>
              <map:TopLeft>
                <map:Latitude>${topLeftLatController.text}</map:Latitude>
                <map:Longitude>${topLeftLonController.text}</map:Longitude>
              </map:TopLeft>
              <map:BottomRight>
                <map:Latitude>${bottomRightLatController.text}</map:Latitude>
                <map:Longitude>${bottomRightLonController.text}</map:Longitude>v
              </map:BottomRight>
            </map:request>
          </map:GetMapByGeoCoordinates>
        </soapenv:Body>
      </soapenv:Envelope>''';

      final response = await sendSoap('http://10.0.2.2:5265/MapService.svc',
          'http://mapservice.soap.api/2024/IMapService/GetMapByGeoCoordinates', envelope);
      setState(() {
        imageBytes = extractImageFromSoap(response);
      });
    } catch (e) {
      debugPrint('GetMapByGeo failed: $e');
    }
  }

  // --- Mini-map gestures ---
  void onPanStart(DragStartDetails details) {
    setState(() {
      rectStart = details.localPosition;
      rectEnd = null;
    });
  }

  void onPanUpdate(DragUpdateDetails details) {
    setState(() {
      rectEnd = details.localPosition;
    });
  }

  void onPanEnd(DragEndDetails details) {
    // TODO: przelicz rectStart/rectEnd na pixele oryginału i uzupełnij TextEditingController
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOAP Map Client')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton(onPressed: doPing, child: const Text('Ping Server')),
            const SizedBox(height: 20),
            const Text('Pixel Coordinates'),
            Row(
              children: [
                Expanded(child: TextField(controller: topLeftXController, decoration: const InputDecoration(labelText: 'TopLeft X'))),
                const SizedBox(width: 5),
                Expanded(child: TextField(controller: topLeftYController, decoration: const InputDecoration(labelText: 'TopLeft Y'))),
              ],
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: bottomRightXController, decoration: const InputDecoration(labelText: 'BottomRight X'))),
                const SizedBox(width: 5),
                Expanded(child: TextField(controller: bottomRightYController, decoration: const InputDecoration(labelText: 'BottomRight Y'))),
              ],
            ),
            ElevatedButton(onPressed: getMapByPixel, child: const Text('Get Map (Pixel)')),
            const SizedBox(height: 20),
            const Text('Geo Coordinates'),
            Row(
              children: [
                Expanded(child: TextField(controller: topLeftLatController, decoration: const InputDecoration(labelText: 'TopLeft Lat'))),
                const SizedBox(width: 5),
                Expanded(child: TextField(controller: topLeftLonController, decoration: const InputDecoration(labelText: 'TopLeft Lon'))),
              ],
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: bottomRightLatController, decoration: const InputDecoration(labelText: 'BottomRight Lat'))),
                const SizedBox(width: 5),
                Expanded(child: TextField(controller: bottomRightLonController, decoration: const InputDecoration(labelText: 'BottomRight Lon'))),
              ],
            ),
            ElevatedButton(onPressed: getMapByGeo, child: const Text('Get Map (Geo)')),
            const SizedBox(height: 20),
            if (imageBytes != null)
              Image.memory(imageBytes!),
            const SizedBox(height: 20),
            const Text('Mini-map (draw rectangle)'),
            Container(
              width: 300,
              height: 300,
              color: Colors.grey[300],
              child: GestureDetector(
                onPanStart: onPanStart,
                onPanUpdate: onPanUpdate,
                onPanEnd: onPanEnd,
                child: CustomPaint(
                  painter: MiniMapPainter(rectStart, rectEnd),
                  child: Image.asset('assets/thumb_map.png', fit: BoxFit.cover), // dodaj plik miniatury
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniMapPainter extends CustomPainter {
  final Offset? start;
  final Offset? end;

  MiniMapPainter(this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    if (start != null && end != null) {
      final rect = Rect.fromPoints(start!, end!);
      final paint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, paint);

      final border = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(rect, border);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}