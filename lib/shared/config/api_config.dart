import 'package:flutter/foundation.dart' show kIsWeb;

/// Host y rutas base de la API (misma lógica que [AuthService]).
class ApiConfig {
  ApiConfig._();

  /// Ajusta si usas dispositivo físico: IP de tu PC en lugar de 10.0.2.2.
  static String get authority => kIsWeb ? 'localhost:8000' : '10.0.2.2:8000';

  /// Ruta POST para renovar access con refresh (simplejwt / variantes comunes).
  /// Si tu backend usa otra URL, cámbiala aquí (p. ej. `/api/token/refresh/`).
  static const String tokenRefreshPath = '/api/auth/token/refresh/';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.http(authority, p, queryParameters);
  }
}
