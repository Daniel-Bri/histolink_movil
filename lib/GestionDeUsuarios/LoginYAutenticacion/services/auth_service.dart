import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:histolink/shared/models/user_model.dart';

class AuthService {
  // Se selecciona automáticamente según la plataforma:
  //   Web/Chrome        → localhost:8000
  //   Emulador Android  → 10.0.2.2:8000
  //   Dispositivo físico → cambia a la IP local de tu PC
  static String get _host =>
      kIsWeb ? 'localhost:8000' : '10.0.2.2:8000';

  static Uri _uri(String path) => Uri.http(_host, path);

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
}
