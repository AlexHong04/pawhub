class AuthModel {
  final String id;
  final String name;
  final String role;
  final String email;
  final String password;
  final DateTime createAt;

  AuthModel({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.password,
    required this.createAt,
  });

  factory AuthModel.fromJson(Map<String, dynamic> data) => AuthModel(
    id: data["user_id"],
    name: data['name'],
    role: data['role'],
    email: data['email'],
    password: data['encrypted_password'],
    createAt: data['created_at'],
  );
}
