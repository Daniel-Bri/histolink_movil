class UserModel {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> groups;
  final String? tenantNombre;
  final String? tenantSlug;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.groups,
    this.tenantNombre,
    this.tenantSlug,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final tenant = json['tenant'] as Map<String, dynamic>?;
    return UserModel(
      id:           json['id'],
      username:     json['username'] ?? '',
      email:        json['email'] ?? '',
      firstName:    json['first_name'] ?? '',
      lastName:     json['last_name'] ?? '',
      groups:       List<String>.from(json['groups'] ?? []),
      tenantNombre: tenant?['nombre'] as String?,
      tenantSlug:   tenant?['slug'] as String?,
    );
  }

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : username;
  }

  String get role {
    return groups.isNotEmpty ? groups.first : 'Sin rol asignado';
  }
}
