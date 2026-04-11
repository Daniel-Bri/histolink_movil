import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración centralizada de la URL del backend.
///
/// Para dispositivo físico, pasar el host en tiempo de compilación:
///   flutter run --dart-define=API_HOST=192.168.x.x:8000
///
/// Si API_HOST no se define, se usa automáticamente:
///   - Web/Chrome     → localhost:8000
///   - Emulador Android → 10.0.2.2:8000
class ApiConfig {
  ApiConfig._();

  static const String _customHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get host {
    if (_customHost.isNotEmpty) return _customHost;
    return kIsWeb ? 'localhost:8000' : '10.0.2.2:8000';
  }

  static Uri uri(String path) => Uri.http(host, path);
}
