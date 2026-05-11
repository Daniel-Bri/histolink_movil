import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:histolink/shared/services/api_service.dart';

class ReporteService {
  ReporteService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
  static const _endpoint = '/api/reportes/produccion/';

  Future<Map<String, dynamic>> previsualizar({
    required String fechaDesde,
    required String fechaHasta,
    String tipoReporte = 'resumen_general',
    String? nivelUrgencia,
    String? q,
  }) async {
    final params = {
      'fecha_desde': fechaDesde,
      'fecha_hasta': fechaHasta,
      'tipo_reporte': tipoReporte,
      if (nivelUrgencia != null && nivelUrgencia.isNotEmpty && nivelUrgencia != 'Todos')
        'nivel_urgencia': nivelUrgencia,
      if (q != null && q.isNotEmpty) 'q': q,
    };

    final res = await _api.get(_endpoint, queryParameters: params);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Error al obtener reporte (${res.statusCode})');
  }

  Future<File> exportar({
    required String formato, // 'csv', 'excel', 'pdf'
    required String fechaDesde,
    required String fechaHasta,
    String tipoReporte = 'resumen_general',
    String? nivelUrgencia,
    String? q,
  }) async {
    final params = {
      'fecha_desde': fechaDesde,
      'fecha_hasta': fechaHasta,
      'tipo_reporte': tipoReporte,
      'formato': formato,
      if (nivelUrgencia != null && nivelUrgencia.isNotEmpty && nivelUrgencia != 'Todos')
        'nivel_urgencia': nivelUrgencia,
      if (q != null && q.isNotEmpty) 'q': q,
    };

    final res = await _api.get(_endpoint, queryParameters: params);
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
