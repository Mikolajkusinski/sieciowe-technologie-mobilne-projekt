import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class MapServiceClient {
  MapServiceClient({required this.baseUrl});

  /// Base URL of the SOAP service, e.g. http://localhost:5000
  final String baseUrl;

  // Anchors for geo→pixel conversion (confirmed by you)
  static const double _anchorMinLat = 54.164336; // bottom edge (south)
  static const double _anchorMaxLat = 54.188424; // top edge (north)
  static const double _anchorMinLon = 19.387526; // left edge (west)
  static const double _anchorMaxLon = 19.428238; // right edge (east)

  // Default base image size (confirmed single PNG 1000x1000)
  static const int _defaultImageWidth = 1000;
  static const int _defaultImageHeight = 1000;

  /// Calls SOAP method GetMapByPixelCoordinates.
  /// [topLeftX],[topLeftY],[bottomRightX],[bottomRightY] define the crop rectangle.
  /// [imageBytes] is the source image to crop on the backend.
  /// Returns decoded JPEG bytes of the cropped image on success.
  Future<Uint8List> getMapByPixelCoordinates({
    required int topLeftX,
    required int topLeftY,
    required int bottomRightX,
    required int bottomRightY,
    required Uint8List imageBytes,
  }) async {
    final endpoint = Uri.parse('$baseUrl/MapService.svc');

    final imageBase64 = base64Encode(imageBytes);

    const svcNs = 'http://mapservice.soap.api/2024';
    const modelNs = 'http://schemas.datacontract.org/2004/07/SoapWebApi.Models';

    // Build SOAP envelope matching CoreWCF expectations:
    // - Operation wrapper in service namespace (svcNs)
    // - Parameter element (request) in model namespace (modelNs)
    // - Data members in model namespace (modelNs)
    final envelope = '''
<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns="$svcNs" xmlns:dt="$modelNs">
  <soapenv:Header/>
  <soapenv:Body>
    <ns:GetMapByPixelCoordinates>
      <ns:request>
        <dt:BottomRight>
          <dt:X>$bottomRightX</dt:X>
          <dt:Y>$bottomRightY</dt:Y>
        </dt:BottomRight>
        <dt:ImageData>$imageBase64</dt:ImageData>
        <dt:TopLeft>
          <dt:X>$topLeftX</dt:X>
          <dt:Y>$topLeftY</dt:Y>
        </dt:TopLeft>
      </ns:request>
    </ns:GetMapByPixelCoordinates>
  </soapenv:Body>
</soapenv:Envelope>
''';

    final headers = <String, String>{
      'Content-Type': 'text/xml; charset=utf-8',
      'SOAPAction': 'http://mapservice.soap.api/2024/IMapService/GetMapByPixelCoordinates',
    };

    final resp = await http
        .post(endpoint, headers: headers, body: envelope)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final doc = xml.XmlDocument.parse(resp.body);

    // Helper to find first element by local name (ignore namespaces)
    xml.XmlElement? _firstByLocal(String local) {
      final it = doc.descendants.whereType<xml.XmlElement>();
      for (final e in it) {
        if (e.name.local == local) return e;
      }
      return null;
    }

    // Try to read ImageData regardless of Success flag (some services may omit Success)
    final imageNode = _firstByLocal('ImageData') ?? doc.findAllElements('ImageData').firstOrNull;

    // Read Success if present
    final successNode = _firstByLocal('Success') ?? doc.findAllElements('Success').firstOrNull;
    final isSuccess = successNode?.innerText.trim().toLowerCase() == 'true';

    // If we have image data, prefer returning it even if Success flag is missing/false
    if (imageNode != null) {
      final imgB64 = imageNode.innerText.trim();
      if (imgB64.isNotEmpty) {
        return base64Decode(imgB64);
      }
    }

    // Otherwise, if explicitly successful but no image found, treat as error
    if (isSuccess == true) {
      throw Exception('Service error: No ImageData in response');
    }

    // Extract message (namespace-agnostic)
    final messageNode = _firstByLocal('Message') ?? doc.findAllElements('Message').firstOrNull;
    final msg = messageNode?.innerText.trim().isNotEmpty == true
        ? messageNode!.innerText.trim()
        : 'Unknown error';

    throw Exception('Service error: $msg');
  }

  /// Calls SOAP method GetMapByGeoCoordinates.
  /// [topLeftLat],[topLeftLon],[bottomRightLat],[bottomRightLon] define geo rectangle.
  /// [imageBytes] is the source image used by backend.
  /// Returns decoded JPEG bytes on success.
  Future<Uint8List> getMapByGeoCoordinates({
    required double topLeftLat,
    required double topLeftLon,
    required double bottomRightLat,
    required double bottomRightLon,
    required Uint8List imageBytes,
  }) async {
    final endpoint = Uri.parse('$baseUrl/MapService.svc');

    final imageBase64 = base64Encode(imageBytes);

    const svcNs = 'http://mapservice.soap.api/2024';
    const modelNs = 'http://schemas.datacontract.org/2004/07/SoapWebApi.Models';

    final envelope = '''
<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns="$svcNs" xmlns:dt="$modelNs">
  <soapenv:Header/>
  <soapenv:Body>
    <ns:GetMapByGeoCoordinates>
      <ns:request>
        <dt:TopLeft>
          <dt:Latitude>$topLeftLat</dt:Latitude>
          <dt:Longitude>$topLeftLon</dt:Longitude>
        </dt:TopLeft>
        <dt:BottomRight>
          <dt:Latitude>$bottomRightLat</dt:Latitude>
          <dt:Longitude>$bottomRightLon</dt:Longitude>
        </dt:BottomRight>
        <dt:ImageData>$imageBase64</dt:ImageData>
      </ns:request>
    </ns:GetMapByGeoCoordinates>
  </soapenv:Body>
</soapenv:Envelope>
''';

    final headers = <String, String>{
      'Content-Type': 'text/xml; charset=utf-8',
      'SOAPAction': 'http://mapservice.soap.api/2024/IMapService/GetMapByGeoCoordinates',
    };

    final resp = await http
        .post(endpoint, headers: headers, body: envelope)
        .timeout(const Duration(seconds: 15));
    print(resp.body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final doc = xml.XmlDocument.parse(resp.body);

    xml.XmlElement? _firstByLocal(String local) {
      final it = doc.descendants.whereType<xml.XmlElement>();
      for (final e in it) {
        if (e.name.local == local) return e;
      }
      return null;
    }

    final imageNode = _firstByLocal('ImageData') ?? doc.findAllElements('ImageData').firstOrNull;
    if (imageNode != null) {
      final b64 = imageNode.innerText.trim();
      if (b64.isNotEmpty) {
        return base64Decode(b64);
      }
    }

    final messageNode = _firstByLocal('Message') ?? doc.findAllElements('Message').firstOrNull;
    final msg = messageNode?.innerText.trim().isNotEmpty == true
        ? messageNode!.innerText.trim()
        : 'Unknown error';
    throw Exception('Service error: $msg');
  }

  /// Client-side geo→pixel conversion using the confirmed anchors
  /// and then call the working pixel endpoint. This bypasses SOAP
  /// deserialization fragility for the Geo operation.
  Future<Uint8List> getMapByGeoViaPixel({
    required double topLeftLat,
    required double topLeftLon,
    required double bottomRightLat,
    required double bottomRightLon,
    required Uint8List imageBytes,
    int imageWidth = _defaultImageWidth,
    int imageHeight = _defaultImageHeight,
  }) async {
    // Convert both corners to image pixel space (origin at top-left)
    final tl = _geoToPixel(topLeftLat, topLeftLon, imageWidth, imageHeight);
    final br = _geoToPixel(bottomRightLat, bottomRightLon, imageWidth, imageHeight);

    // Normalize rectangle: ensure left<right and top<bottom
    final left = tl.$1 < br.$1 ? tl.$1 : br.$1;
    final right = tl.$1 < br.$1 ? br.$1 : tl.$1;
    final top = tl.$2 < br.$2 ? tl.$2 : br.$2;
    final bottom = tl.$2 < br.$2 ? br.$2 : tl.$2;

    return getMapByPixelCoordinates(
      topLeftX: left,
      topLeftY: top,
      bottomRightX: right,
      bottomRightY: bottom,
      imageBytes: imageBytes,
    );
  }

  /// Returns (x,y) in image pixel space (top-left origin)
  /// Using linear interpolation between the geo anchors.
  /// Values are clamped to [0..W]x[0..H].
  (int, int) _geoToPixel(double lat, double lon, int w, int h) {
    // Normalize lon to [0,1] left→right
    double nLon = (lon - _anchorMinLon) / (_anchorMaxLon - _anchorMinLon);
    // Normalize lat to [0,1] top→bottom (invert because lat increases northward)
    double nLat = (_anchorMaxLat - lat) / (_anchorMaxLat - _anchorMinLat);

    // Clamp
    nLon = nLon.clamp(0.0, 1.0);
    nLat = nLat.clamp(0.0, 1.0);

    final x = (nLon * w).toInt();
    final y = (nLat * h).toInt();
    return (x, y);
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
