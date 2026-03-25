import 'package:supabase_flutter/supabase_flutter.dart';

class GeneratorId {
  static Future<String> generateId({
    // The name of the table in Supabase (e.g., 'User', 'Pet')
    required String tableName,
    // The name of the column storing the ID (e.g., 'user_id', 'pet_id')
    required String idColumnName,
    // The letter at the start of the ID (e.g., 'A', 'CP')
    required String prefix,
    // The amount of digits after the prefix (e.g., 5 for '00001')
    required int numberLength,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      // Fetch the latest ID from the specified table
      final response = await supabase
          .from(tableName)
          .select(idColumnName)
          .order(idColumnName, ascending: false)
          .limit(1);

      // If the table is empty, generate the very first ID
      if (response.isEmpty) {
        final String firstNum = '1'.padLeft(numberLength, '0');
        // e.g. 'U' + '00001' = 'U00001'
        return '$prefix$firstNum';
      }

      // Extract the latest ID string (e.g., "CP00045" or "A0001")
      final String lastId = response.first[idColumnName] as String;

      // Extract the numeric part by cutting off the prefix
      final String numberPart = lastId.substring(prefix.length);

      // Convert to integer and add 1
      final int nextNumber = int.parse(numberPart) + 1;

      // Pad with zeros to match the required length
      final String newNumberString = nextNumber.toString().padLeft(numberLength, '0');

      // Combine prefix and new number
      return '$prefix$newNumberString';
    } catch (e) {
      print('Error generating ID for $tableName: $e');
      throw Exception('Failed to generate unique ID');
    }
  }
}