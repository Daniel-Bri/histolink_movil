import 'package:histolink/AtencionClinica/EmisionDeRecetaMedica/models/receta_model.dart';

class AntecedentesResumen {
  final String grupoSanguineo;
  final String alergias;
  final String antecedentesPatologicos;
  final String medicacionActual;

  const AntecedentesResumen({
    required this.grupoSanguineo,
    required this.alergias,
    required this.antecedentesPatologicos,
    required this.medicacionActual,
  });

  factory AntecedentesResumen.fromJson(Map<String, dynamic> json) {
    return AntecedentesResumen(
      grupoSanguineo: (json['grupo_sanguineo'] ?? '').toString(),
      alergias: (json['alergias'] ?? '').toString(),
      antecedentesPatologicos: (json['ant_patologicos'] ?? '').toString(),
      medicacionActual: (json['medicacion_actual'] ?? '').toString(),
    );
  }
}

class TriajeResumen {
  final String horaTriaje;
  final String nivelUrgenciaLabel;
  final String motivoConsultaTriaje;

  const TriajeResumen({
    required this.horaTriaje,
    required this.nivelUrgenciaLabel,
    required this.motivoConsultaTriaje,
  });

  factory TriajeResumen.fromJson(Map<String, dynamic> json) {
    return TriajeResumen(
      horaTriaje: (json['hora_triaje'] ?? '').toString(),
      nivelUrgenciaLabel: (json['nivel_urgencia_label'] ?? json['nivel_urgencia'] ?? '').toString(),
      motivoConsultaTriaje: (json['motivo_consulta_triaje'] ?? '').toString(),
    );
  }
}

class ConsultaResumen {
  final int id;
  final String estado;
  final String creadoEn;
  final String estadoLabel;
  final String motivoConsulta;
  final String impresionDiagnostica;
  // Sprint 5 — recetas embebidas por el backend (con uuid para el QR)
  final List<RecetaModel> recetas;

  const ConsultaResumen({
    required this.id,
    required this.estado,
    required this.creadoEn,
    required this.estadoLabel,
    required this.motivoConsulta,
    required this.impresionDiagnostica,
    this.recetas = const [],
  });

  bool get esFirmada => estado == 'FIRMADA';

  factory ConsultaResumen.fromJson(Map<String, dynamic> json) {
    return ConsultaResumen(
      id: (json['id'] ?? 0) as int,
      estado: (json['estado'] ?? '').toString(),
      creadoEn: (json['creado_en'] ?? '').toString(),
      estadoLabel: (json['estado_label'] ?? json['estado'] ?? '').toString(),
      motivoConsulta: (json['motivo_consulta'] ?? '').toString(),
      impresionDiagnostica: (json['impresion_diagnostica'] ?? '').toString(),
      recetas: (json['recetas'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(RecetaModel.fromJson)
          .toList(),
    );
  }
}

class ExpedienteResumido {
  final int id;
  final String ci;
  final String ciComplemento;
  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String fechaNacimiento;
  final String sexoLabel;
  final String telefono;
  final AntecedentesResumen? antecedentes;
  final List<TriajeResumen> triajes;
  final List<ConsultaResumen> consultas;

  const ExpedienteResumido({
    required this.id,
    required this.ci,
    required this.ciComplemento,
    required this.nombres,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.fechaNacimiento,
    required this.sexoLabel,
    required this.telefono,
    required this.antecedentes,
    required this.triajes,
    required this.consultas,
  });

  factory ExpedienteResumido.fromJson(Map<String, dynamic> json) {
    final antecedentesJson = json['antecedentes'];
    final triajesJson = (json['triajes'] as List<dynamic>? ?? []);
    final consultasJson = (json['consultas'] as List<dynamic>? ?? []);

    return ExpedienteResumido(
      id: (json['id'] ?? 0) as int,
      ci: (json['ci'] ?? '').toString(),
      ciComplemento: (json['ci_complemento'] ?? '').toString(),
      nombres: (json['nombres'] ?? '').toString(),
      apellidoPaterno: (json['apellido_paterno'] ?? '').toString(),
      apellidoMaterno: (json['apellido_materno'] ?? '').toString(),
      fechaNacimiento: (json['fecha_nacimiento'] ?? '').toString(),
      sexoLabel: (json['sexo_label'] ?? json['sexo'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      antecedentes: antecedentesJson is Map<String, dynamic>
          ? AntecedentesResumen.fromJson(antecedentesJson)
          : null,
      triajes: triajesJson
          .whereType<Map<String, dynamic>>()
          .map(TriajeResumen.fromJson)
          .toList(),
      consultas: consultasJson
          .whereType<Map<String, dynamic>>()
          .map(ConsultaResumen.fromJson)
          .toList(),
    );
  }
}

