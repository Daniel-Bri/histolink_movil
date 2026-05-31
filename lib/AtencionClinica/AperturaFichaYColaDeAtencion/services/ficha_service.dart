import 'dart:convert';
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
    String? motivoConsulta,
  }) async {
    final body = <String, dynamic>{'paciente': pacienteId};
    if (motivoConsulta != null && motivoConsulta.trim().isNotEmpty) {
      body['motivo_consulta'] = motivoConsulta.trim();
    }
    final res = await _api.post(_base, body: body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return FichaModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    String msg = 'Error al crear ficha';
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        final detail = decoded['detail'] ?? decoded['non_field_errors'];
        if (detail != null) msg = detail.toString();
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
