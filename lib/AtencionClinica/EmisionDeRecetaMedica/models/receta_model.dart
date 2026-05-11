class DetalleRecetaModel {
  final int? id;
  final String medicamento;
  final String concentracion;
  final String formaFarmaceutica;
  final String viaAdministracion;
  final String dosis;
  final String frecuencia;
  final String duracion;
  final String cantidadTotal;
  final String instrucciones;
  final int orden;

  DetalleRecetaModel({
    this.id,
    required this.medicamento,
    this.concentracion = '',
    this.formaFarmaceutica = '',
    this.viaAdministracion = 'VO',
    required this.dosis,
    required this.frecuencia,
    required this.duracion,
    this.cantidadTotal = '',
    this.instrucciones = '',
    this.orden = 1,
  });

  factory DetalleRecetaModel.fromJson(Map<String, dynamic> j) => DetalleRecetaModel(
    id: j['id'],
    medicamento: j['medicamento'] ?? '',
    concentracion: j['concentracion'] ?? '',
    formaFarmaceutica: j['forma_farmaceutica'] ?? '',
    viaAdministracion: j['via_administracion'] ?? 'VO',
    dosis: j['dosis'] ?? '',
    frecuencia: j['frecuencia'] ?? '',
    duracion: j['duracion'] ?? '',
    cantidadTotal: j['cantidad_total'] ?? '',
    instrucciones: j['instrucciones'] ?? '',
    orden: j['orden'] ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'medicamento': medicamento,
    'concentracion': concentracion,
    'forma_farmaceutica': formaFarmaceutica,
    'via_administracion': viaAdministracion,
    'dosis': dosis,
    'frecuencia': frecuencia,
    'duracion': duracion,
    'cantidad_total': cantidadTotal,
    'instrucciones': instrucciones,
    'orden': orden,
  };

  DetalleRecetaModel copyWith({
    String? medicamento, String? concentracion, String? formaFarmaceutica,
    String? viaAdministracion, String? dosis, String? frecuencia,
    String? duracion, String? cantidadTotal, String? instrucciones,
  }) => DetalleRecetaModel(
    id: id,
    medicamento: medicamento ?? this.medicamento,
    concentracion: concentracion ?? this.concentracion,
    formaFarmaceutica: formaFarmaceutica ?? this.formaFarmaceutica,
    viaAdministracion: viaAdministracion ?? this.viaAdministracion,
    dosis: dosis ?? this.dosis,
    frecuencia: frecuencia ?? this.frecuencia,
    duracion: duracion ?? this.duracion,
    cantidadTotal: cantidadTotal ?? this.cantidadTotal,
    instrucciones: instrucciones ?? this.instrucciones,
    orden: orden,
  );
}

class RecetaModel {
  final int id;
  final String numeroReceta;
  final String fechaEmision;
  final String estado;
  final String observaciones;
  final int consulta;
  final String? fechaDispensacion;
  final List<DetalleRecetaModel> detalles;

  RecetaModel({
    required this.id,
    required this.numeroReceta,
    required this.fechaEmision,
    required this.estado,
    this.observaciones = '',
    required this.consulta,
    this.fechaDispensacion,
    required this.detalles,
  });

  factory RecetaModel.fromJson(Map<String, dynamic> j) => RecetaModel(
    id: j['id'],
    numeroReceta: j['numero_receta'] ?? '',
    fechaEmision: j['fecha_emision'] ?? '',
    estado: j['estado'] ?? '',
    observaciones: j['observaciones'] ?? '',
    consulta: j['consulta'] ?? 0,
    fechaDispensacion: j['fecha_dispensacion'],
    detalles: (j['detalles'] as List<dynamic>? ?? [])
        .map((d) => DetalleRecetaModel.fromJson(d as Map<String, dynamic>))
        .toList(),
  );
}