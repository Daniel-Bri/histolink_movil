class ConsultaParaOrden {
  final int id;
  final String display;
  final String pacienteNombre;

  const ConsultaParaOrden({
    required this.id,
    required this.display,
    required this.pacienteNombre,
  });

  factory ConsultaParaOrden.fromJson(Map<String, dynamic> j) {
    String nombre = '';
    final paciente = j['paciente'];
    if (paciente is Map<String, dynamic>) {
      nombre = (paciente['nombre_completo'] as String?) ??
          '${paciente['primer_nombre'] ?? ''} ${paciente['primer_apellido'] ?? ''}'.trim();
    } else if (paciente is String) {
      nombre = paciente;
    }
    if (nombre.isEmpty) nombre = 'Consulta #${j['id']}';

    final cie10 = (j['codigo_cie10_principal'] as String?) ?? '';
    final motivo = (j['motivo_consulta'] as String?) ?? '';
    final motivoShort = motivo.length > 40 ? '${motivo.substring(0, 40)}...' : motivo;
    final parts = <String>[
      nombre,
      if (cie10.isNotEmpty) cie10,
      if (motivoShort.isNotEmpty) motivoShort,
    ];
    return ConsultaParaOrden(
      id: j['id'] as int,
      display: parts.join(' — '),
      pacienteNombre: nombre,
    );
  }
}

class ResultadoEstudioModel {
  final int id;
  final String? archivoAdjunto;
  final String? nombreArchivo;
  final String? valoresResultado;
  final String? interpretacionMedica;
  final DateTime? fechaResultado;

  const ResultadoEstudioModel({
    required this.id,
    this.archivoAdjunto,
    this.nombreArchivo,
    this.valoresResultado,
    this.interpretacionMedica,
    this.fechaResultado,
  });

  bool get esPdf {
    final name = (nombreArchivo ?? archivoAdjunto ?? '').toLowerCase();
    return name.endsWith('.pdf');
  }

  bool get esImagen {
    final name = (nombreArchivo ?? archivoAdjunto ?? '').toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp');
  }

  bool get tieneArchivo => archivoAdjunto != null && archivoAdjunto!.isNotEmpty;

  factory ResultadoEstudioModel.fromJson(Map<String, dynamic> j) {
    return ResultadoEstudioModel(
      id: j['id'] as int,
      archivoAdjunto: j['archivo_adjunto'] as String?,
      nombreArchivo: j['nombre_archivo'] as String?,
      valoresResultado: j['valores_resultado'] as String?,
      interpretacionMedica: j['interpretacion_medica'] as String?,
      fechaResultado: j['fecha_resultado'] != null
          ? DateTime.tryParse(j['fecha_resultado'].toString())
          : null,
    );
  }
}

class OrdenEstudioModel {
  final int id;
  final String correlativoOrden;
  final String tipo;
  final String descripcion;
  final String indicacionClinica;
  final bool urgente;
  final String? motivoUrgencia;
  final String estado;
  final DateTime? fechaSolicitud;
  final String? medicoNombre;
  final int? consultaId;
  final String? pacienteNombre;
  final ResultadoEstudioModel? resultado;

  const OrdenEstudioModel({
    required this.id,
    required this.correlativoOrden,
    required this.tipo,
    required this.descripcion,
    required this.indicacionClinica,
    required this.urgente,
    this.motivoUrgencia,
    required this.estado,
    this.fechaSolicitud,
    this.medicoNombre,
    this.consultaId,
    this.pacienteNombre,
    this.resultado,
  });

  bool get puedeIniciar => estado == 'SOLICITADA';
  bool get puedeSubirResultado => estado == 'EN_PROCESO';
  bool get estaCompletada => estado == 'COMPLETADA';
  bool get estaAnulada => estado == 'ANULADA';

  String get tipoLabel => _tipoLabels[tipo] ?? tipo;

  static const _tipoLabels = <String, String>{
    'LAB': 'Laboratorio',
    'RX': 'Rayos X',
    'ECO': 'Ecografía',
    'TC': 'TAC/TC',
    'RMN': 'Resonancia',
    'ECG': 'ECG',
    'END': 'Endoscopía',
    'OTRO': 'Otro',
  };

  factory OrdenEstudioModel.fromJson(Map<String, dynamic> j) {
    String? medicoNombre;
    final medico = j['medico_solicitante'];
    if (medico is Map<String, dynamic>) {
      medicoNombre = (medico['nombre_completo'] as String?) ??
          '${medico['first_name'] ?? ''} ${medico['last_name'] ?? ''}'.trim();
    } else if (medico is String) {
      medicoNombre = medico;
    }

    String? pacienteNombre;
    final pacienteField = j['paciente_nombre'] ?? j['paciente'];
    if (pacienteField is String) {
      pacienteNombre = pacienteField;
    } else if (pacienteField is Map<String, dynamic>) {
      pacienteNombre = (pacienteField['nombre_completo'] as String?) ??
          '${pacienteField['primer_nombre'] ?? ''} ${pacienteField['primer_apellido'] ?? ''}'.trim();
    }

    ResultadoEstudioModel? resultado;
    final raw = j['resultado'];
    if (raw is Map<String, dynamic>) {
      resultado = ResultadoEstudioModel.fromJson(raw);
    }

    int? consultaId;
    final consulta = j['consulta'];
    if (consulta is int) {
      consultaId = consulta;
    } else if (consulta is Map<String, dynamic>) {
      consultaId = consulta['id'] as int?;
    }

    return OrdenEstudioModel(
      id: j['id'] as int,
      correlativoOrden: (j['correlativo_orden'] as String?) ?? '#${j['id']}',
      tipo: (j['tipo'] as String?) ?? 'OTRO',
      descripcion: (j['descripcion'] as String?) ?? '',
      indicacionClinica: (j['indicacion_clinica'] as String?) ?? '',
      urgente: (j['urgente'] as bool?) ?? false,
      motivoUrgencia: j['motivo_urgencia'] as String?,
      estado: (j['estado'] as String?) ?? 'SOLICITADA',
      fechaSolicitud: j['fecha_solicitud'] != null
          ? DateTime.tryParse(j['fecha_solicitud'].toString())
          : null,
      medicoNombre: medicoNombre?.trim().isEmpty ?? true ? null : medicoNombre?.trim(),
      consultaId: consultaId,
      pacienteNombre: pacienteNombre?.trim().isEmpty ?? true ? null : pacienteNombre?.trim(),
      resultado: resultado,
    );
  }
}
