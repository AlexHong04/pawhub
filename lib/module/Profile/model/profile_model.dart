class AuthModel {
  final String id;
  final String name;
  final String gender;
  final String contact;
  final String address;
  final String role;
  final String onlineStatus;
  final bool isVolunteer;
  final DateTime updatedAt;
  final String avatarUrl;
  final String email;

  AuthModel({
    required this.id,
    required this.name,
    required this.gender,
    required this.contact,
    required this.address,
    required this.role,
    required this.onlineStatus,
    required this.isVolunteer,
    required this.updatedAt,
    required this.avatarUrl,
    required this.email,
  });

  factory AuthModel.fromJson(Map<String, dynamic> data) => AuthModel(
    id: data["user_id"],
    name: data['name'],
    gender: data['gender'],
    contact: data['contact'],
    address: data['address'],
    role: data['role'],
    onlineStatus: data['online_status'],
    isVolunteer: data['is_volunteer'],
    updatedAt: data['updated_at'],
    avatarUrl: data['avatar_url'],
    email: data['email'],
  );
}
