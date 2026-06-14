import 'dart:convert';

import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/services/auth_service.dart';
import 'package:histolink/SeguridadAvanzadaYAdministracion/BreakGlass_Solicitud/models/break_glass_solicitud_model.dart';
import 'package:histolink/shared/config/api_config.dart';
import 'package:http/http.dart' as http;

class BreakGlassAprobacionException implements Exception {
  const BreakGlassAprobacionException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

class BreakGlassAprobacionService {
  final AuthService _auth = AuthService();
  static const _basePath = '/api/seguridad/break-glass/';

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw const BreakGlassAprobacionException(
        'Tu sesión expiró. Vuelve a iniciar sesión.',
        statusCode: 401,
      );
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<BreakGlassSolicitudModel>> listarPendientes() async {
    final resp = await http.get(
      ApiConfig.uri('${_basePath}pendientes/'),
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

    throw BreakGlassAprobacionException(
      _extractMessage(resp.statusCode, _safeMap(resp.body)),
      statusCode: resp.statusCode,
    );
  }

  Future<Map<String, dynamic>> aprobar(int solicitudId) async {
    final resp = await http.post(
      ApiConfig.uri('$_basePath$solicitudId/aprobar/'),
      headers: await _headers(),
    );
    final data = _safeMap(resp.body);
    if (resp.statusCode == 200) return data;
    throw BreakGlassAprobacionException(
      _extractMessage(resp.statusCode, data),
      statusCode: resp.statusCode,
    );
  }

  Future<Map<String, dynamic>> rechazar({
    required int solicitudId,
    required String motivoRechazo,
  }) async {
    final resp = await http.post(
      ApiConfig.uri('$_basePath$solicitudId/rechazar/'),
      headers: await _headers(),
      body: jsonEncode({'motivo_rechazo': motivoRechazo}),
    );
    final data = _safeMap(resp.body);
    if (resp.statusCode == 200) return data;
    throw BreakGlassAprobacionException(
      _extractMessage(resp.statusCode, data),
      statusCode: resp.statusCode,
    );
  }

  Map<String, dynamic> _safeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  String _extractMessage(int code, Map<String, dynamic> data) {
    final detail = (data['detail'] ?? data['error'])?.toString();
    if (detail != null && detail.trim().isNotEmpty) return detail;

    final motivo = data['motivo_rechazo'];
    if (motivo is List && motivo.isNotEmpty) return motivo.first.toString();

    if (code == 400) return 'La solicitud no pudo procesarse. Revisa los datos.';
    if (code == 401) return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    if (code == 403) return 'No tienes permisos para aprobar o rechazar esta solicitud.';
    if (code == 404) return 'La solicitud Break-Glass no fue encontrada.';
    if (code == 409) return 'La solicitud ya fue procesada por otro usuario.';
    if (code == 500) return 'Ocurrió un error del servidor. Intenta nuevamente.';
    return 'No se pudo completar la operación. Verifica tu conexión.';
  }
}
