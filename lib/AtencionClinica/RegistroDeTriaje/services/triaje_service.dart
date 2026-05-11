import 'dart:convert';
import 'package:histolink/shared/services/api_service.dart';
import '../models/ficha_model.dart';

class TriajeApiException implements Exception {
  const TriajeApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TriajeService {
  TriajeService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static const _baseFichas = '/api/fichas/';
  static const _baseTriaje = '/api/triaje/';

  String _fmtError(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map<String, dynamic>) {
        final detail = d['detail'];
        if (detail != null) return detail.toString();
        final parts = <String>[];
        d.forEach((k, v) {
          if (v is List) {
            parts.addAll(v.map((e) => e.toString()));
          } else if (v != null) {
            parts.add('$k: $v');
          }
        });
        if (parts.isNotEmpty) return parts.join('\n');
      }
    } catch (_) {}
    return 'Error desconocido';
  }

  /// GET /api/fichas/?paciente=<id>&en_curso=true
  Future<List<FichaModel>> listarFichasAbiertas(int pacienteId) async {
    final res = await _api.get(_baseFichas, queryParameters: {
      'paciente': pacienteId.toString(),
      'en_curso': 'true',
    });
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final List<dynamic> raw = decoded is Map
          ? ((decoded['results'] ?? []) as List<dynamic>)
          : (decoded is List ? decoded : []);
      return raw.whereType<Map<String, dynamic>>().map(FichaModel.fromJson).toList();
    }
    throw TriajeApiException(_fmtError(res.body), statusCode: res.statusCode);
  }

  /// POST /api/triaje/clasificar/ — clasifica sin guardar en BD
  Future<Map<String, dynamic>> clasificar({
    String motivoConsulta = '',
    int? saturacionOxigeno,
    int? presionSistolica,
    int? frecuenciaCardiaca,
    int? escalaDolor,
    int? glasgow,
  }) async {
    final body = <String, dynamic>{};
    if (motivoConsulta.isNotEmpty) body['motivo_consulta_triaje'] = motivoConsulta;
    if (saturacionOxigeno != null) body['saturacion_oxigeno'] = saturacionOxigeno;
    if (presionSistolica != null) body['presion_sistolica'] = presionSistolica;
    if (frecuenciaCardiaca != null) body['frecuencia_cardiaca'] = frecuenciaCardiaca;
    if (escalaDolor != null) body['escala_dolor'] = escalaDolor;
    if (glasgow != null) body['glasgow'] = glasgow;

    final res = await _api.post('${_baseTriaje}clasificar/', body: body);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw TriajeApiException(_fmtError(res.body), statusCode: res.statusCode);
  }

  /// POST /api/triaje/ — guarda triaje confirmado por enfermería
  Future<Map<String, dynamic>> guardar(Map<String, dynamic> data) async {
    final res = await _api.post(_baseTriaje, body: data);
    if (res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw TriajeApiException(_fmtError(res.body), statusCode: res.statusCode);
  }
}
