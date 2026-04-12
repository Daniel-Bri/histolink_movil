class PacienteModel {
  final int id;
  final String ci;
  final String? ciComplemento;
  final String nombres;
  final String apellidoPaterno;
  final String? apellidoMaterno;
  final String fechaNacimiento;
  final String sexo;
  final String? email;
  final String? telefono;
  final String? direccion;

  PacienteModel({
    required this.id,
    required this.ci,
    this.ciComplemento,
    required this.nombres,
    required this.apellidoPaterno,
    this.apellidoMaterno,
    required this.fechaNacimiento,
    required this.sexo,
    this.email,
    this.telefono,
    this.direccion,
  });

  String get nombreCompleto {
    final parts = <String>[];
    if (nombres.trim().isNotEmpty) parts.add(nombres.trim());
    if (apellidoPaterno.trim().isNotEmpty) parts.add(apellidoPaterno.trim());
    final am = apellidoMaterno?.trim();
    if (am != null && am.isNotEmpty) parts.add(am);
    return parts.join(' ');
  }

  String get ciCompleto {
    final c = ciComplemento?.trim();
    if (c == null || c.isEmpty) return ci;
    return '$ci-$c';
  }

  int? get edadCalculada {
    final d = DateTime.tryParse(fechaNacimiento);
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
      age--;
    }
    return age;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    return v.toString();
  }

  factory PacienteModel.fromJson(Map<String, dynamic> json) {
    final ci = _str(json['ci']) ?? _str(json['numero_documento']) ?? '';

    // El serializer devuelve aliases: nombre→nombres, apellido→apellido_paterno, genero→sexo
    return PacienteModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      ci: ci,
      ciComplemento: _str(json['ci_complemento']),
      nombres:        _str(json['nombre'])         ?? _str(json['nombres'])         ?? '',
      apellidoPaterno:_str(json['apellido'])        ?? _str(json['apellido_paterno']) ?? '',
      apellidoMaterno:_str(json['apellido_materno']),
      fechaNacimiento:_str(json['fecha_nacimiento']) ?? '',
      sexo:           _str(json['genero'])          ?? _str(json['sexo'])            ?? '',
      email:    _str(json['email']),
      telefono: _str(json['telefono']),
      direccion:_str(json['direccion']),
    );
  }

  /// Cuerpo para POST — usa los alias que espera el serializer Django.
  Map<String, dynamic> toCreateJson() {
    return {
      'ci': ci,
      if (ciComplemento != null && ciComplemento!.trim().isNotEmpty)
        'ci_complemento': ciComplemento!.trim(),
      'nombre':           nombres.trim(),
      'apellido':         apellidoPaterno.trim(),
      if (apellidoMaterno != null && apellidoMaterno!.trim().isNotEmpty)
        'apellido_materno': apellidoMaterno!.trim(),
      'fecha_nacimiento': fechaNacimiento,
      'genero':           sexo,
      if (email    != null && email!.trim().isNotEmpty)    'email':    email!.trim(),
      if (telefono != null && telefono!.trim().isNotEmpty) 'telefono': telefono!.trim(),
      if (direccion!= null && direccion!.trim().isNotEmpty)'direccion':direccion!.trim(),
    };
  }
}
