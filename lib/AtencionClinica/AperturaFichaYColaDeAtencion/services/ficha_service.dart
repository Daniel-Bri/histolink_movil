import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:histolink/shared/services/api_service.dart';
import '../../RegistroDeTriaje/models/ficha_model.dart';

class FichaApiException implements Exception {
  const FichaApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class FichaService {
  FichaService({ApiService? api}) : _api = api ?? ApiService();
  final ApiService _api;
  static const _base = '/api/fichas/';

  Future<List<FichaModel>> listarFichasDelDia(String fecha) async {
    final res = await _api.get(_base, queryParameters: {
      'fecha_desde': fecha,
      'fecha_hasta': fecha,
      'page_size': '100',
    });
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final List<dynamic> raw = decoded is Map
          ? ((decoded['results'] ?? []) as List<dynamic>)
          : (decoded is List ? decoded : []);
      return raw.whereType<Map<String, dynamic>>().map(FichaModel.fromJson).toList();
    }
    throw FichaApiException('Error al cargar fichas', statusCode: res.statusCode);
  }

  Future<FichaModel> crearFicha({
    required int pacienteId,
    required int medicoId,
    String? motivoConsulta,
  }) async {
    final body = <String, dynamic>{
      'paciente_id': pacienteId,  // int — ID del paciente
      'medico': medicoId,         // int — ID del usuario médico
    };
    if (motivoConsulta != null && motivoConsulta.trim().isNotEmpty) {
      body['motivo_consulta'] = motivoConsulta.trim();
    }

    debugPrint('FichaService.crearFicha → POST $_base payload: $body');

    final res = await _api.post(_base, body: body);

    debugPrint('FichaService.crearFicha ← ${res.statusCode} body: ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      return FichaModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }

    // Extraer el mensaje de error más descriptivo del body de Django
    String msg = 'Error ${res.statusCode} al crear ficha';
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        // Django devuelve errores por campo: {"paciente": ["..."], "medico": ["..."]}
        final camposConError = decoded.entries
            .where((e) => e.key != 'detail')
            .map((e) => '${e.key}: ${e.value}')
            .join(' | ');
        final detail = decoded['detail'] ?? decoded['non_field_errors'];
        if (camposConError.isNotEmpty) {
          msg = camposConError;
        } else if (detail != null) {
          msg = detail.toString();
        }
        debugPrint('ERROR DETALLADO DJANGO (fichas 400): ${res.body}');
      }
    } catch (_) {}
    throw FichaApiException(msg, statusCode: res.statusCode);
  }

  Future<void> cambiarEstado(int id, String nuevoEstado) async {
    final res = await _api.patch('$_base$id/', body: {'estado': nuevoEstado});
    if (res.statusCode != 200) {
      throw FichaApiException('Error al cambiar estado', statusCode: res.statusCode);
    }
  }
}
