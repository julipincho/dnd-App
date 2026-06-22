import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const imageBucket = String.fromEnvironment(
    'SUPABASE_IMAGE_BUCKET',
    defaultValue: 'user-images',
  );

  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static Future<void> initializeIfConfigured() async {
    if (!isConfigured) {
      debugPrint(
        'Supabase not configured. Pass SUPABASE_URL and SUPABASE_ANON_KEY '
        'with --dart-define to enable image uploads.',
      );
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static Future<String> uploadUserImage({
    required File file,
    required String ownerUserId,
    required String folder,
    String? entityId,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Supabase is not configured. Run Flutter with SUPABASE_URL and '
        'SUPABASE_ANON_KEY dart-defines before uploading images.',
      );
    }

    final extension = _extensionFor(file.path);
    final storagePath = _storagePath(
      ownerUserId: ownerUserId,
      folder: folder,
      entityId: entityId,
      extension: extension,
    );

    await Supabase.instance.client.storage.from(imageBucket).upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(extension),
          ),
        );

    return Supabase.instance.client.storage
        .from(imageBucket)
        .getPublicUrl(storagePath);
  }

  static Future<String> uploadUserImageBytes({
    required Uint8List bytes,
    required String fileName,
    required String ownerUserId,
    required String folder,
    String? entityId,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Supabase is not configured. Run Flutter with SUPABASE_URL and '
        'SUPABASE_ANON_KEY dart-defines before uploading images.',
      );
    }
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Image bytes cannot be empty.');
    }

    final extension = _extensionFor(fileName);
    final storagePath = _storagePath(
      ownerUserId: ownerUserId,
      folder: folder,
      entityId: entityId,
      extension: extension,
    );

    await Supabase.instance.client.storage.from(imageBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(extension),
          ),
        );

    return Supabase.instance.client.storage
        .from(imageBucket)
        .getPublicUrl(storagePath);
  }

  static String _storagePath({
    required String ownerUserId,
    required String folder,
    required String extension,
    String? entityId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeOwner = _safePathSegment(ownerUserId);
    final safeFolder = _safePathSegment(folder);
    final safeEntity =
        entityId == null || entityId.trim().isEmpty ? 'image' : entityId;
    final fileName = '${_safePathSegment(safeEntity)}_$timestamp$extension';
    return 'users/$safeOwner/$safeFolder/$fileName';
  }

  static String _safePathSegment(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static String _extensionFor(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1 || lastDot == path.length - 1) return '.jpg';
    return path.substring(lastDot).toLowerCase();
  }

  static String _contentTypeFor(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
