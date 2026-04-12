import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalFileService {

  /// Save an image pass 3 parameters: the file, the SharedPreferences key, and the folder name
  static Future<File?> storeImageLocally(String id,XFile pickedFile, String storageKey, String folderName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // Use the folderName parameter to organize files!
      final dir = Directory('${appDir.path}${Platform.pathSeparator}$folderName');

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final fileExtension = pickedFile.path.contains('.') ? pickedFile.path.split('.').last : 'jpg';
      final localFileName = '${id}_${folderName}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final localFile = await File(pickedFile.path).copy('${dir.path}${Platform.pathSeparator}$localFileName');

      // Use the storageKey parameter to save it
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, localFile.path);

      return localFile;
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      return null;
    }
  }

  /// Load a saved image pass the storageKey parameter so it knows WHICH image to find
  static Future<File?> loadSavedImage(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(storageKey);

    if (savedPath == null || savedPath.isEmpty) {
      return null;
    }

    final savedFile = File(savedPath);
    if (await savedFile.exists()) {
      return savedFile;
    }

    await prefs.remove(storageKey);
    return null;
  }
}