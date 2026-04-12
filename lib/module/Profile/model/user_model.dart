class UserModel {
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

  UserModel({
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

  factory UserModel.fromJson(Map<String, dynamic> data) => UserModel(
    id: data["user_id"] ?? '',
    name: data['name'] ?? '',
    gender: data['gender'] ?? '',
    contact: data['contact'] ?? '',
    address: data['address'] ?? '',
    role: data['role'] ?? 'User',
    onlineStatus: data['online_status'] ?? 'Online',
    isVolunteer: data['is_volunteer'] ?? false,
    updatedAt: data['updated_at'] != null
        ? DateTime.parse(data['updated_at'])
        : DateTime.now(),
    avatarUrl: data['avatar_url'] ?? '',
    email: data['email'] ?? '',
  );
}
