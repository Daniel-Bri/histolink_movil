import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/config/api_config.dart';

class AuthService {
  // Backend en Railway (producción)
  static const String _baseUrl = 'https://histolinkbackend-production.up.railway.app';

  static Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  // Android Keystore (AES-256) en Android · Keychain en iOS
  static const _storage = FlutterSecureStorage();

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
      final data = jsonDecode(response.body);
      await _storage.write(key: _keyAccessToken,  value: data['access']);
      await _storage.write(key: _keyRefreshToken, value: data['refresh']);
      final user = UserModel.fromJson(data['user']);
      await _storage.write(key: _keyUsername, value: user.username);
      return user;
    } else {
      final data = jsonDecode(response.body);
      final message = data['detail'] ?? data['non_field_errors']?[0] ?? 'Credenciales incorrectas';
      throw Exception(message);
    }
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
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'refresh': refresh}),
        );
      } catch (_) {
        // Si falla la llamada al servidor igual borramos localmente
      }
    }

    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUsername);
  }

  /// Verifica si hay sesión activa comprobando que el access token
  /// existe Y no ha expirado (decodifica el claim `exp` del JWT).
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null || token.isEmpty) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // base64url → base64 estándar (reemplazar chars y agregar padding)
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      final decoded = jsonDecode(utf8.decode(base64.decode(payload)));
      final exp = decoded['exp'] as int?;
      if (exp == null) return false;

      // exp es Unix timestamp en segundos
      return DateTime.now().millisecondsSinceEpoch < exp * 1000;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  Future<String> getCachedUsername() async {
    return await _storage.read(key: _keyUsername) ?? '';
  }
}
