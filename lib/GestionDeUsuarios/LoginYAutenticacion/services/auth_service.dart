import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/config/api_config.dart';

class AuthService {
  static Uri _uri(String path) => ApiConfig.uri(path);

  // Android Keystore (AES-256) en Android · Keychain en iOS
  static const _storage = FlutterSecureStorage();

  static const String _keyAccessToken  = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUsername     = 'cached_username';

  Future<UserModel> login(String username, String password) async {
    final response = await http.post(
      _uri('/api/auth/login/'),
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
          _uri('/api/auth/logout/'),
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

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _keyAccessToken);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  Future<String> getCachedUsername() async {
    return await _storage.read(key: _keyUsername) ?? '';
  }

  /// Renueva el access token con el refresh guardado. Devuelve false si no hay refresh o falla la petición.
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
