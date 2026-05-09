import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:histolink/shared/services/api_service.dart';
import 'package:histolink/shared/config/api_config.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/services/auth_service.dart';
import 'package:histolink/AtencionClinica/SolicitudDeEstudios/models/orden_estudio_model.dart';

class EstudiosService {
  EstudiosService(this._api) : _auth = AuthService();

  final ApiService _api;
  final AuthService _auth;

  String get baseUrl => ApiConfig.baseUrl;

  Future<List<ConsultaParaOrden>> getConsultasCompletadas() async {
    final resp = await _api.get(
      '/api/consultas/consultas/',
      queryParameters: {'estado': 'COMPLETADA'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Error al cargar consultas: ${resp.statusCode}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final List<dynamic> items;
    if (data is Map && data.containsKey('results')) {
      items = data['results'] as List<dynamic>;
    } else if (data is List) {
      items = data;
    } else {
      items = [];
    }
    return items
        .map((j) => ConsultaParaOrden.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<OrdenEstudioModel> crearOrden(Map<String, dynamic> payload) async {
    final resp = await _api.post('/api/ordenes-estudio/', body: payload);
    if (resp.statusCode != 201) {
      throw Exception(
        _parseError(resp.body) ?? 'Error al crear orden: ${resp.statusCode}',
      );
    }
    return OrdenEstudioModel.fromJson(
      jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<List<OrdenEstudioModel>> getColaLaboratorio() async {
    final resp = await _api.get('/api/ordenes-estudio/cola-laboratorio/');
    if (resp.statusCode != 200) {
      throw Exception('Error al cargar cola: ${resp.statusCode}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    if (data is List) {
      return data
          .map((j) => OrdenEstudioModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    // Respuesta agrupada: {urgentes, en_proceso, normales}
    final result = <OrdenEstudioModel>[];
    if (data is Map) {
      for (final key in ['urgentes', 'en_proceso', 'normales']) {
        final list = data[key] as List<dynamic>? ?? [];
        result.addAll(
          list.map((j) => OrdenEstudioModel.fromJson(j as Map<String, dynamic>)),
        );
      }
    }
    return result;
  }

  Future<List<OrdenEstudioModel>> getOrdenes({String? estado}) async {
    final params = <String, String>{};
    if (estado != null) params['estado'] = estado;
    final resp = await _api.get(
      '/api/ordenes-estudio/',
      queryParameters: params.isEmpty ? null : params,
    );
    if (resp.statusCode != 200) {
      throw Exception('Error al cargar órdenes: ${resp.statusCode}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final List<dynamic> items;
    if (data is Map && data.containsKey('results')) {
      items = data['results'] as List<dynamic>;
    } else if (data is List) {
      items = data;
    } else {
      items = [];
    }
    return items
        .map((j) => OrdenEstudioModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> cambiarEstado(int id, String estado) async {
    final resp = await _api.patch(
      '/api/ordenes-estudio/$id/cambiar-estado/',
      body: {'estado': estado},
    );
    if (resp.statusCode != 200) {
      throw Exception(
        _parseError(resp.body) ?? 'Error al cambiar estado: ${resp.statusCode}',
      );
    }
  }

  Future<void> subirResultado({
    required int ordenId,
    required String fechaResultado,
    Uint8List? archivoBytes,
    String? archivoNombre,
    String? archivoMime,
    String? valoresResultado,
    String? interpretacionMedica,
  }) async {
    final token = await _auth.getToken();
    final uri = ApiConfig.uri('/api/resultados-estudio/');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['orden'] = ordenId.toString();
    request.fields['fecha_resultado'] = fechaResultado;
    if (valoresResultado != null && valoresResultado.isNotEmpty) {
      request.fields['valores_resultado'] = valoresResultado;
    }
    if (interpretacionMedica != null && interpretacionMedica.isNotEmpty) {
      request.fields['interpretacion_medica'] = interpretacionMedica;
    }
    if (archivoBytes != null && archivoNombre != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'archivo_adjunto',
          archivoBytes,
          filename: archivoNombre,
          contentType: MediaType.parse(archivoMime ?? 'application/octet-stream'),
        ),
      );
    }
    final streamed = await request.send();
    if (streamed.statusCode != 201 && streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      throw Exception(
        _parseError(body) ?? 'Error al subir resultado: ${streamed.statusCode}',
      );
    }
  }

  String? _parseError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        for (final v in data.values) {
          if (v is List && v.isNotEmpty) return v.first.toString();
          if (v is String) return v;
        }
      }
    } catch (_) {}
    return null;
  }
}
