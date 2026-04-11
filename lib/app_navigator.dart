import 'package:flutter/material.dart';

/// Clave global para redirigir a login cuando el token expira (desde [ApiService]).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
