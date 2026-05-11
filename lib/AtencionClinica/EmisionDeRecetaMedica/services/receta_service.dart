import 'dart:convert';
import 'package:histolink/shared/services/api_service.dart';
import '../models/receta_model.dart';

class RecetaApiException implements Exception {
  final String message;
  RecetaApiException(this.message);
}

class RecetaService {
  final _api = ApiService();

  Future<List<RecetaModel>> listar() async {
    final res = await _api.get('/api/clinica/recetas/');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data is Map ? (data['results'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => RecetaModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw RecetaApiException('Error al cargar recetas (${res.statusCode})');
  }

  Future<RecetaModel> crear({
    required int consultaId,
    required List<DetalleRecetaModel> detalles,
    String observaciones = '',
  }) async {
    final body = {
      'consulta': consultaId,
      'observaciones': observaciones,
      'detalles': detalles.asMap().entries.map((e) {
        final d = e.value.toJson();
        d['orden'] = e.key + 1;
        return d;
      }).toList(),
    };
    final res = await _api.post('/api/clinica/recetas/', body: body);
    if (res.statusCode == 201) {
      return RecetaModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw RecetaApiException('Error al crear receta (${res.statusCode})');
  }

  Future<RecetaModel> dispensar(int id) async {
    final res = await _api.patch('/api/clinica/recetas/$id/dispensar/');
    if (res.statusCode == 200) {
      return RecetaModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw RecetaApiException('Error al dispensar receta (${res.statusCode})');
  }

  Future<RecetaModel> anular(int id) async {
    final res = await _api.patch('/api/clinica/recetas/$id/anular/');
    if (res.statusCode == 200) {
      return RecetaModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw RecetaApiException('Error al anular receta (${res.statusCode})');
  }
}