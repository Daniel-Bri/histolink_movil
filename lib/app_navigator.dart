import 'package:flutter/material.dart';

/// Clave global para redirigir a login cuando el token expira (desde [ApiService]).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Clave global del ScaffoldMessenger para mostrar SnackBars desde cualquier
/// lugar sin un BuildContext (p.ej. notificaciones push en primer plano).
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
