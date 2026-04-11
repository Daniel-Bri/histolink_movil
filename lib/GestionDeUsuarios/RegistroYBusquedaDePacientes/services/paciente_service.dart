import 'dart:convert';
import 'package:histolink/shared/services/api_service.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';

class PacienteApiException implements Exception {
  PacienteApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PacienteService {
  PacienteService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static const String _base = '/api/pacientes/';

  String _formatErrorBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail != null) return detail.toString();
        final parts = <String>[];
        decoded.forEach((key, value) {
          if (value is List) {
            parts.add('$key: ${value.map((e) => e.toString()).join(", ")}');
          } else if (value is String) {
            parts.add('$key: $value');
          } else if (value != null) {
            parts.add('$key: $value');
          }
        });
        if (parts.isNotEmpty) return parts.join('\n');
      }
    } catch (_) {}
    return 'No se pudo completar la operación';
  }

  List<PacienteModel> _parseList(String body) {
    final decoded = jsonDecode(body);
    List<dynamic> raw;
    if (decoded is Map<String, dynamic> && decoded['results'] is List) {
      raw = decoded['results'] as List<dynamic>;
    } else if (decoded is List) {
      raw = decoded;
    } else {
      return [];
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PacienteModel.fromJson)
        .toList();
  }

  /// Lista o busca pacientes. Si [search] está vacío, pide el listado sin filtro.
  Future<List<PacienteModel>> listar({String? search}) async {
    final query = <String, String>{};
    final s = search?.trim();
    if (s != null && s.isNotEmpty) query['search'] = s;

    final res = await _api.get(_base, queryParameters: query.isEmpty ? null : query);
    if (res.statusCode == 200) {
      return _parseList(res.body);
    }
    throw PacienteApiException(_formatErrorBody(res.body), statusCode: res.statusCode);
  }

  Future<PacienteModel> obtener(int id) async {
    final res = await _api.get('/api/pacientes/$id/');
    if (res.statusCode == 200) {
      return PacienteModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw PacienteApiException(_formatErrorBody(res.body), statusCode: res.statusCode);
  }

  Future<PacienteModel> crear(PacienteModel datos) async {
    final res = await _api.post(_base, body: datos.toCreateJson());
    if (res.statusCode == 200 || res.statusCode == 201) {
      return PacienteModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw PacienteApiException(_formatErrorBody(res.body), statusCode: res.statusCode);
  }
}
