import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

class ApiService {
  static final _storage = const FlutterSecureStorage();

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<void> setToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};

    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
    );

    return _handle(res);
  }

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );

    return _handle(res);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    return _handle(res);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    return _handle(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await http.delete(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
    );

    return _handle(res);
  }

  static Future<dynamic> uploadFile(String path, File file) async {
    final token = await getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiUrl}$path'),
    );

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    return _handle(res);
  }

  static Future<dynamic> uploadBytes(
    String path, {
    required List<int> bytes,
    required String filename,
  }) async {
    final token = await getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiUrl}$path'),
    );

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    return _handle(res);
  }

  static dynamic _handle(http.Response res) {
    dynamic body = {};

    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = {'message': res.body};
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }

    if (body is Map && body['message'] != null) {
      throw Exception(body['message']);
    }

    throw Exception('Request failed: ${res.statusCode}');
  }
}
