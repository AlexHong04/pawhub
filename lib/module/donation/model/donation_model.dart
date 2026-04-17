class DonationModel {
  final String donationId;
  final String userId;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String userName;
  final String donationMethod;

  DonationModel({
    required this.donationId,
    required this.userId,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.userName,
    required this.donationMethod,
  });

  factory DonationModel.fromJson(Map<String, dynamic> data) {
    final userData = data['User'] ?? {};
    return DonationModel(
      donationId: data["donation_id"].toString(),
      userId: data["user_id"].toString(),
      amount: double.parse((data["amount"] ?? 0).toStringAsFixed(2)),
      status: data["status"] ?? "fail",
      createdAt: data['created_at'] is String
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      userName: userData['name'] ?? "Unknown User",
      donationMethod: data['donation_method'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'amount': double.parse(amount.toStringAsFixed(2)),
      'status': status,
      'donation_method': donationMethod,
      'created_at': createdAt.toString().split('.')[0],
    };
  }
}
