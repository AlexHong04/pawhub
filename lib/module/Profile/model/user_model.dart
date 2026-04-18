class UserModel {
  final String id;
  final String name;
  final String gender;
  final String contact;
  final String address;
  final String role;
  final String onlineStatus;
  final bool isVolunteer;
  final bool isBanned;
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
    this.isBanned = false,
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
    isBanned: _parseBool(data['is_banned']),
    updatedAt: DateTime.tryParse(
          (data['last_seen'] ?? data['updated_at'] ?? '').toString(),
        ) ??
        DateTime.now(),
    avatarUrl: data['avatar_url'] ?? '',
    email: data['email'] ?? '',
  );

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }
}
