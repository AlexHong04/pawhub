import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/current_user_store.dart';
import '../../../core/utils/generatorId.dart';
import '../../../core/utils/local_file_service.dart';
import '../../../core/utils/supabase_file_service.dart';
import '../model/event.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EventService {
  static final supabase = Supabase.instance.client;

  static Future<String> getCurrentUserId() async {
    final userModel = await CurrentUserStore.read();
    return userModel?.id ?? "GUEST";
  }

  // ✅ UPDATED: Get internal local storage directory path
  static Future<String> _getLocalStoragePath(String folderName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final folder = Directory('${appDir.path}/$folderName');

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    return folder.path;
  }

  // ✅ NEW: Get a single event by its ID
  static Future<Map<String, dynamic>?> getEventById(String eventId) async {
    try {
      final response = await supabase
          .from('Event')
          .select('*')
          .eq('event_id', eventId)
          .maybeSingle(); // Returns null if not found instead of throwing an error

      return response;
    } catch (e) {
      print('getEventById error: $e');
      return null;
    }
  }

  static Future<bool> deleteEvent(String eventId) async {
    try {
      await supabase
          .from('JoinedEvent')
          .update({'joinned_status': 'Cancelled'})
          .eq('event_id', eventId);

      final response = await supabase
          .from('Event')
          .update({'event_status': 'Cancelled'})
          .eq('event_id', eventId)
          .select();

      return response.isNotEmpty;
    } catch (e) {
      print('deleteEvent error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllEvents() async {
    try {
      final today = DateTime.now();

      final response = await supabase
          .from('Event')
          .select('*')
          .eq('event_status', 'Available')
          .gte('event_date', today.toIso8601String().split('T')[0])
          .order('event_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('getAllEvents error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllEventsAdmin() async {
    try {
      final response = await supabase
          .from('Event')
          .select('*')
          .neq('event_status', 'Cancelled')
          .order('event_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('getAllEvents error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMyJoinedEvents(
      String userId) async {
    try {
      print("DEBUG: Fetching joined events for user: $userId");

      final joinedEvents = await supabase
          .from('JoinedEvent')
          .select('*')
          .eq('user_id', userId);

      print("DEBUG: Found ${joinedEvents.length} joined events");

      if (joinedEvents.isEmpty) {
        return [];
      }

      final eventIds = joinedEvents.map((je) => je['event_id'] as String)
          .toSet()
          .toList();
      print("DEBUG: Event IDs to fetch: $eventIds");

      final events = await supabase
          .from('Event')
          .select('*')
          .inFilter('event_id', eventIds);

      print("DEBUG: Found ${events.length} events");

      final eventMap = {
        for (var event in events) event['event_id']: event
      };

      final result = joinedEvents.map((joinedEvent) {
        final eventId = joinedEvent['event_id'];
        final eventDetails = eventMap[eventId];

        return {
          ...joinedEvent,
          'Event': eventDetails,
        };
      }).toList();

      return result;
    } catch (e) {
      print('getMyJoinedEvents error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getEventsByCategory(

      String categoryName) async {
    try {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final response = await supabase
          .from('Event')
          .select('*')
          .eq('event_status', 'Available')
          .eq('event_status', 'Available')
          .gte('event_date', today.toIso8601String().split('T')[0])
          .eq('event_category', categoryName)
          .order('event_date', ascending: true);

      return response;
    } catch (e) {
      print('getEventsByCategory error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getEventParticipants(
      String eventId) async {
    try {
      final response = await supabase
          .from('JoinedEvent')
          .select('''
          User:user_id (
            name,
            avatar_url,
            is_volunteer
          )
        ''')
          .eq('event_id', eventId);

      return response;
    } catch (e) {
      print('getEventParticipants error: $e');
      return [];
    }
  }

  static Future<bool> checkIfUserJoined(String eventId, String userId) async {
    try {
      final response = await supabase
          .from('JoinedEvent')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('checkIfUserJoined error: $e');
      return false;
    }
  }

  static Future<bool> joinEvent(String eventId, String userId) async {
    try {
      if (userId.isEmpty || userId == "GUEST") return false;

      // 1. Check if already joined
      final alreadyJoined = await checkIfUserJoined(eventId, userId);
      if (alreadyJoined) return false;

      // 2. Fetch the current spot_left from the Event table
      final eventData = await supabase
          .from('Event')
          .select('spot_left')
          .eq('event_id', eventId)
          .single();

      int currentSpotLeft = eventData['spot_left'] ?? 0;

      // Prevent joining if the event is already full
      if (currentSpotLeft <= 0) {
        print('Event is already full');
        return false;
      }

      // 3. Insert the user into JoinedEvent
      await supabase.from('JoinedEvent').insert({
        'user_id': userId,
        'event_id': eventId,
        'joinned_status': 'Upcoming',
        'rigistration_datetime': DateTime.now().toIso8601String(),
        'certificate_url': null,
        'check_in_time': null,
      });

      // 4. Decrease spot_left by 1 in the Event table
      await supabase
          .from('Event')
          .update({'spot_left': currentSpotLeft - 1})
          .eq('event_id', eventId);

      return true;
    } catch (e) {
      print('joinEvent error: $e');
      return false;
    }
  }
  static Future<bool> cancelRegistration(String eventId, String userId) async {
    try {
      // 1. Fetch the current spot_left from the Event
      final eventData = await supabase
          .from('Event')
          .select('spot_left')
          .eq('event_id', eventId)
          .single();

      int currentSpotLeft = eventData['spot_left'] ?? 0;

      // 2. DELETE the user's registration completely
      // We use .select() to ensure the row actually existed and was deleted
      final deletedRows = await supabase
          .from('JoinedEvent')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .select();

      // If no rows were deleted, the user wasn't actually registered
      if (deletedRows.isEmpty) {
        print('No matching registration found to delete.');
        return false;
      }

      // 3. Add the spot back (+1) to the Event table
      await supabase
          .from('Event')
          .update({'spot_left': currentSpotLeft + 1})
          .eq('event_id', eventId);

      return true;
    } catch (e) {
      print('cancelRegistration error: $e');
      return false;
    }
  }


  static Future<String?> copyFlyerLocally(File? flyerFile,
      String eventTitle) async {
    try {
      if (flyerFile == null) return null;

      final storagePath = await _getLocalStoragePath('flyers');
      final fileName = '$eventTitle.jpg';
      final flyerPath = '$storagePath/$fileName';

      await flyerFile.copy(flyerPath);
      return fileName;
    } catch (e) {
      return null;
    }

  }

  static Future<String?> generateAndUploadCertificate({
    required String userId,
    required String eventId,
    required String eventTitle,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Get user name
      final userData = await supabase
          .from('User')
          .select('name')
          .eq('user_id', userId)
          .maybeSingle();

      final userName = (userData?['name'] ?? 'Volunteer').toString().trim();

      // 2. Check if user joined event
      final joined = await supabase
          .from('JoinedEvent')
          .select('user_id,event_id')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (joined == null) return null;

      // 3. Load certificate template
      final templateData = await rootBundle.load('assets/images/Certificate.png');
      final certImage = img.decodeImage(templateData.buffer.asUint8List());

      if (certImage == null) return null;

      final textColor = img.ColorRgb8(0, 0, 0);

      // 4. Draw text
      img.drawString(
        certImage,
        userName.toUpperCase(),
        font: img.arial48,
        x: (certImage.width ~/ 2) - (userName.length * 12),
        y: (certImage.height ~/ 2) - 100,
        color: textColor,
      );

      img.drawString(
        certImage,
        eventTitle,
        font: img.arial24,
        x: (certImage.width ~/ 2) - (eventTitle.length * 6),
        y: (certImage.height ~/ 2) + 150,
        color: textColor,
      );

      // 5. Convert to PNG bytes and save as a Temporary File
      final bytes = Uint8List.fromList(img.encodePng(certImage));
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/cert_${userId}_$eventId.png');
      await tempFile.writeAsBytes(bytes);

      // 6. UPLOAD EXACT FILE NAME TO SUPABASE
      print("CERTIFICATE FILE PATH: ${tempFile.path}");

      final exactFilePath = 'certificates/${userId}_$eventId.png';

      await supabase.storage.from('documents').upload(
        exactFilePath,
        tempFile,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/png',
        ),
      );

      // Get the public URL for the exact file we just uploaded
      final String certificateUrl = supabase.storage.from('documents').getPublicUrl(exactFilePath);

      print("CERTIFICATE UPLOAD RESULT: $certificateUrl");

      // Optional: Delete the temp file after upload to save phone storage
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // 7. UPDATE DATABASE attributes
      final updated = await supabase
          .from('JoinedEvent')
          .update({'certificate_url': certificateUrl})
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .select();

      if (updated.isEmpty) {
        print("Database update failed. Check RLS policies.");
        return null;
      }

      return certificateUrl;
    } catch (e) {
      print('generateAndUploadCertificate error: $e');
      return null;
    }
  }

  static Future<bool> addEvent(EventModel event) async {
    try {
      final eventId = await GeneratorId.generateId(
        tableName: 'Event',
        idColumnName: 'event_id',
        prefix: 'E',
        numberLength: 5,
      );

      String? flyerUrl;

      if (event.flyerFile != null) {
        print("FILE PATH: ${event.flyerFile?.path}");
        flyerUrl = await SupabaseFileService.uploadImage(
          imageFile: event.flyerFile!,
          bucketName: 'documents',
          folderPath: 'event_flyers',
          fileNamePrefix: event.title.replaceAll(' ', '_'),
        );
        print("UPLOAD RESULT: $flyerUrl");
      }

      await supabase.from('Event').insert({
        'event_id': eventId,
        'title': event.title,
        'event_date': DateFormat('yyyy-MM-dd').format(event.eventDate),
        'description': event.description,
        'start_time': event.startTime.replaceAll(RegExp(r'[^\d:]'), ''),
        'end_time': event.endTime.replaceAll(RegExp(r'[^\d:]'), ''),
        'event_category': event.eventCategory,
        'address': event.address,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'volunteer_capacity': event.volunteerCapacity,
        'spot_left': event.volunteerCapacity,
        'event_qr': null,
        'flyer_url': flyerUrl, // ✅ FIXED
        'event_status': 'Available',
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print("ADD EVENT ERROR: $e");
      return false;
    }
  }


  static Future<void> exportAsPDF(File imageFile) async {
    try {
      final pdf = pw.Document();

      final image = pw.MemoryImage(await imageFile.readAsBytes());

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(child: pw.Image(image)),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      print("PDF error: $e");
    }
  }

  static Future<File?> downloadFromUrl(String url) async {
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);

        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/certificate.png');

        await file.writeAsBytes(bytes);
        return file;
      }
    } catch (e) {
      print("Download error: $e");
    }
    return null;
  }

  static String? formatTime(String? time) {
    if (time == null || time.isEmpty) return null;

    final parsed = DateFormat.jm().parse(time);
    return DateFormat('HH:mm:ss').format(parsed);
  }

  static Future<Map<String, dynamic>?> checkJoinedEventRecord(String userId,
      String eventId,) async {
    try {
      print(
          "🔍 Checking joined event record for user: $userId, event: $eventId");

      final response = await supabase
          .from('JoinedEvent')
          .select()
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (response != null) {
        print("✅ Record found");
      } else {
        print("⚠️ No record found");
      }

      return response as Map<String, dynamic>?;
    } catch (e) {
      print("❌ Error checking joined event record: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> validateCheckIn(String eventId,
      String userId,) async {
    try {
      print("🔍 Validating check-in for user: $userId, event: $eventId");

      // Check if user joined
      bool hasJoined = await checkIfUserJoined(eventId, userId);

      if (!hasJoined) {
        print("⚠️ User has not joined this event");
        return {
          'canCheckIn': false,
          'message': "You haven't joined this event yet!",
        };
      }

      // Get existing record
      final existingRecord = await checkJoinedEventRecord(userId, eventId);

      if (existingRecord != null &&
          existingRecord['check_in_time'] != null) {
        return {
          'canCheckIn': false,
          'message':
          "You already checked in at ${existingRecord['check_in_time']}",
          'checkInTime': existingRecord['check_in_time'],
        };
      }

      return {
        'canCheckIn': true,
        'message': "Ready to check-in",
      };
    } catch (e) {
      return {
        'canCheckIn': false,
        'message': "Error validating check-in: $e",
      };
    }
  }

  static Future<bool> updateJoinedEventAttendance({
    required String userId,
    required String eventId,
    required String checkInTime,
    required String joinedStatus,
  }) async {
    try {

      final response = await supabase
          .from('JoinedEvent')
          .update({
        'check_in_time': checkInTime,
        'joinned_status': joinedStatus,
      })
          .match({
        'user_id': userId,
        'event_id': eventId,
      })
          .select();

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getEventAttendanceReport(
      String eventId,) async {
    try {
      final response = await supabase
          .from('JoinedEvent')
          .select()
          .eq('event_id', eventId)
          .order('check_in_time', ascending: false);

      // Filter out nulls in Dart
      final attendees = (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((record) => record['check_in_time'] != null)
          .toList();

      return attendees;
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      if (updates.containsKey('flyerFile') && updates['flyerFile'] != null) {
        final File flyerFile = updates['flyerFile'] as File;

        final String? flyerUrl = await SupabaseFileService.uploadImage(
          imageFile: flyerFile,
          bucketName: 'documents',
          folderPath: 'event_flyers',
          fileNamePrefix: (updates['title'] ?? 'event').toString().replaceAll(' ', '_'),
        );

        if (flyerUrl != null) {
          updates['flyer_url'] = flyerUrl;
        }
      }

      // Remove non-table field before database update
      updates.remove('flyerFile');

      final response = await supabase
          .from('Event')
          .update(updates)
          .eq('event_id', eventId)
          .select();

      return response.isNotEmpty;
    } catch (e) {
      print('updateEvent error: $e');
      return false;
    }
  }

  static Future<void> bulkUpdateStatus({
    required String userId,
    required List<String> eventIds,
    required String newStatus,
  }) async {
    try {
      await Supabase.instance.client
          .from('JoinedEvent')
          .update({'joinned_status': newStatus})
          .eq('user_id', userId)
          .inFilter('event_id', eventIds);
    } catch (e) {
      debugPrint("Failed to update status: $e");
    }
  }
}