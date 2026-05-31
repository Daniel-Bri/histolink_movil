import 'dart:convert';
import 'package:histolink/shared/services/api_service.dart';

class RiesgoApiException implements Exception {
  RiesgoApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class RiesgoService {
  RiesgoService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  /// Llama a GET /api/ia/riesgo/?paciente_id=[pacienteId] y devuelve el
  /// objeto JSON crudo para que el widget lo interprete directamente.
  Future<Map<String, dynamic>> obtenerRiesgo(int pacienteId) async {
    final res = await _api.get(
      '/api/ia/riesgo/',
      queryParameters: {'paciente_id': pacienteId.toString()},
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) return body;
      throw RiesgoApiException(
        'Respuesta inesperada del servidor',
        statusCode: res.statusCode,
      );
    }

    String msg = 'Error al obtener predicción de riesgo (${res.statusCode})';
    try {
      final err = jsonDecode(res.body);
      if (err is Map && err['detail'] != null) msg = err['detail'].toString();
    } catch (_) {}
    throw RiesgoApiException(msg, statusCode: res.statusCode);
  }
}
