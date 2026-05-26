import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/services/auth_service.dart';
import 'package:histolink/shared/config/api_config.dart';
import 'package:histolink/SeguridadAvanzadaYAdministracion/BreakGlass_Solicitud/models/break_glass_solicitud_model.dart';

class BreakGlassApiException implements Exception {
  const BreakGlassApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

class BreakGlassSolicitudService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw const BreakGlassApiException('Sesión no válida. Vuelve a iniciar sesión.', statusCode: 401);
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<BreakGlassSolicitudModel> crearSolicitud({
    required int pacienteId,
    required String justificacion,
    required String nivelUrgencia,
  }) async {
    final resp = await http.post(
      ApiConfig.uri('/api/seguridad/break-glass/solicitar/'),
      headers: await _headers(),
      body: jsonEncode({
        'paciente_id': pacienteId,
        'justificacion': justificacion,
        'nivel_urgencia': nivelUrgencia,
      }),
    );

    final data = _safeMap(resp.body);
    if (resp.statusCode == 201) {
      return BreakGlassSolicitudModel.fromJson(data);
    }
    throw BreakGlassApiException(_extractMessage(resp.statusCode, data), statusCode: resp.statusCode);
  }

  Future<List<BreakGlassSolicitudModel>> misSolicitudes() async {
    final resp = await http.get(
      ApiConfig.uri('/api/seguridad/break-glass/mis-solicitudes/'),
      headers: await _headers(),
    );
    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(BreakGlassSolicitudModel.fromJson)
            .toList();
      }
      return const [];
    }
    final data = _safeMap(resp.body);
    throw BreakGlassApiException(_extractMessage(resp.statusCode, data), statusCode: resp.statusCode);
  }

  Map<String, dynamic> _safeMap(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) return d;
      return {};
    } catch (_) {
      return {};
    }
  }

  String _extractMessage(int code, Map<String, dynamic> data) {
    final detail = (data['detail'] ?? data['error'])?.toString();
    if (detail != null && detail.trim().isNotEmpty) return detail;
    if (data['justificacion'] is List && (data['justificacion'] as List).isNotEmpty) {
      return (data['justificacion'] as List).first.toString();
    }
    if (code == 400) return 'Solicitud inválida. Revisa la justificación y los campos.';
    if (code == 401) return 'Tu sesión expiró. Inicia sesión nuevamente.';
    if (code == 403) return 'No tienes permisos para solicitar acceso de emergencia.';
    if (code == 404) return 'No se encontró el paciente solicitado.';
    return 'No se pudo procesar la solicitud de emergencia.';
  }
}

