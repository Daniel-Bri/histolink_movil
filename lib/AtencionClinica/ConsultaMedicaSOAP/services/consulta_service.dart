import 'dart:convert';
import '../../../shared/services/api_service.dart';
import '../models/consulta_model.dart';

class ConsultaService {
  final ApiService _apiService = ApiService();

  Future<ConsultaMedica> getById(int id) async {
    final response = await _apiService.get('/api/consultas/consultas/$id/');
    if (response.statusCode == 200) {
      return ConsultaMedica.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error al obtener consulta: ${response.statusCode}');
  }

  Future<ConsultaMedica> create(int fichaId) async {
    final response = await _apiService.post('/api/consultas/consultas/', body: {'ficha': fichaId});
    if (response.statusCode == 201 || response.statusCode == 200) {
      return ConsultaMedica.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error al crear consulta: ${response.statusCode}');
  }

  Future<ConsultaMedica> update(int id, Map<String, dynamic> data) async {
    final response = await _apiService.patch('/api/consultas/consultas/$id/', body: data);
    if (response.statusCode == 200) {
      return ConsultaMedica.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error al actualizar consulta: ${response.statusCode}');
  }

  Future<ConsultaMedica> completar(int id) async {
    final response = await _apiService.post('/api/consultas/consultas/$id/completar/', body: {});
    if (response.statusCode == 200) {
      return ConsultaMedica.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error al completar consulta: ${response.statusCode}');
  }

  Future<ConsultaMedica> firmar(int id) async {
    final response = await _apiService.patch('/api/consultas/consultas/$id/firmar/', body: {});
    if (response.statusCode == 200) {
      return ConsultaMedica.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error al firmar consulta: ${response.statusCode}');
  }

  Future<List<Map<String, dynamic>>> searchCIE10(String query) async {
    final response = await _apiService.get('/api/auditoria/cie10/search/?q=$query');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> getUltimoTriaje(int pacienteId) async {
    try {
      final response = await _apiService.get('/api/pacientes/$pacienteId/triaje/ultimo/');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
