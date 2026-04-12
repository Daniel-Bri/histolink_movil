import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/config/api_config.dart';

class AuthService {
  // encryptedSharedPreferences evita cuelgues de keystore en Android
  static final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyAccessToken  = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUsername     = 'cached_username';

  Future<UserModel> login(String username, String password) async {
    final response = await http.post(
      ApiConfig.uri('/api/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storage.write(key: _keyAccessToken,  value: data['access']  as String?);
      await _storage.write(key: _keyRefreshToken, value: data['refresh'] as String?);
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await _storage.write(key: _keyUsername, value: user.username);
      return user;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = (data['detail']
        ?? (data['non_field_errors'] as List?)?.first
        ?? 'Credenciales incorrectas')
        .toString();
    throw Exception(message);
  }

  Future<void> logout() async {
    final refresh = await _storage.read(key: _keyRefreshToken);
    if (refresh != null) {
      final token = await _storage.read(key: _keyAccessToken);
      try {
        await http.post(
          ApiConfig.uri('/api/auth/logout/'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'refresh': refresh}),
        );
      } catch (_) {
        // Si falla la llamada al servidor igual borramos localmente
      }
    }
    await _storage.deleteAll();
  }

  /// Verifica si hay sesión activa comprobando que el access token
  /// existe y no ha expirado (decodifica el claim `exp` del JWT).
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null || token.isEmpty) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '=';  break;
      }

      final decoded = jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      final exp = decoded['exp'] as int?;
      if (exp == null) return false;

      return DateTime.now().millisecondsSinceEpoch < exp * 1000;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getToken() => _storage.read(key: _keyAccessToken);

  Future<String> getCachedUsername() async =>
      await _storage.read(key: _keyUsername) ?? '';

  /// Renueva el access token con el refresh guardado.
  Future<bool> tryRefreshAccessToken() async {
    final refresh = await _storage.read(key: _keyRefreshToken);
    if (refresh == null || refresh.isEmpty) return false;

    final response = await http.post(
      ApiConfig.uri(ApiConfig.tokenRefreshPath),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );

    if (response.statusCode != 200) return false;

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final access = data['access'] as String?;
      if (access == null || access.isEmpty) return false;
      await _storage.write(key: _keyAccessToken, value: access);
      return true;
    } catch (_) {
      return false;
    }
  }
}
