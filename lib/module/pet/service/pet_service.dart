import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../model/pet_model.dart';

class PetService {
  final supabase = Supabase.instance.client;

  // fetch all pets
  Future<List<Map<String, dynamic>>> fetchAllPets() async {
    final response = await supabase
        .from('Pet')
        .select()
        .eq('isDeleted', false);

    return List<Map<String, dynamic>>.from(response);
  }

  // fetch pet details
  Future<Pet> fetchPetDetails(String petId) async {
    final data = await supabase
        .from('Pet')
        .select()
        .eq('pet_id', petId)
        .single();

    return Pet.fromJson(data);
  }

  // create new pet
  Future<void> createPet({
    required String petId,
    required String name,
    required String species,
    required String gender,
    required double age,
    required double weight,
    required String color,
    required String healthStatus,
    required bool vaccinationStatus,
    required List<String> images,
    String? description,
  }) async {
    String formattedDate =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    await supabase.from('Pet').insert({
      'pet_id': petId,
      'name': name,
      'species': species,
      'gender': gender,
      'age': age,
      'weight': weight,
      'color': color,
      'health_status': healthStatus,
      'vaccination_status': vaccinationStatus,
      'adoption_status': false,
      'image_url': images.join(','),
      'created_at': formattedDate,
      'updated_at': null,
      'isDeleted': false,
      'description': description,
    });
  }

  // update pet
  Future<void> updatePet({
    required String petId,
    required String name,
    required double age,
    required double weight,
    required String color,
    required String gender,
    required String species,
    required String healthStatus,
    required bool vaccinationStatus,
    required List<String> images,
    String? description,
  }) async {
    String formattedDate =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    await supabase
        .from('Pet')
        .update({
      'name': name,
      'weight': weight,
      'age': age,
      'color': color,
      'description': description,
      'image_url': images.join(','),
      'gender': gender,
      'species': species,
      'health_status': healthStatus,
      'vaccination_status': vaccinationStatus,
      'updated_at': formattedDate,
    })
        .eq('pet_id', petId);
  }

  // delete pets
  Future<void> softDeletePets(List<String> petIds) async {
    String formattedDate =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    await supabase
        .from('Pet')
        .update({
      'isDeleted': true,
      'updated_at': formattedDate,
    })
        .inFilter('pet_id', petIds);
  }
}