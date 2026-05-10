class ConsultaModel {
  final int id;
  final int ficha;
  final String estado;
  final String subjetivo;
  final String objetivo;
  final String analisis;
  final String plan;
  final String? codigoCie10;
  final String? diagnostico;
  final String? fechaConsulta;

  const ConsultaModel({
    required this.id,
    required this.ficha,
    required this.estado,
    required this.subjetivo,
    required this.objetivo,
    required this.analisis,
    required this.plan,
    this.codigoCie10,
    this.diagnostico,
    this.fechaConsulta,
  });

  factory ConsultaModel.fromJson(Map<String, dynamic> json) => ConsultaModel(
        id: json['id'] as int,
        ficha: json['ficha'] as int,
        estado: json['estado'] as String? ?? 'BORRADOR',
        subjetivo: json['subjetivo'] as String? ?? '',
        objetivo: json['objetivo'] as String? ?? '',
        analisis: json['analisis'] as String? ?? '',
        plan: json['plan'] as String? ?? '',
        codigoCie10: json['codigo_cie10_principal'] as String?,
        diagnostico: json['diagnostico_principal'] as String?,
        fechaConsulta: json['fecha_consulta'] as String?,
      );

  String get estadoLabel => switch (estado) {
        'BORRADOR' => 'Borrador',
        'COMPLETADA' => 'Completada',
        'FIRMADA' => 'Firmada',
        _ => estado,
      };
}
