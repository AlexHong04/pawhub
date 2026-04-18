import '../../pet/model/pet_model.dart';

class Application {
  final String adoptionId;
  final String userId;
  final String userName;
  final String petId;
  final String petName;
  final String createdAt;
  final String petGender;
  final String petImage;
  final String petSpecies;
  final List<String> adoptionStatuses; // store all statuses

  Application({
    required this.adoptionId,
    required this.userId,
    required this.userName,
    required this.petId,
    required this.petName,
    required this.createdAt,
    required this.petGender,
    required this.petImage,
    required this.petSpecies,
    required this.adoptionStatuses,
  });

  /// Latest status helper
  String get latestStatus => adoptionStatuses.isNotEmpty ? adoptionStatuses.last : '';

  factory Application.fromJson(Map<String, dynamic> json) {
    final user = json['User'] as Map<String, dynamic>?;
    final pet = json['Pet'] as Map<String, dynamic>?;
    final status = json['AdoptionStatus'];

    List<String> statuses = [];
    if (status is List) {
      statuses = status
          .map((s) => s['adoption_status']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (status is Map) {
      statuses = [status['adoption_status']?.toString() ?? ''];
    }

    return Application(
      adoptionId: json['adoption_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: user?['name'] ?? '',
      petId: json['pet_id']?.toString() ?? '',
      petName: pet?['name'] ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      petGender: pet?['gender'] ?? '',
      petImage: pet?['image_url'] ?? '',   // 👈 THIS is the key fix
      petSpecies: pet?['species'] ?? '',
      adoptionStatuses: statuses,
    );
  }
}

class AdoptionDetails {
  final Application application;
  final Pet pet;

  AdoptionDetails({
    required this.application,
    required this.pet,
  });
}

class PetAdoption {
  final String adoptionId;
  final Pet pet;
  final String adoptionStatus;

  PetAdoption({
    required this.adoptionId,
    required this.pet,
    required this.adoptionStatus,
  });
}