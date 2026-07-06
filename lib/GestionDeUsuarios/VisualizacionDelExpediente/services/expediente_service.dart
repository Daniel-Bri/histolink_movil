import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:histolink/shared/config/api_config.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/services/auth_service.dart';
import 'package:histolink/GestionDeUsuarios/VisualizacionDelExpediente/models/expediente_resumido_model.dart';

class ExpedienteApiException implements Exception {
  const ExpedienteApiException(
    this.message, {
    this.statusCode,
    this.data,
  });

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? data;
}

class ExpedienteService {
  final AuthService _authService = AuthService();

  Future<ExpedienteResumido> obtenerExpedienteResumido(int pacienteId) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const ExpedienteApiException(
        'Sesión no válida. Vuelve a iniciar sesión.',
        statusCode: 401,
      );
    }

    final response = await http.get(
      ApiConfig.uri('/api/expediente/$pacienteId/expediente/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return ExpedienteResumido.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final message =
        (data['error'] ?? data['detail'] ?? 'No se pudo cargar el expediente.')
            .toString();
    throw ExpedienteApiException(message, statusCode: response.statusCode, data: data);
  }

  /// Sprint 5 — Expediente del propio paciente autenticado (rol Paciente).
  /// Resuelve el paciente por el email del usuario; no requiere ID.
  Future<ExpedienteResumido> obtenerMiExpediente() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const ExpedienteApiException(
        'Sesión no válida. Vuelve a iniciar sesión.',
        statusCode: 401,
      );
    }

    final response = await http.get(
      ApiConfig.uri('/api/expediente/mi-expediente/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return ExpedienteResumido.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final message = (data['error'] ??
            data['detail'] ??
            'No se pudo cargar tu expediente.')
        .toString();
    throw ExpedienteApiException(message, statusCode: response.statusCode, data: data);
  }
}
