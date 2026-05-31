import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';

class EmergencyConsentService {
  // Base de datos mock con pacientes reales del sistema
  final List<Map<String, dynamic>> _mockPacientes = [
    {
      'id': 1001,
      'nombre': 'Lorena',
      'apellido': 'García Rocha',
      'ci': '49593002',
      'fecha_nacimiento': '2000-05-31', // 26 años aprox
      'genero': 'Femenino',
    },
    {
      'id': 1002,
      'nombre': 'Roberto',
      'apellido': 'Chavez Inca',
      'ci': '3001003',
      'fecha_nacimiento': '1976-05-31', // 50 años aprox
      'genero': 'Masculino',
    },
    {
      'id': 1003,
      'nombre': 'Maria Elena',
      'apellido': 'Torres Vargas',
      'ci': '3001002',
      'fecha_nacimiento': '1959-05-31', // 67 años aprox
      'genero': 'Femenino',
    },
    {
      'id': 1004,
      'nombre': 'Juan Carlos',
      'apellido': 'Perez Soria',
      'ci': '3001001',
      'fecha_nacimiento': '1961-05-31', // 65 años aprox
      'genero': 'Masculino',
    }
  ];

  Future<List<PacienteModel>> fetchAllPacientes() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockPacientes.map((p) => PacienteModel.fromJson(p)).toList();
  }

  Future<PacienteModel?> fetchPaciente(int id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final data = _mockPacientes.firstWhere(
      (p) => p['id'] == id,
      orElse: () => {},
    );
    if (data.isEmpty) return null;
    return PacienteModel.fromJson(data);
  }

  Future<bool> checkExistingConsent(int pacienteId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? consentsJson = prefs.getString('offline_consents');
    if (consentsJson == null) return false;

    final List<dynamic> consents = json.decode(consentsJson);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return consents.any((c) => 
      c['paciente_id'] == pacienteId && 
      c['fecha_hora'].toString().startsWith(today)
    );
  }

  Future<List<Map<String, dynamic>>> fetchRegisteredConsents() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    final String? consentsJson = prefs.getString('offline_consents');
    if (consentsJson == null) return [];

    final List<dynamic> consents = json.decode(consentsJson);
    return List<Map<String, dynamic>>.from(consents);
  }

  Future<Map<String, dynamic>> saveConsentimiento(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(seconds: 1));
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? consentsJson = prefs.getString('offline_consents');
      List<dynamic> consents = consentsJson != null ? json.decode(consentsJson) : [];
      
      consents.add(data);
      await prefs.setString('offline_consents', json.encode(consents));

      return {'success': true, 'message': 'Consentimiento registrado exitosamente'};
    } catch (e) {
      return {'success': false, 'message': 'Error al guardar localmente: $e'};
    }
  }
}
