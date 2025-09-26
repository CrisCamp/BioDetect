import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AIService {
  static const String _baseUrl = 'https://biodetect-417004325627.us-central1.run.app/';
  
  static Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/predict'),
      );

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'image.jpg',
        contentType: MediaType('image', 'jpg'),
      ));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(responseData);
        
        return {
          'predicted_class': jsonResponse['predicted_class'],
          'confidence': jsonResponse['confidence'],
        };
      } else {
        final errorData = await response.stream.bytesToString();
        final errorJson = jsonDecode(errorData);
        throw Exception(errorJson['error'] ?? 'Error del servidor');
      }
    } catch (e) {
      throw Exception('Error al analizar imagen: $e');
    }
  }
}