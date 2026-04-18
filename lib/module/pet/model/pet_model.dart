class Pet {
  final String id;
  final String name;
  final String image;
  final String gender;
  final double age;
  final double weight;
  final String color;
  final String health;
  final bool vaccination;
  final String species;
  final bool adopted;
  final String description;

  Pet({
    required this.id,
    required this.name,
    required this.image,
    required this.gender,
    required this.age,
    required this.weight,
    required this.color,
    required this.health,
    required this.vaccination,
    required this.species,
    required this.adopted,
    required this.description,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['pet_id'].toString(),
      name: json['name'].toString(),
      image: json['image_url'].toString(),
      gender: json['gender'].toString(),
      age: (json['age'] as num).toDouble(),
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      color: (json['color'])?.toString() ?? "",
      health: json['health_status'].toString(),
      vaccination: json['vaccination_status'] as bool,
      species: json['species'].toString(),
      adopted: json['adoption_status'] as bool,
      description: json['description']?.toString() ?? "",
    );
  }
}
