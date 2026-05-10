import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:histolink/shared/services/api_service.dart';

class ReporteService {
  ReporteService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static const _base = '/api/reportes/';

  /// POST /api/reportes/previsualizar/
  Future<List<Map<String, dynamic>>> previsualizar({
    required String fechaDesde,
    required String fechaHasta,
    required String tipo,
    String? estado,
    String? textoLibre,
  }) async {
    final body = {
      'fecha_desde': fechaDesde,
      'fecha_hasta': fechaHasta,
      'tipo': tipo,
      if (estado != null && estado != 'Todos') 'estado': estado,
      if (textoLibre != null && textoLibre.isNotEmpty) 'texto_libre': textoLibre,
    };

    final res = await _api.post('${_base}previsualizar/', body: body);
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else if (decoded is Map && decoded.containsKey('results')) {
        return List<Map<String, dynamic>>.from(decoded['results']);
      }
      return [];
    }
    throw Exception('Error al previsualizar reporte: ${res.statusCode}');
  }

  /// Descarga el reporte en el formato especificado
  Future<File> exportar({
    required String formato, // 'csv', 'excel', 'pdf'
    required String fechaDesde,
    required String fechaHasta,
    required String tipo,
    String? estado,
    String? textoLibre,
  }) async {
    final queryParams = {
      'fecha_desde': fechaDesde,
      'fecha_hasta': fechaHasta,
      'tipo': tipo,
      if (estado != null && estado != 'Todos') 'estado': estado,
      if (textoLibre != null && textoLibre.isNotEmpty) 'texto_libre': textoLibre,
    };

    final res = await _api.get('${_base}exportar/$formato/', queryParameters: queryParams);
    
    if (res.statusCode == 200) {
      final bytes = res.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = formato == 'excel' ? 'xlsx' : formato;
      final file = File('${tempDir.path}/reporte_$timestamp.$ext');
      await file.writeAsBytes(bytes);
      return file;
    }
    throw Exception('Error al exportar reporte ($formato): ${res.statusCode}');
  }
}
