class FichaPacienteResumen {
  const FichaPacienteResumen({
    required this.id,
    required this.nombreCompleto,
    required this.ci,
  });

  final int id;
  final String nombreCompleto;
  final String ci;

  factory FichaPacienteResumen.fromJson(Map<String, dynamic> json) =>
      FichaPacienteResumen(
        id: json['id'] as int? ?? 0,
        nombreCompleto: json['nombre_completo'] as String? ?? '',
        ci: json['ci'] as String? ?? '',
      );
}

class FichaModel {
  const FichaModel({
    required this.id,
    required this.correlativo,
    required this.estado,
    required this.paciente,
    required this.fechaApertura,
    required this.tieneTriage,
  });

  final int id;
  final String correlativo;
  final String estado;
  final FichaPacienteResumen paciente;
  final String fechaApertura;
  final bool tieneTriage;

  factory FichaModel.fromJson(Map<String, dynamic> json) {
    final pac = json['paciente'];
    return FichaModel(
      id: json['id'] as int? ?? 0,
      correlativo: json['correlativo'] as String? ?? '',
      estado: json['estado'] as String? ?? '',
      paciente: pac is Map<String, dynamic>
          ? FichaPacienteResumen.fromJson(pac)
          : const FichaPacienteResumen(id: 0, nombreCompleto: '', ci: ''),
      fechaApertura: json['fecha_apertura'] as String? ?? '',
      tieneTriage: json['triaje_resumen'] != null,
    );
  }

  String get estadoLabel => const {
        'ABIERTA': 'Abierta',
        'EN_TRIAJE': 'En Triaje',
        'EN_ATENCION': 'En Atención',
        'CERRADA': 'Cerrada',
        'CANCELADA': 'Cancelada',
      }[estado] ??
      estado;
}
