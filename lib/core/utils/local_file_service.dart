import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalImageMetadata {
  static const String idKey = 'id';
  static const String indexKey = 'index';
  static const String filePathKey = 'file_path';
  static const String remoteUrlKey = 'remote_url';

  final String id;
  final int index;
  final String filePath;
  final String? remoteUrl;

  const LocalImageMetadata({
    required this.id,
    required this.index,
    required this.filePath,
    this.remoteUrl,
  });

  Map<String, dynamic> toJson() => {
        idKey: id,
        indexKey: index,
        filePathKey: filePath,
        remoteUrlKey: remoteUrl,
      };

  static LocalImageMetadata? fromJsonMap(Map<String, dynamic> decoded) {
    final filePath = decoded[filePathKey] as String?;
    if (filePath == null || filePath.isEmpty) return null;

    return LocalImageMetadata(
      id: (decoded[idKey] as String?) ?? '',
      index: (decoded[indexKey] as int?) ?? 0,
      filePath: filePath,
      remoteUrl: decoded[remoteUrlKey] as String?,
    );
  }

  static LocalImageMetadata? fromStoredValue(String storedValue) {
    try {
      final decoded = jsonDecode(storedValue);
      if (decoded is Map<String, dynamic>) {
        return fromJsonMap(decoded);
      }
    } catch (_) {
      // Legacy format handled by caller.
    }
    return null;
  }
}

class LocalFileService {
  static List<LocalImageMetadata> _decodeMetadataList(String savedValue) {
    try {
      final decoded = jsonDecode(savedValue);

      if (decoded is List) {
        final items = <LocalImageMetadata>[];
        for (final item in decoded) {
          if (item is Map) {
            final metadata = LocalImageMetadata.fromJsonMap(
              Map<String, dynamic>.from(item),
            );
            if (metadata != null) {
              items.add(metadata);
            }
          }
        }
        return items;
      }

      if (decoded is Map) {
        final metadata = LocalImageMetadata.fromJsonMap(
          Map<String, dynamic>.from(decoded),
        );
        return metadata == null ? <LocalImageMetadata>[] : <LocalImageMetadata>[metadata];
      }
    } catch (_) {
      // Keep legacy raw path support below.
    }

    // Legacy plain-path format.
    if (savedValue.isNotEmpty) {
      return <LocalImageMetadata>[
        LocalImageMetadata(id: '', index: 0, filePath: savedValue),
      ];
    }
    return <LocalImageMetadata>[];
  }

  static String _encodeMetadataList(List<LocalImageMetadata> items) {
    return jsonEncode(items.map((item) => item.toJson()).toList());
  }

  static int _sortByIndex(LocalImageMetadata a, LocalImageMetadata b) {
    return a.index.compareTo(b.index);
  }

  /// Save image and cache metadata in SharedPreferences.
  /// Supports multiple images under the same `storageKey` by upserting via `id + index`.
  static Future<File?> storeImageLocally(
    String id,
    String filePath,
    String storageKey,
    String folderName, {
    int index = 0,
    String? remoteUrl,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}${Platform.pathSeparator}$folderName');

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final fileExtension = filePath.contains('.') ? filePath.split('.').last : 'jpg';
      final localFileName = '${id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final localFile = await File(filePath).copy('${dir.path}${Platform.pathSeparator}$localFileName');

      final prefs = await SharedPreferences.getInstance();
      final existingValue = prefs.getString(storageKey);
      final items = existingValue == null
          ? <LocalImageMetadata>[]
          : _decodeMetadataList(existingValue);

      final upsertAt = items.indexWhere(
        (item) => item.id == id && item.index == index,
      );

      if (upsertAt >= 0) {
        final oldItem = items[upsertAt];
        if (oldItem.filePath != localFile.path) {
          final oldFile = File(oldItem.filePath);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }

        items[upsertAt] = LocalImageMetadata(
          id: id,
          index: index,
          filePath: localFile.path,
          remoteUrl: remoteUrl ?? oldItem.remoteUrl,
        );
      } else {
        items.add(
          LocalImageMetadata(
            id: id,
            index: index,
            filePath: localFile.path,
            remoteUrl: remoteUrl,
          ),
        );
      }

      items.sort(_sortByIndex);

      await prefs.setString(
        storageKey,
        _encodeMetadataList(items),
      );

      return localFile;
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      return null;
    }
  }

  /// Load a saved image by SharedPreferences key.
  /// For multi-image keys this returns the first valid file (lowest index).
  /// Supports list JSON, single metadata JSON, and old raw-path values.
  static Future<File?> loadSavedImage(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(storageKey);

    if (savedValue == null || savedValue.isEmpty) {
      return null;
    }

    final items = _decodeMetadataList(savedValue)..sort(_sortByIndex);
    if (items.isEmpty) {
      await prefs.remove(storageKey);
      return null;
    }

    final validItems = <LocalImageMetadata>[];
    File? firstFile;

    for (final item in items) {
      final file = File(item.filePath);
      if (await file.exists()) {
        validItems.add(item);
        firstFile ??= file;
      }
    }

    if (firstFile == null) {
      await prefs.remove(storageKey);
      return null;
    }

    final normalizedJson = _encodeMetadataList(validItems);
    if (savedValue != normalizedJson) {
      await prefs.setString(storageKey, normalizedJson);
    }

    return firstFile;
  }

  /// Load all saved images by SharedPreferences key.
  /// Use `id` to filter records for a specific entity (for example a post or user).
  static Future<List<File>> loadSavedImages(String storageKey, {String? id}) async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(storageKey);

    if (savedValue == null || savedValue.isEmpty) {
      return <File>[];
    }

    final items = _decodeMetadataList(savedValue)..sort(_sortByIndex);
    if (items.isEmpty) {
      await prefs.remove(storageKey);
      return <File>[];
    }

    final validItems = <LocalImageMetadata>[];
    final files = <File>[];

    for (final item in items) {
      final file = File(item.filePath);
      if (await file.exists()) {
        validItems.add(item);
        if (id == null || item.id == id) {
          files.add(file);
        }
      }
    }

    if (validItems.isEmpty) {
      await prefs.remove(storageKey);
      return <File>[];
    }

    final normalizedJson = _encodeMetadataList(validItems);
    if (savedValue != normalizedJson) {
      await prefs.setString(storageKey, normalizedJson);
    }

    return files;
  }

  /// Update an existing local image record with the Supabase remote URL.
  /// For multi-image keys, this updates the first record (lowest index).
  static Future<void> cacheRemoteUrl(String storageKey, String remoteUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(storageKey);
    if (savedValue == null || savedValue.isEmpty) return;

    final items = _decodeMetadataList(savedValue)..sort(_sortByIndex);
    if (items.isEmpty) return;

    final first = items.first;
    items[0] = LocalImageMetadata(
      id: first.id,
      index: first.index,
      filePath: first.filePath,
      remoteUrl: remoteUrl,
    );

    await prefs.setString(storageKey, _encodeMetadataList(items));
  }

  /// Update remote URL for a specific image record identified by `id + index`.
  static Future<void> cacheRemoteUrlByIndex(
    String storageKey, {
    required String id,
    required int index,
    required String remoteUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(storageKey);
    if (savedValue == null || savedValue.isEmpty) return;

    final items = _decodeMetadataList(savedValue);
    final targetIndex = items.indexWhere(
      (item) => item.id == id && item.index == index,
    );
    if (targetIndex < 0) return;

    final target = items[targetIndex];
    items[targetIndex] = LocalImageMetadata(
      id: target.id,
      index: target.index,
      filePath: target.filePath,
      remoteUrl: remoteUrl,
    );

    items.sort(_sortByIndex);
    await prefs.setString(storageKey, _encodeMetadataList(items));
  }
}