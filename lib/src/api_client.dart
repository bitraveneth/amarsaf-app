import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.offline = false});

  final String message;
  final int? status;
  final bool offline;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, this.timeout = const Duration(seconds: 25)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Future<Map<String, dynamic>> getJson(
    String root,
    String path, {
    String? token,
    Map<String, String>? query,
  }) {
    return _send(
      () => _client.get(_uri(root, path, query), headers: _headers(token)),
    );
  }

  Future<Map<String, dynamic>> postJson(
    String root,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) {
    return _send(
      () => _client.post(
        _uri(root, path),
        headers: _headers(token, json: true),
        body: jsonEncode(body ?? const {}),
      ),
    );
  }

  Future<Map<String, dynamic>> postMultipart(
    String root,
    String path, {
    required String token,
    required Map<String, String> fields,
    String? filePath,
    String fileField = 'attachment',
  }) {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(root, path));
      request.headers.addAll(_headers(token));
      request.fields.addAll(fields);
      if (filePath != null && filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
      }
      final streamed = await _client.send(request).timeout(timeout);
      return http.Response.fromStream(streamed);
    });
  }

  Map<String, String> _headers(String? token, {bool json = false}) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String root, String path, [Map<String, String>? query]) {
    final base = root.endsWith('/') ? root.substring(0, root.length - 1) : root;
    final suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$suffix').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() run,
  ) async {
    try {
      final response = await run().timeout(timeout);
      final decoded = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      throw ApiException(
        _message(decoded, response.body, response.statusCode),
        status: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('No network connection.', offline: true);
    } on TimeoutException {
      throw ApiException('The server took too long to answer.', offline: true);
    } on http.ClientException {
      throw ApiException('Could not reach the server.', offline: true);
    } on HandshakeException {
      throw ApiException('Could not reach the server.', offline: true);
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return {};
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) return parsed;
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
      return {'data': parsed};
    } catch (_) {
      return {'message': body};
    }
  }

  String _message(Map<String, dynamic> json, String raw, int status) {
    final errors = json['errors'];
    if (errors is Map) {
      final lines = <String>[];
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          lines.add('${value.first}');
        } else if (value != null) {
          lines.add('$value');
        }
      }
      if (lines.isNotEmpty) return lines.join('\n');
    }
    final message = json['message'];
    if (message is String && message.isNotEmpty) return message;
    if (raw.isNotEmpty && raw.length < 180) return raw;
    return 'Request failed ($status).';
  }
}
