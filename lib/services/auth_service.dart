import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  // En emulador Android usa 10.0.2.2 para acceder a localhost de la PC.
  // En dispositivo físico, cambia por la IP local de tu PC (ej: 192.168.1.x).
  static const String _baseUrl = 'http://10.0.2.2:8000/api/auth';

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';

  Future<UserModel> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, data['access']);
      await prefs.setString(_keyRefreshToken, data['refresh']);
      return UserModel.fromJson(data['user']);
    } else {
      final data = jsonDecode(response.body);
      final message = data['detail'] ?? data['non_field_errors']?[0] ?? 'Credenciales incorrectas';
      throw Exception(message);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_keyRefreshToken);

    if (refresh != null) {
      final token = prefs.getString(_keyAccessToken);
      try {
        await http.post(
          Uri.parse('$_baseUrl/logout/'),
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

    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyAccessToken);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }
}
