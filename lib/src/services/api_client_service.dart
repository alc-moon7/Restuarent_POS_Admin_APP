import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClientService {
  Future<Map<String, dynamic>> getHealth(String baseUrl) async {
    return _getJson(Uri.parse('$baseUrl/health'));
  }

  Future<Map<String, dynamic>> getMenu(
    String baseUrl, {
    bool includeUnavailable = false,
  }) async {
    final uri = Uri.parse('$baseUrl/menu').replace(
      queryParameters: includeUnavailable
          ? const {'includeUnavailable': 'true'}
          : null,
    );
    return _getJson(uri);
  }

  Future<Map<String, dynamic>> createOrder(
    String baseUrl,
    Map<String, Object?> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri);
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }
}
