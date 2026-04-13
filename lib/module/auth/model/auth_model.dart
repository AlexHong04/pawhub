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
    id: (data['user_id'] ?? '').toString(),
    name: (data['name'] ?? '').toString(),
    role: (data['role'] ?? '').toString(),
    email: (data['email'] ?? '').toString(),
    password: (data['encrypted_password'] ?? data['password'] ?? '').toString(),
    createAt: DateTime.tryParse((data['created_at'] ?? '').toString()) ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'user_id': id,
    'name': name,
    'role': role,
    'email': email,
    // Never persist raw password locally.
    'password': '',
    'created_at': createAt.toIso8601String(),
  };
}
