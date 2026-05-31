import 'dart:convert';
import 'package:histolink/shared/services/api_service.dart';

class VerificacionResult {
  final String estado; // VÁLIDO | ALTERADO | SIN_FIRMA
  final bool? integro;
  final int consultaId;
  final String? firmadoPor;
  final String? firmadoEn;
  final String? didFirmante;
  final int? bloqueNumero;
  final String? bloqueHash;

  const VerificacionResult({
    required this.estado,
    required this.integro,
    required this.consultaId,
    this.firmadoPor,
    this.firmadoEn,
    this.didFirmante,
    this.bloqueNumero,
    this.bloqueHash,
  });

  bool get esValido => estado == 'VÁLIDO';
  bool get esAlterado => estado == 'ALTERADO';
  bool get sinFirma => estado == 'SIN_FIRMA';

  factory VerificacionResult.fromJson(Map<String, dynamic> json) {
    return VerificacionResult(
      estado: (json['estado'] ?? 'SIN_FIRMA').toString(),
      integro: json['integro'] as bool?,
      consultaId: (json['consulta_id'] ?? 0) as int,
      firmadoPor: json['firmado_por']?.toString(),
      firmadoEn: json['firmado_en']?.toString(),
      didFirmante: json['did_firmante']?.toString(),
      bloqueNumero: json['bloque_numero'] as int?,
      bloqueHash: json['bloque_hash']?.toString(),
    );
  }
}

class VerificacionService {
  final _api = ApiService();

  Future<VerificacionResult> verificarDocumento(int consultaId) async {
    final resp = await _api.get('/api/blockchain/documento/$consultaId/verificar/');
    if (resp.statusCode == 200) {
      return VerificacionResult.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Error al verificar documento (HTTP ${resp.statusCode})');
  }
}
