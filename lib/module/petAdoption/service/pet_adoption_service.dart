import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/generatorId.dart';
import '../../Profile/model/user_model.dart';
import '../../pet/model/pet_model.dart';
import '../model/adoption_application_model.dart';

class AdoptionService {
  final supabase = Supabase.instance.client;

  // fetch applications
  Future<List<Application>> fetchApplications() async {
    final response = await supabase
        .from('Adoption')
        .select('''
          adoption_id,
          pet_id,
          user_id,
          User(name),
          created_at,
          AdoptionStatus (
            adoption_status,
            created_at
          ),
          Pet (
            name,
            species,
            gender,
            image_url
          )
        ''')
        .order(
          'created_at',
          referencedTable: 'AdoptionStatus',
          ascending: false,
        )
        .limit(1, referencedTable: 'AdoptionStatus');

    return (response as List)
        .map((item) => Application.fromJson(item))
        .toList();
  }

  // approve single application
  Future<void> approveSingleApplication(String adoptionId) async {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    if (adoptionId.trim().isEmpty) {
      log("Invalid adoption ID");
      return;
    }

    debugPrint("Approving single application: $adoptionId");

    try {
      final adoptionRes = await supabase
          .from('Adoption')
          .select('adoption_id, pet_id')
          .eq('adoption_id', adoptionId)
          .single();

      debugPrint("Fetched adoption: $adoptionId");

      final petId = adoptionRes['pet_id'] as String;
      debugPrint("Pet ID: $petId");

      // update Adoption
      await supabase
          .from('Adoption')
          .update({'updated_at': formattedDate})
          .eq('adoption_id', adoptionId);

      debugPrint("Updated Adoption: $adoptionId");

      // update Pet
      await supabase
          .from('Pet')
          .update({'adoption_status': true})
          .eq('pet_id', petId);

      debugPrint("Updated Pet: $petId");

      // generate and insert status
      final statusId = await GeneratorId.generateId(
        tableName: 'AdoptionStatus',
        idColumnName: 'status_id',
        prefix: 'S',
        numberLength: 5,
      );

      await supabase.from('AdoptionStatus').insert({
        'status_id': statusId,
        'adoption_status': 'Approved',
        'created_at': formattedDate,
        'adoption_id': adoptionId,
      });

      debugPrint("Successfully approved: $adoptionId");
    } catch (e) {
      log("Approve single application error: $e");
      rethrow;
    }
  }

// reject single application
  Future<void> rejectSingleApplication(String adoptionId) async {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    if (adoptionId.trim().isEmpty) {
      log("Invalid adoption ID");
      return;
    }

    debugPrint("Rejecting single application: $adoptionId");

    try {
      final adoptionRes = await supabase
          .from('Adoption')
          .select('adoption_id, pet_id')
          .eq('adoption_id', adoptionId)
          .single();

      debugPrint("Fetched adoption: $adoptionId");

      final petId = adoptionRes['pet_id'] as String;
      debugPrint("Pet ID: $petId");

      // update Pet
      await supabase
          .from('Pet')
          .update({'adoption_status': false})
          .eq('pet_id', petId);

      debugPrint("Updated Pet: $petId");

      // 3update Adoption
      await supabase
          .from('Adoption')
          .update({'updated_at': formattedDate})
          .eq('adoption_id', adoptionId);

      debugPrint("Updated Adoption: $adoptionId");

      // generate and insert status
      final statusId = await GeneratorId.generateId(
        tableName: 'AdoptionStatus',
        idColumnName: 'status_id',
        prefix: 'S',
        numberLength: 5,
      );

      await supabase.from('AdoptionStatus').insert({
        'status_id': statusId,
        'adoption_status': 'Rejected',
        'created_at': formattedDate,
        'adoption_id': adoptionId,
      });

      debugPrint("Successfully rejected: $adoptionId");
    } catch (e) {
      log("Reject single application error: $e");
      rethrow;
    }
  }

// approve multiple applications (loops through each one)
  Future<void> approveApplications(Set<String> ids) async {
    final cleanIds = ids.where((e) => e.trim().isNotEmpty).toList();

    if (cleanIds.isEmpty) {
      log("No valid IDs to approve");
      return;
    }

    debugPrint("🟢 Approving ${cleanIds.length} applications");

    int successCount = 0;
    int failureCount = 0;

    for (final id in cleanIds) {
      try {
        await approveSingleApplication(id);
        successCount++;
      } catch (e) {
        log("Failed to approve $id: $e");
        failureCount++;
      }
    }

    debugPrint(
      "Approve complete: $successCount succeeded, $failureCount failed",
    );

    if (failureCount > 0) {
      throw Exception(
        "Failed to approve $failureCount out of ${cleanIds.length} applications",
      );
    }
  }

// ✅ Reject multiple applications (loops through each one)
  Future<void> rejectApplications(Set<String> ids) async {
    final cleanIds = ids.where((e) => e.trim().isNotEmpty).toList();

    if (cleanIds.isEmpty) {
      log("No valid IDs to reject");
      return;
    }

    debugPrint("Rejecting ${cleanIds.length} applications");

    int successCount = 0;
    int failureCount = 0;

    for (final id in cleanIds) {
      try {
        await rejectSingleApplication(id);
        successCount++;
      } catch (e) {
        log("Failed to reject $id: $e");
        failureCount++;
      }
    }

    debugPrint(
      "Reject complete: $successCount succeeded, $failureCount failed",
    );

    if (failureCount > 0) {
      throw Exception(
        "Failed to reject $failureCount out of ${cleanIds.length} applications",
      );
    }
  }

  Future<bool> submitApplication({
    required String petId,
    required String userId,
    required String address,
  }) async {
    try {
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final adoptionId = await GeneratorId.generateId(
        tableName: 'Adoption',
        idColumnName: 'adoption_id',
        prefix: 'AD',
        numberLength: 4,
      );

      final statusId = await GeneratorId.generateId(
        tableName: 'AdoptionStatus',
        idColumnName: 'status_id',
        prefix: 'S',
        numberLength: 5,
      );

      // Insert Adoption
      await supabase.from('Adoption').insert({
        'adoption_id': adoptionId,
        'user_address': address,
        'created_at': now,
        'pet_id': petId,
        'user_id': userId,
      });

      // Insert Status
      await supabase.from('AdoptionStatus').insert({
        'status_id': statusId,
        'adoption_status': 'Pending',
        'created_at': now,
        'adoption_id': adoptionId,
      });

      // Update pet adoption status
      await supabase.from('Pet').update({
        'adoption_status': true,
        'updated_at': now,
      }).eq('pet_id', petId);

      return true;
    } catch (e) {
      throw Exception('Error submitting adoption application: $e');
    }
  }

  Future<AdoptionDetails?> fetchAdoptionDetails(String adoptionId) async {
    try {
      final adoptionResponse = await supabase
          .from('Adoption')
          .select('''
            adoption_id,
            user_id,
            pet_id,
            created_at,
            AdoptionStatus(adoption_status, created_at)
          ''')
          .eq('adoption_id', adoptionId)
          .order(
            'created_at',
            referencedTable: 'AdoptionStatus',
            ascending: true,
          )
          .maybeSingle();

      if (adoptionResponse == null) {
        return null;
      }

      final application = Application.fromJson(adoptionResponse);

      // Fetch Pet
      final petResponse = await supabase
          .from('Pet')
          .select()
          .eq('pet_id', application.petId)
          .maybeSingle();

      if (petResponse == null) {
        return null;
      }

      final pet = Pet.fromJson(petResponse);

      return AdoptionDetails(application: application, pet: pet);
    } catch (e) {
      throw Exception('Error fetching adoption details: $e');
    }
  }

  Future<UserModel> fetchAdoptionUser(String userId) async {
    try {
      final userResponse = await supabase
          .from('User')
          .select('name, gender, contact, avatar_url')
          .eq('user_id', userId)
          .single();

      final user = UserModel.fromJson(userResponse);

      return user;
    } catch (e) {
      throw Exception('Error fetching pet adoptions user: $e');
    }
  }

  Future<DateTime?> fetchPickupDate(String adoptionId) async {
    try {
      final response = await supabase
          .from('Adoption')
          .select('pickup_datetime')
          .eq('adoption_id', adoptionId)
          .single();

      final value = response['pickup_datetime'];
      if (value == null) return null;

      final dt = DateTime.parse(value);

      return DateTime(dt.year, dt.month, dt.day);
    } catch (e) {
      throw Exception('Error fetching pet adoptions user: $e');
    }
  }

  Future<String?> fetchAdoptionUserEmail() async {
    final authUser = supabase.auth.currentUser;
    return authUser?.email;
  }

  Future<List<PetAdoption>> fetchUserPetAdoptions(String userId) async {
    try {
      final adoptionResponse = await supabase
          .from('Adoption')
          .select()
          .eq('user_id', userId);

      final adoptions = (adoptionResponse as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      List<PetAdoption> pets = [];

      for (var adoption in adoptions) {
        final adoptionId = adoption['adoption_id'];

        // Fetch Pet
        final petResponse = await supabase
            .from('Pet')
            .select()
            .eq('pet_id', adoption['pet_id'])
            .maybeSingle();

        if (petResponse == null) continue;

        final pet = Pet.fromJson(petResponse);

        // Latest status
        final statusResponse = await supabase
            .from('AdoptionStatus')
            .select()
            .eq('adoption_id', adoptionId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final latestStatus = statusResponse != null
            ? statusResponse['adoption_status']
            : "Unknown";

        pets.add(
          PetAdoption(
            adoptionId: adoptionId,
            pet: pet,
            adoptionStatus: latestStatus,
          ),
        );
      }

      return pets;
    } catch (e) {
      throw Exception('Error fetching pet adoptions: $e');
    }
  }

  Future<void> schedulePickup({
    required String adoptionId,
    required DateTime pickupDate,
  }) async {
    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      String formattedPickupDate = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(pickupDate);

      String formattedUpdatedDate = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());

      String statusId = await GeneratorId.generateId(
        tableName: 'AdoptionStatus',
        idColumnName: 'status_id',
        prefix: 'S',
        numberLength: 5,
      );

      await supabase
          .from('Adoption')
          .update({
            'pickup_datetime': formattedPickupDate,
            'updated_at': formattedUpdatedDate,
          })
          .eq('adoption_id', adoptionId);

      await supabase.from('AdoptionStatus').insert({
        'status_id': statusId,
        'adoption_status': 'Pending Pickup',
        'created_at': formattedDate,
        'adoption_id': adoptionId,
      });

    } catch (e) {
      throw Exception("Failed to schedule pickup: $e");
    }
  }

  Future<DateTime?> getPickupDate({
    required String adoptionId,
  }) async {
    try {
      final response = await supabase
          .from('Adoption')
          .select('pickup_datetime')
          .eq('adoption_id', adoptionId)
          .single(); // 👈 ensures one row

      final timestamp = response['pickup_datetime'];

      if (timestamp == null) return null;

      return DateTime.parse(timestamp);

    } catch (e) {
      throw Exception("Failed to fetch pickup date: $e");
    }
  }

  Future<bool> confirmPickup({
    required String data,
  }) async {
    try {
      final response = await supabase
          .from('Adoption')
          .select()
          .eq('adoption_id', data)
          .maybeSingle();

      if (response == null) return false;

      final now = DateTime.now();
      final formattedDate =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      String statusId = await GeneratorId.generateId(
        tableName: 'AdoptionStatus',
        idColumnName: 'status_id',
        prefix: 'S',
        numberLength: 5,
      );

      await supabase.from('AdoptionStatus').insert({
        'status_id': statusId,
        'adoption_status': 'Completed',
        'created_at': formattedDate,
        'adoption_id': data,
      });

      return true;
    } catch (e) {
      throw Exception("Failed to confirm pickup: $e");
    }
  }

}
