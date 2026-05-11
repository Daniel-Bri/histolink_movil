enum EstadoConsulta { borrador, completada, firmada }

class ConsultaMedica {
  final int id;
  final int pacienteId;
  final String pacienteNombre;
  final int? triajeId;
  final String subjetivo;
  final String objetivo;
  final String analisis;
  final String plan;
  final Map<String, dynamic>? diagnosticoPrincipal;
  final EstadoConsulta estado;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  ConsultaMedica({
    required this.id,
    required this.pacienteId,
    required this.pacienteNombre,
    this.triajeId,
    required this.subjetivo,
    required this.objetivo,
    required this.analisis,
    required this.plan,
    this.diagnosticoPrincipal,
    required this.estado,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  bool get isEditable => estado == EstadoConsulta.borrador;
  
  bool get canComplete => 
    isEditable && 
    analisis.trim().isNotEmpty && 
    diagnosticoPrincipal != null && 
    diagnosticoPrincipal!['codigo'] != null;

  factory ConsultaMedica.fromJson(Map<String, dynamic> json) {
    return ConsultaMedica(
      id: json['id'],
      pacienteId: json['paciente_id'] ?? 0,
      pacienteNombre: json['paciente_nombre'] ?? 'Paciente Desconocido',
      triajeId: json['triaje'],
      subjetivo: json['motivo_consulta'] ?? '',
      objetivo: json['examen_fisico'] ?? '',
      analisis: json['impresion_diagnostica'] ?? '',
      plan: json['plan_tratamiento'] ?? '',
      diagnosticoPrincipal: json['codigo_cie10_principal'] != null ? {
        'codigo': json['codigo_cie10_principal'],
        'descripcion': json['descripcion_cie10'] ?? '',
      } : null,
      estado: _parseEstado(json['estado']),
      fechaCreacion: DateTime.parse(json['creado_en']),
      fechaActualizacion: json['actualizado_en'] != null 
          ? DateTime.parse(json['actualizado_en']) 
          : null,
    );
  }

  static EstadoConsulta _parseEstado(String? estado) {
    switch (estado) {
      case 'COMPLETADA': return EstadoConsulta.completada;
      case 'FIRMADA': return EstadoConsulta.firmada;
      default: return EstadoConsulta.borrador;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'motivo_consulta': subjetivo,
      'examen_fisico': objetivo,
      'impresion_diagnostica': analisis,
      'plan_tratamiento': plan,
      'codigo_cie10_principal': diagnosticoPrincipal?['codigo'],
      'descripcion_cie10': diagnosticoPrincipal?['descripcion'],
    };
  }
}
