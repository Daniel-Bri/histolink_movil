import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:histolink/shared/services/api_service.dart';

class ReporteService {
  ReporteService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
  static const _endpoint = '/api/reportes/produccion/';

  /// GET /api/reportes/produccion/ → formato json
  Future<Map<String, dynamic>> previsualizar({
    required String fechaDesde,
    required String fechaHasta,
    String tipoReporte = 'resumen_general',
    String? nivelUrgencia,
    String? q,
  }) async {
    final params = <String, String>{
      'fecha_desde': fechaDesde,
      'fecha_hasta': fechaHasta,
      'tipo_reporte': tipoReporte,
      if (nivelUrgencia != null && nivelUrgencia != 'Todos') 'nivel_urgencia': nivelUrgencia,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };

    final res = await _api.get(_endpoint, queryParameters: params);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    String msg = 'Error ${res.statusCode}';
    try {
      final d = jsonDecode(res.body);
      if (d is Map && d['detail'] != null) msg = d['detail'].toString();
    } catch (_) {}
    throw Exception(msg);
  }

  /// GET /api/reportes/produccion/?formato=csv|excel|pdf
  Future<File> exportar({
    required String formato,
    required String fechaDesde,
    required String fechaHasta,
    String tipoReporte = 'resumen_general',
    String? nivelUrgencia,
    String? q,
  }) async {
    final params = <String, String>{
      'fecha_desde': fechaDesde,
      'fecha_hasta': fechaHasta,
      'tipo_reporte': tipoReporte,
      'formato': formato,
      if (nivelUrgencia != null && nivelUrgencia != 'Todos') 'nivel_urgencia': nivelUrgencia,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };

    final res = await _api.get(_endpoint, queryParameters: params);
    if (res.statusCode == 200) {
      final tempDir = await getTemporaryDirectory();
      final ext = formato == 'excel' ? 'xlsx' : formato;
      final file = File('${tempDir.path}/reporte_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(res.bodyBytes);
      return file;
    }
    throw Exception('Error al exportar ($formato): ${res.statusCode}');
  }
}
