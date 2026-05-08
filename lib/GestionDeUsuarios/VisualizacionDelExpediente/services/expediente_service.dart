import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:histolink/shared/config/api_config.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/services/auth_service.dart';
import 'package:histolink/GestionDeUsuarios/VisualizacionDelExpediente/models/expediente_resumido_model.dart';

class ExpedienteService {
  final AuthService _authService = AuthService();

  Future<ExpedienteResumido> obtenerExpedienteResumido(int pacienteId) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no válida. Vuelve a iniciar sesión.');
    }

    final response = await http.get(
      ApiConfig.uri('/api/expediente/$pacienteId/expediente/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return ExpedienteResumido.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message =
        (data['error'] ?? data['detail'] ?? 'No se pudo cargar el expediente.')
            .toString();
    throw Exception(message);
  }
}
