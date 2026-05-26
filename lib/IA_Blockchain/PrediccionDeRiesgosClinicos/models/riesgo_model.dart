import 'package:flutter/material.dart';

class RiesgoItem {
  const RiesgoItem({
    required this.nombre,
    required this.clave,
    required this.probabilidad,
    required this.clasificacion,
    required this.nivelAlerta,
    required this.recomendacion,
  });

  final String nombre;
  final String clave;

  /// Probabilidad en porcentaje (0–100). Llega del backend como 0.0–1.0 y
  /// se multiplica por 100 en el constructor de fábrica.
  final double probabilidad;
  final String clasificacion;
  final String nivelAlerta;
  final String recomendacion;

  factory RiesgoItem.fromEntry(String clave, Map<String, dynamic> json) {
    return RiesgoItem(
      nombre: _label(clave),
      clave: clave,
      probabilidad: ((json['probabilidad'] as num?) ?? 0.0) * 100,
      clasificacion: (json['clasificacion'] as String?) ?? '',
      nivelAlerta: (json['nivel_alerta'] as String?) ?? '',
      recomendacion: (json['recomendacion'] as String?) ?? '',
    );
  }

  /// Color semántico estricto según nivel_alerta (ISO 25010 – percepción clara).
  Color get color {
    // Normalizar: remover tilde de Í para comparar 'CRÍTICO' == 'CRITICO'
    final n = nivelAlerta.toUpperCase().replaceAll('Í', 'I');
    switch (n) {
      case 'CRITICO':
        return Colors.purple;
      case 'ALTO':
        return Colors.red;
      case 'MODERADO':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  /// Verdadero si el nivel requiere atención urgente (para feedback háptico).
  bool get esUrgente {
    final n = nivelAlerta.toUpperCase().replaceAll('Í', 'I');
    return n == 'CRITICO' || n == 'ALTO';
  }

  // ---------------------------------------------------------------------------

  static const _keys = [
    'diabetes_tipo2',
    'hipertension',
    'enfermedad_renal',
    'evento_cardiovascular',
  ];

  static const _labels = <String, String>{
    'diabetes_tipo2': 'Diabetes Tipo 2',
    'hipertension': 'Hipertensión',
    'enfermedad_renal': 'Enfermedad Renal',
    'evento_cardiovascular': 'Evento Cardiovascular',
  };

  static String _label(String clave) =>
      _labels[clave] ?? clave.replaceAll('_', ' ');

  /// Parsea la respuesta plana del endpoint /api/ia/riesgo/ en una lista de
  /// [RiesgoItem]. Las claves no reconocidas se ignoran silenciosamente.
  static List<RiesgoItem> fromApiResponse(Map<String, dynamic> json) {
    return _keys
        .where((k) => json[k] is Map<String, dynamic>)
        .map((k) => RiesgoItem.fromEntry(k, json[k] as Map<String, dynamic>))
        .toList();
  }
}
