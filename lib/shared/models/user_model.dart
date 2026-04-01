class UserModel {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> groups;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.groups,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      groups: List<String>.from(json['groups'] ?? []),
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
