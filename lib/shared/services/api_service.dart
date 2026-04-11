import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:histolink/app_navigator.dart';
import 'package:histolink/shared/config/api_config.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/services/auth_service.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/screens/login_screen.dart';

/// Cliente HTTP con Bearer JWT, reintento tras refresh y redirección a login en 401.
class ApiService {
  ApiService({AuthService? auth}) : _auth = auth ?? AuthService();

  final AuthService _auth;

  Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final token = await _auth.getToken();
    final h = <String, String>{
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    return h;
  }

  Future<void> _goToLogin() async {
    await _auth.logout();
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    bool jsonBody = false,
    bool retried = false,
  }) async {
    var response = await request(await _headers(jsonBody: jsonBody));
    if (response.statusCode == 401 && !retried) {
      final ok = await _auth.tryRefreshAccessToken();
      if (ok) {
        response = await request(await _headers(jsonBody: jsonBody));
      }
      if (response.statusCode == 401) {
        await _goToLogin();
      }
    }
    return response;
  }

  Future<http.Response> get(String path, {Map<String, String>? queryParameters}) {
    final uri = ApiConfig.uri(path, queryParameters);
    return _send((h) => http.get(uri, headers: h));
  }

  Future<http.Response> post(String path, {Object? body}) {
    final uri = ApiConfig.uri(path);
    return _send(
      (h) => http.post(uri, headers: h, body: body is String ? body : jsonEncode(body)),
      jsonBody: body != null,
    );
  }

  Future<http.Response> put(String path, {Object? body}) {
    final uri = ApiConfig.uri(path);
    return _send(
      (h) => http.put(uri, headers: h, body: body is String ? body : jsonEncode(body)),
      jsonBody: body != null,
    );
  }

  Future<http.Response> patch(String path, {Object? body}) {
    final uri = ApiConfig.uri(path);
    return _send(
      (h) => http.patch(uri, headers: h, body: body is String ? body : jsonEncode(body)),
      jsonBody: body != null,
    );
  }

  Future<http.Response> delete(String path) {
    final uri = ApiConfig.uri(path);
    return _send((h) => http.delete(uri, headers: h));
  }
}
