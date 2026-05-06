import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/services/auth_service.dart';
import 'package:histolink/GestionDeUsuarios/VisualizacionDelExpediente/models/expediente_resumido_model.dart';

class ExpedienteService {
  static String get _host => kIsWeb ? 'localhost:8000' : '192.168.0.108:8000';

  static Uri _uri(String path) => Uri.http(_host, path);

  final AuthService _authService = AuthService();

  Future<ExpedienteResumido> obtenerExpedienteResumido(int pacienteId) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesion no valida. Vuelve a iniciar sesion.');
    }

    final response = await http.get(
      _uri('/api/expediente/$pacienteId/expediente/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return ExpedienteResumido.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = (data['error'] ?? data['detail'] ?? 'No se pudo cargar el expediente.').toString();
    throw Exception(message);
  }
}
