import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class MapServiceClient {
  MapServiceClient({required this.baseUrl});

  /// Base URL of the SOAP service, e.g. http://localhost:5000
  final String baseUrl;

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

    // Build SOAP envelope matching the WSDL sample exactly (prefix names don't matter but we align them):
    final envelope = '''
<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns="$svcNs" xmlns:soap="$modelNs">
  <soapenv:Header/>
  <soapenv:Body>
    <ns:GetMapByPixelCoordinates>
      <ns:request>
        <soap:BottomRight>
          <soap:X>$bottomRightX</soap:X>
          <soap:Y>$bottomRightY</soap:Y>
        </soap:BottomRight>
        <soap:ImageData>$imageBase64</soap:ImageData>
        <soap:TopLeft>
          <soap:X>$topLeftX</soap:X>
          <soap:Y>$topLeftY</soap:Y>
        </soap:TopLeft>
      </ns:request>
    </ns:GetMapByPixelCoordinates>
  </soapenv:Body>
</soapenv:Envelope>
''';

    final headers = <String, String>{
      'Content-Type': 'text/xml; charset=utf-8',
      'SOAPAction': 'http://mapservice.soap.api/2024/IMapService/GetMapByPixelCoordinates',
    };

    final resp = await http.post(endpoint, headers: headers, body: envelope);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final doc = xml.XmlDocument.parse(resp.body);

    final successNode = doc.findAllElements('Success').firstOrNull;
    final isSuccess = successNode?.innerText.toLowerCase() == 'true';
    if (isSuccess != true) {
      final msg = doc.findAllElements('Message').firstOrNull?.innerText ?? 'Unknown error';
      throw Exception('Service error: $msg');
    }

    final imageNode = doc.findAllElements('ImageData').firstOrNull;
    if (imageNode == null) {
      throw Exception('No ImageData in response');
    }

    final base64 = imageNode.innerText.trim();
    return base64Decode(base64);
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
