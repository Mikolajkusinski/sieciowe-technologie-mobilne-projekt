import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MapClientPage(),
    );
  }
}

class MapClientPage extends StatefulWidget {
  const MapClientPage({super.key});
  @override
  State<MapClientPage> createState() => _MapClientPageState();
}

class _MapClientPageState extends State<MapClientPage> {
  //CONFIG
  final String soapEndpoint = 'http://<SERVER_ADDRESS>/MapService'; //TODO: endpoint
  final String soapAction = 'getMapFragment';                       //TODO: SoapAction/NazwaMetody
  final int originalWidth = 1000;                                   //Width oryginalnego obrazu
  final int originalHeight = 1000;                                  //Height oryginalnego obrazu
  //Bounding Box geograficzny mapy [top-left & bot-right]
  final double topLeftLat = 99.9999;                                //TODO: wspolrzedne
  final double topLeftLon = 99.9999;                                //TODO: -/-
  final double botRightLat = 99.9999;                               //TODO: -/-
  final double botLeftLon = 99.9999;                                //TODO: -/-

  //Controllers for pixel coords
  final TextEditingController x1Ctrl = TextEditingController();
  final TextEditingController y1Ctrl = TextEditingController();
  final TextEditingController x2Ctrl = TextEditingController();
  final TextEditingController y2Ctrl = TextEditingController();

  //Controllers for geographic coords
  final TextEditingController lat1Ctrl = TextEditingController();
  final TextEditingController lon1Ctrl = TextEditingController();
  final TextEditingController lat2Ctrl = TextEditingController();
  final TextEditingController lon2Ctrl = TextEditingController();

  Uint8List? receivedImage;
  bool loading = false;
  String logText = '';

  //Minimap drawing state
  Offset? dragStart;
  Offset? dragCurrent;
  GlobalKey miniMapKey = GlobalKey();

  void appendLog(String s){
    setState((){
      logText = '${DateTime.now().toIso8601String()} - $s\n$logText';
    });
  }

  //Build SOAP XML
  String buildSoapRequest({int? x1, int? y1, int? x2, int? y2,
    double? lat1, double? lon1, double? lat2, double? lon2}){
    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="utf-8"');
    builder.element('soapenv:Envelope', namespace: {
      'soapenv': 'http://schamas.xmlsoap.org/soap/envelope/',
      'ns': 'http://service.example.com/' //TODO: zmienic na targetNamespace serwera

    }, nest: () {
      builder.element('soapenv:Header', nest: () {});
      builder.element('soapenv:Body', nest: () {
        builder.element('ns:$soapAction', nest: () {
          if (x1 != null) builder.element('x1', nest: x1.toString());
          if (y1 != null) builder.element('y1', nest: y1.toString());
          if (x2 != null) builder.element('x2', nest: x2.toString());
          if (y2 != null) builder.element('y2', nest: y2.toString());
          if (lat1 != null) builder.element('lat1', nest: lat1.toString());
          if (lon1 != null) builder.element('lon1', nest: lon1.toString());
          if (lat2 != null) builder.element('lat2', nest: lat2.toString());
          if (lon2 != null) builder.element('lon2', nest: lon2.toString());
        });
      });
    });
    return builder.buildDocument().toXmlString(pretty: false);
  }

  Future<void> sendRequestByPixels() async {
    final int? x1 = int.tryParse(x1Ctrl.text);
    final int? y1 = int.tryParse(y1Ctrl.text);
    final int? x2 = int.tryParse(x2Ctrl.text);
    final int? y2 = int.tryParse(y2Ctrl.text);

    if (x1 == null || y1 == null || x2 == null || y2 == null) {
      appendLog('Błędne wartości pikseli');
      return;
    }
    await _sendSoapRequest(x1: x1, y1: y1, x2: x2, y2: y2);
  }

  Future<void> sendRequestByGeo() async {
    final double? lat1 = double.tryParse(lat1Ctrl.text);
    final double? lon1 = double.tryParse(lon1Ctrl.text);
    final double? lat2 = double.tryParse(lat2Ctrl.text);
    final double? lon2 = double.tryParse(lon2Ctrl.text);

    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      appendLog('Błędne wartości geograficzne');
      return;
    }
    await _sendSoapRequest(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2);
  }

  Future<void> _sendSoapRequest({int? x1, int? y1, int? x2, int? y2, double? lat1, double? lon1, double? lat2, double? lon2}) async {
    setState(() => loading = true);
    final xmlReq = buildSoapRequest(x1: x1, y1: y1, x2: x2, y2: y2, lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2);
    appendLog('Request XML: $xmlReq');

    try {
      final resp = await http.post(
        Uri.parse(soapEndpoint),
        headers: {
          'Content-Type': 'text/xml; charset=utf-8',
          'SOAPAction': soapAction, // w zależności od serwera może być potrzebne pełne URI
        },
        body: xmlReq,
      ).timeout(const Duration(seconds: 15));

      appendLog('HTTP status: ${resp.statusCode}');
      appendLog('Response body: ${resp.body}');

      if (resp.statusCode == 200) {
        // Parsujemy odpowiedź XML i wydobywamy Base64 (dostosuj nazwę tagu)
        final doc = xml.XmlDocument.parse(resp.body);
        // Znajdź pierwszy node z zawartością base64 — dopasuj ścieżkę w zależności od serwera
        final base64Element = doc.findAllElements('return').isNotEmpty
            ? doc.findAllElements('return').first
            : (doc.findAllElements('imageBase64').isNotEmpty ? doc.findAllElements('imageBase64').first : null);

        if (base64Element != null) {
          final base64String = base64Element.text;
          final bytes = base64Decode(base64String);
          setState(() {
            receivedImage = bytes;
          });
          appendLog('Odebrano obraz (rozmiar bajtów: ${bytes.length})');
        } else {
          appendLog('Nie znaleziono elementu z Base64 w odpowiedzi XML.');
        }
      } else {
        appendLog('Błąd HTTP: ${resp.statusCode}');
      }
    } on TimeoutException {
      appendLog('Timeout podczas wysyłania żądania');
    } catch (e) {
      appendLog('Exception: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // Konwersja tap -> pixel original
  // displaySize = actual rendered size of the mini-map image
  // originalWidth/Height - rozmiar oryginału obrazka w px.
  Offset convertDisplayToOriginal(Offset displayTap, Size displaySize) {
    final double scaleX = originalWidth / displaySize.width;
    final double scaleY = originalHeight / displaySize.height;
    final double realX = displayTap.dx * scaleX;
    final double realY = displayTap.dy * scaleY;
    return Offset(realX, realY);
  }

  // Konwersja pomiędzy pixel <-> geo (prosta liniowa interpolacja)
  // zakłada, że topLeftLatLon i bottomRightLatLon zdefiniowane w CONFIGu
  Offset pixelToGeo(Offset pix) {
    // pix.x w [0, originalWidth], pix.y w [0, originalHeight]
    final double lonRange = bottomRightLon - topLeftLon;
    final double latRange = topLeftLat - bottomRightLat; // lat maleje w dół
    final double lon = topLeftLon + (pix.dx / originalWidth) * lonRange;
    final double lat = topLeftLat - (pix.dy / originalHeight) * latRange;
    return Offset(lat, lon);
  }

  Offset geoToPixel(double lat, double lon) {
    final double lonRange = bottomRightLon - topLeftLon;
    final double latRange = topLeftLat - bottomRightLat;
    final double x = ((lon - topLeftLon) / lonRange) * originalWidth;
    final double y = ((topLeftLat - lat) / latRange) * originalHeight;
    return Offset(x, y);
  }

  void _onMiniMapPanStart(DragStartDetails details) {
    final rb = miniMapKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final local = rb.globalToLocal(details.globalPosition);
    setState(() {
      dragStart = local;
      dragCurrent = local;
    });
  }

  void _onMiniMapPanUpdate(DragUpdateDetails details) {
    final rb = miniMapKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final local = rb.globalToLocal(details.globalPosition);
    setState(() {
      dragCurrent = local;
    });
  }

  void _onMiniMapPanEnd(DragEndDetails details) {
    final rb = miniMapKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null || dragStart == null || dragCurrent == null) {
      setState(() {
        dragStart = null;
        dragCurrent = null;
      });
      return;
    }
    final size = rb.size;
    final p1 = convertDisplayToOriginal(dragStart!, size);
    final p2 = convertDisplayToOriginal(dragCurrent!, size);

    final left = p1.dx < p2.dx ? p1.dx : p2.dx;
    final top = p1.dy < p2.dy ? p1.dy : p2.dy;
    final right = p1.dx > p2.dx ? p1.dx : p2.dx;
    final bottom = p1.dy > p2.dy ? p1.dy : p2.dy;

    // Ustaw pola tekstowe px
    x1Ctrl.text = left.floor().toString();
    y1Ctrl.text = top.floor().toString();
    x2Ctrl.text = right.ceil().toString();
    y2Ctrl.text = bottom.ceil().toString();

    // Ustaw pola geograficzne
    final geoTL = pixelToGeo(Offset(left, top));
    final geoBR = pixelToGeo(Offset(right, bottom));
    lat1Ctrl.text = geoTL.dx.toStringAsFixed(6);
    lon1Ctrl.text = geoTL.dy.toStringAsFixed(6);
    lat2Ctrl.text = geoBR.dx.toStringAsFixed(6);
    lon2Ctrl.text = geoBR.dy.toStringAsFixed(6);

    setState(() {
      dragStart = null;
      dragCurrent = null;
    });
    appendLog('Zaznaczono prostokąt -> px: ($left,$top)-($right,$bottom), geo: (${geoTL.dx},${geoTL.dy})-(${geoBR.dx},${geoBR.dy})');
  }

  @override
  void dispose() {
    x1Ctrl.dispose();
    y1Ctrl.dispose();
    x2Ctrl.dispose();
    y2Ctrl.dispose();
    lat1Ctrl.dispose();
    lon1Ctrl.dispose();
    lat2Ctrl.dispose();
    lon2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final miniMap = GestureDetector(
      onPanStart: _onMiniMapPanStart,
      onPanUpdate: _onMiniMapPanUpdate,
      onPanEnd: _onMiniMapPanEnd,
      child: Container(
        key: miniMapKey,
        width: 320,
        height: 320,
        decoration: BoxDecoration(border: Border.all(width: 1, color: Colors.black26)),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/map_thumbnail.png', fit: BoxFit.contain),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _SelectionPainter(start: dragStart, current: dragCurrent),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Map SOAP Client')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Mini map
                Column(
                  children: [
                    const Text('Mini map (draw rectangle):'),
                    const SizedBox(height: 8),
                    miniMap,
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // If you'd like to clear fields
                        x1Ctrl.clear();
                        y1Ctrl.clear();
                        x2Ctrl.clear();
                        y2Ctrl.clear();
                        lat1Ctrl.clear();
                        lon1Ctrl.clear();
                        lat2Ctrl.clear();
                        lon2Ctrl.clear();
                        appendLog('Wyczyszczono pola');
                      },
                      child: const Text('Clear fields'),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Right: Params and result
                Expanded(
                  child: Column(
                    children: [
                      const Text('Pixel coordinates (int):', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(children: [
                        Expanded(child: TextField(controller: x1Ctrl, decoration: const InputDecoration(labelText: 'x1'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: y1Ctrl, decoration: const InputDecoration(labelText: 'y1'))),
                      ]),
                      Row(children: [
                        Expanded(child: TextField(controller: x2Ctrl, decoration: const InputDecoration(labelText: 'x2'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: y2Ctrl, decoration: const InputDecoration(labelText: 'y2'))),
                      ]),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: loading ? null : sendRequestByPixels,
                        child: loading ? const CircularProgressIndicator() : const Text('Send (pixels)'),
                      ),
                      const Divider(),
                      const Text('Geographic coordinates (double):', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(children: [
                        Expanded(child: TextField(controller: lat1Ctrl, decoration: const InputDecoration(labelText: 'lat1'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: lon1Ctrl, decoration: const InputDecoration(labelText: 'lon1'))),
                      ]),
                      Row(children: [
                        Expanded(child: TextField(controller: lat2Ctrl, decoration: const InputDecoration(labelText: 'lat2'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: lon2Ctrl, decoration: const InputDecoration(labelText: 'lon2'))),
                      ]),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: loading ? null : sendRequestByGeo,
                        child: loading ? const CircularProgressIndicator() : const Text('Send (geo)'),
                      ),
                      const SizedBox(height: 12),
                      const Text('Result image:'),
                      Container(
                        width: double.infinity,
                        height: 300,
                        color: Colors.black12,
                        child: receivedImage == null
                            ? const Center(child: Text('No image received yet'))
                            : Image.memory(receivedImage!, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      Text('Logs:', style: const TextStyle(fontWeight: FontWeight.bold).copyWith()),
                      Container(
                        width: double.infinity,
                        height: 180,
                        padding: const EdgeInsets.all(8),
                        color: Colors.black12,
                        child: SingleChildScrollView(child: Text(logText)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Painter to draw rectangle during selection
class _SelectionPainter extends CustomPainter {
  final Offset? start;
  final Offset? current;
  _SelectionPainter({this.start, this.current});
  @override
  void paint(Canvas canvas, Size size) {
    if (start == null || current == null) return;
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    final rect = Rect.fromPoints(start!, current!);
    canvas.drawRect(rect, paint);

    final border = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.current != current;
  }
}