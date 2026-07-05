import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Handler para mensajes recibidos con la app en BACKGROUND o TERMINADA
// Debe ser una función de nivel superior (no dentro de una clase)
=======
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:histolink/shared/config/api_config.dart';
import 'package:histolink/app_navigator.dart';

// Handler para mensajes recibidos con la app en BACKGROUND o TERMINADA.
// Debe ser una función de nivel superior (no dentro de una clase).
// En Android, las notificaciones con payload `notification` las muestra el
// sistema automáticamente en la bandeja; aquí solo dejamos traza.
>>>>>>> servidor
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Mensaje en background: ${message.notification?.title}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

<<<<<<< HEAD
  // Callback para mostrar notificación en primer plano (SnackBar / banner)
  void Function(String titulo, String cuerpo, Map<String, dynamic> datos)? onNotificacion;

  Future<void> init() async {
=======
  // Los tokens de sesión viven en FlutterSecureStorage (igual que AuthService),
  // NO en SharedPreferences. Leerlos del lugar equivocado era la causa de que el
  // token FCM nunca llegara al backend.
  static const _storage = FlutterSecureStorage();
  static const _keyAccessToken = 'access_token';

  // Evita registrar los listeners más de una vez (init() se llamaba al arrancar
  // y otra vez tras el login → listeners y callbacks duplicados).
  bool _listenersListos = false;
  String? _ultimoToken;

  // Callback opcional para mostrar la notificación en primer plano de forma
  // personalizada. Si es null, se usa un SnackBar global por defecto.
  void Function(String titulo, String cuerpo, Map<String, dynamic> datos)? onNotificacion;

  /// Registra permisos y listeners UNA sola vez. Llamar en `main()`.
  /// Si ya hay una sesión activa, también sincroniza el token al final.
  Future<void> init() async {
    if (_listenersListos) return;
    _listenersListos = true;

>>>>>>> servidor
    // Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Solicitar permisos (Android 13+ y iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Permiso de notificaciones denegado');
      return;
    }

<<<<<<< HEAD
    // Obtener y registrar token
    await _registrarToken();

    // Escuchar cuando el token cambia (ej: reinstalación de app)
    _messaging.onTokenRefresh.listen((nuevoToken) async {
      await _guardarToken(nuevoToken);
=======
    // Escuchar cuando el token cambia (ej: reinstalación de app)
    _messaging.onTokenRefresh.listen((nuevoToken) async {
      _ultimoToken = nuevoToken;
>>>>>>> servidor
      await _enviarTokenAlBackend(nuevoToken);
    });

    // Mensajes recibidos con la app en PRIMER PLANO
    FirebaseMessaging.onMessage.listen((message) {
<<<<<<< HEAD
      final titulo = message.notification?.title ?? 'Histolink';
      final cuerpo = message.notification?.body  ?? '';
      final datos  = message.data;
      debugPrint('[FCM] Mensaje en primer plano: $titulo');
      onNotificacion?.call(titulo, cuerpo, datos);
    });

    // App abierta desde una notificación (estaba en background)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] App abierta desde notificación: ${message.data}');
      // TODO: navegar a la pantalla correspondiente según message.data['tipo']
    });
  }

  Future<void> _registrarToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      debugPrint('[FCM] Token: ${token.substring(0, 20)}…');
      await _guardarToken(token);
=======
      final titulo = message.notification?.title ?? (message.data['title'] as String?) ?? 'Histolink';
      final cuerpo = message.notification?.body ?? (message.data['body'] as String?) ?? '';
      debugPrint('[FCM] Mensaje en primer plano: $titulo');
      _mostrarEnPrimerPlano(titulo, cuerpo, message.data);
    });

    // App abierta desde una notificación (estaba en background)
    FirebaseMessaging.onMessageOpenedApp.listen(_abrirDesdeNotificacion);

    // App abierta desde estado TERMINADO por tocar una notificación
    final inicial = await _messaging.getInitialMessage();
    if (inicial != null) _abrirDesdeNotificacion(inicial);

    // Si ya hay sesión (app reabierta logueada), registra el token ahora.
    await sincronizarToken();
  }

  /// Obtiene el token FCM y lo registra en el backend. Llamar tras un login
  /// exitoso, cuando ya existe `access_token` en el almacenamiento seguro.
  /// Es idempotente (upsert en el backend), así que puede llamarse varias veces.
  Future<void> sincronizarToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      _ultimoToken = token;
      debugPrint('[FCM] Token: ${token.substring(0, 20)}…');
>>>>>>> servidor
      await _enviarTokenAlBackend(token);
    } catch (e) {
      debugPrint('[FCM] Error al obtener token: $e');
    }
  }

<<<<<<< HEAD
  Future<void> _guardarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  Future<void> _enviarTokenAlBackend(String token) async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null) return;

      const baseUrl = 'http://10.0.2.2:8000/api/notificaciones/token/';
      final resp = await http.post(
        Uri.parse(baseUrl),
=======
  void _mostrarEnPrimerPlano(String titulo, String cuerpo, Map<String, dynamic> datos) {
    if (onNotificacion != null) {
      onNotificacion!.call(titulo, cuerpo, datos);
      return;
    }
    // Por defecto: SnackBar global, así las notificaciones en primer plano
    // siempre se ven aunque ninguna pantalla haya configurado un callback.
    final messenger = appScaffoldMessengerKey.currentState;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(cuerpo.isEmpty ? titulo : '$titulo\n$cuerpo'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _abrirDesdeNotificacion(RemoteMessage message) {
    debugPrint('[FCM] App abierta desde notificación: ${message.data}');
    // La navegación profunda según message.data['tipo'] queda como punto de
    // extensión: las pantallas destino (cola de fichas) aún son stubs y
    // requieren el UserModel de la sesión, que no está disponible aquí.
    onNotificacionAbierta?.call(message.data);
  }

  /// Hook opcional para reaccionar cuando el usuario abre la app tocando una
  /// notificación (deep-link). Lo puede asignar la pantalla raíz logueada.
  void Function(Map<String, dynamic> datos)? onNotificacionAbierta;

  Future<void> _enviarTokenAlBackend(String token) async {
    try {
      final accessToken = await _storage.read(key: _keyAccessToken);
      if (accessToken == null) return;

      final resp = await http.post(
        ApiConfig.uri('/api/notificaciones/token/'),
>>>>>>> servidor
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'token': token, 'plataforma': 'android'}),
      );
      debugPrint('[FCM] Token enviado al backend: ${resp.statusCode}');
    } catch (e) {
      debugPrint('[FCM] Error al enviar token al backend: $e');
    }
  }

<<<<<<< HEAD
  Future<void> eliminarToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      if (token == null) return;

      final accessToken = prefs.getString('access_token');
      if (accessToken == null) return;

      await http.delete(
        Uri.parse('http://10.0.2.2:8000/api/notificaciones/token/eliminar/'),
=======
  /// Desactiva el token en el backend al cerrar sesión.
  /// IMPORTANTE: llamar ANTES de que AuthService borre el access_token.
  Future<void> eliminarToken() async {
    try {
      final accessToken = await _storage.read(key: _keyAccessToken);
      final token = _ultimoToken ?? await _messaging.getToken();
      if (accessToken == null || token == null) return;

      await http.delete(
        ApiConfig.uri('/api/notificaciones/token/eliminar/'),
>>>>>>> servidor
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'token': token}),
      );
<<<<<<< HEAD
      await prefs.remove('fcm_token');
=======
      _ultimoToken = null;
>>>>>>> servidor
    } catch (e) {
      debugPrint('[FCM] Error al eliminar token: $e');
    }
  }
}
