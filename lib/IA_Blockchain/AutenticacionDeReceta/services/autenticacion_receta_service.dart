import 'dart:convert';

import 'package:histolink/shared/services/api_service.dart';

import '../models/qr_autenticacion_model.dart';

class AutenticacionRecetaException implements Exception {
  final String message;
  AutenticacionRecetaException(this.message);

  @override
  String toString() => message;
}

/// Sprint 5 — Autenticación de Receta con Blockchain.
/// Pide al backend el JWT de 5 minutos que la app convierte en QR.
class AutenticacionRecetaService {
  final _api = ApiService();

  Future<QrAutenticacionModel> generarQr(String recetaUuid) async {
    final res =
        await _api.post('/api/blockchain/recetas/$recetaUuid/generar-qr/');

    if (res.statusCode == 200) {
      return QrAutenticacionModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }

    String mensaje = 'Error al generar el QR (${res.statusCode}).';
    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['error'] != null) {
        mensaje = data['error'].toString();
      }
    } catch (_) {}
    throw AutenticacionRecetaException(mensaje);
  }
}
