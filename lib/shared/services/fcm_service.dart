import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Handler para mensajes recibidos con la app en BACKGROUND o TERMINADA
// Debe ser una función de nivel superior (no dentro de una clase)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Mensaje en background: ${message.notification?.title}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Callback para mostrar notificación en primer plano (SnackBar / banner)
  void Function(String titulo, String cuerpo, Map<String, dynamic> datos)? onNotificacion;

  Future<void> init() async {
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

    // Obtener y registrar token
    await _registrarToken();

    // Escuchar cuando el token cambia (ej: reinstalación de app)
    _messaging.onTokenRefresh.listen((nuevoToken) async {
      await _guardarToken(nuevoToken);
      await _enviarTokenAlBackend(nuevoToken);
    });

    // Mensajes recibidos con la app en PRIMER PLANO
    FirebaseMessaging.onMessage.listen((message) {
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
      await _enviarTokenAlBackend(token);
    } catch (e) {
      debugPrint('[FCM] Error al obtener token: $e');
    }
  }

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

  Future<void> eliminarToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      if (token == null) return;

      final accessToken = prefs.getString('access_token');
      if (accessToken == null) return;

      await http.delete(
        Uri.parse('http://10.0.2.2:8000/api/notificaciones/token/eliminar/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'token': token}),
      );
      await prefs.remove('fcm_token');
    } catch (e) {
      debugPrint('[FCM] Error al eliminar token: $e');
    }
  }
}
