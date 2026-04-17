import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/donation_model.dart';
import '../../../core/utils/generatorId.dart';

class DonationService {
  final _supabase = Supabase.instance.client;

  Future<String?> getUserEmail() async {
    final authUser = _supabase.auth.currentUser;
    return authUser?.email;
  }

  String _getCustomTimestamp() {
    final now = DateTime.now();
    return now.toString().split('.')[0];
  }

  Future<String> getCurrentUserId() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return "U00002";
    try {
      final data = await _supabase
          .from('User')
          .select('user_id')
          .eq('auth_id', authUser.id)
          .single();
      return data['user_id'].toString();
    } catch (e) {
      return "U00002";
    }
  }

  Future<String?> createPendingDonation(DonationModel donation) async {
    try {
      final String newId = await GeneratorId.generateId(
        tableName: 'Donation',
        idColumnName: 'donation_id',
        prefix: 'D',
        numberLength: 5,
      );

      final Map<String, dynamic> donationData = donation.toJson();
      donationData['donation_id'] = newId;

      await _supabase.from('Donation').insert(donationData);

      return newId;
    } catch (e) {
      print("Create Pending Donation Error: $e");
      return null;
    }
  }

  Future<bool> updateDonationStatus(String donationId, String newStatus) async {
    try {
      await _supabase.from('Donation').update({
        'status': newStatus,
      }).eq('donation_id', donationId);
      return true;
    } catch (e) {
      print("Donation Record Error: $e");
      return false;
    }
  }

  Future<bool> processPaymentSimulation() async {
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }

// ------------------ Admin ------------------
  // Fetch all donation records
  Future<List<dynamic>> fetchAllDonations() async {
    try {
      final response = await _supabase
          .from('Donation')
          .select('*, User!user_id(name, avatar_url)')
          .order('created_at', ascending: false);

      return response as List<dynamic>;
    } catch (e) {
      print("Admin Fetch Donations Error: $e");
      return [];
    }
  }
}
