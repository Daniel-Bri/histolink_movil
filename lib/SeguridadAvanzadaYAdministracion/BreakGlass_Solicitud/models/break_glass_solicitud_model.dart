class BreakGlassSolicitudModel {
  const BreakGlassSolicitudModel({
    required this.id,
    required this.solicitanteId,
    required this.solicitanteUsername,
    required this.pacienteId,
    required this.pacienteCi,
    required this.pacienteNombre,
    required this.justificacion,
    required this.nivelUrgencia,
    required this.estado,
    required this.accesoActivo,
    required this.accesoExpirado,
    required this.creadoEn,
    this.accesoDesde,
    this.accesoHasta,
    this.advertencia,
  });

  final int id;
  final int solicitanteId;
  final String solicitanteUsername;
  final int pacienteId;
  final String pacienteCi;
  final String pacienteNombre;
  final String justificacion;
  final String nivelUrgencia;
  final String estado;
  final bool accesoActivo;
  final bool accesoExpirado;
  final DateTime creadoEn;
  final DateTime? accesoDesde;
  final DateTime? accesoHasta;
  final String? advertencia;

  bool get esAlta => nivelUrgencia.toUpperCase() == 'ALTA';

  factory BreakGlassSolicitudModel.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return BreakGlassSolicitudModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      solicitanteId: (j['solicitante_id'] as num?)?.toInt() ?? 0,
      solicitanteUsername: (j['solicitante_username'] ?? '').toString(),
      pacienteId: (j['paciente_id'] as num?)?.toInt() ?? 0,
      pacienteCi: (j['paciente_ci'] ?? '').toString(),
      pacienteNombre: (j['paciente_nombre'] ?? '').toString(),
      justificacion: (j['justificacion'] ?? '').toString(),
      nivelUrgencia: (j['nivel_urgencia'] ?? '').toString(),
      estado: (j['estado'] ?? '').toString(),
      accesoActivo: (j['acceso_activo'] as bool?) ?? false,
      accesoExpirado: (j['acceso_expirado'] as bool?) ?? false,
      creadoEn: parseDate(j['creado_en']) ?? DateTime.now(),
      accesoDesde: parseDate(j['acceso_desde']),
      accesoHasta: parseDate(j['acceso_hasta']),
      advertencia: j['advertencia']?.toString(),
    );
  }
}
