import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../utils/logger.dart';
import '../infrastructure/cache_service.dart';

/// Servicio consolidado de persistencia para archivos multimedia
/// Maneja imágenes y audio usando la misma infraestructura
class MediaPersistenceService {
  MediaPersistenceService._();

  static final MediaPersistenceService _instance = MediaPersistenceService._();
  static MediaPersistenceService get instance => _instance;

  /// Internal method to get images directory (using cache)
  Future<Directory> _getImagesDir() async {
    final cacheService = CompleteCacheService.instance;
    final cacheDir = await cacheService.getCacheDirectory();
    final imagesDir = Directory('${cacheDir.path}/images');
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
    return imagesDir;
  }

  /// Internal method to get audio directory (using cache)
  Future<Directory> _getAudioDir() async {
    final cacheService = CompleteCacheService.instance;
    final audioDir = await cacheService.getAudioCacheDirectory();
    return audioDir;
  }

  /// Internal method to save base64 to file with specific directory
  Future<String?> _saveBase64ToFile(
    final String base64, {
    final String prefix = 'file',
    final String? fileName,
    required final String mediaType, // 'image' or 'audio'
  }) async {
    try {
      // Normalize data URI format
      String normalized = base64.trim();
      if (normalized.startsWith('data:')) {
        final idx = normalized.indexOf('base64,');
        if (idx != -1 && idx + 7 < normalized.length) {
          normalized = normalized.substring(idx + 7);
        }
      }

      // Decode base64
      Uint8List bytes;
      try {
        bytes = base64Decode(normalized);
      } on FormatException catch (e) {
        AILogger.w('Invalid base64 format: $e');
        return null;
      }

      // Generate filename with appropriate extension
      final extension = mediaType == 'image' ? 'jpg' : 'mp3';
      final finalFileName = fileName ??
          '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      // Get appropriate directory
      final mediaDir =
          mediaType == 'image' ? await _getImagesDir() : await _getAudioDir();
      final filePath = '${mediaDir.path}/$finalFileName';
      final file = await File(filePath).writeAsBytes(bytes);

      if (file.existsSync()) {
        AILogger.d('$mediaType saved: $filePath');
        return finalFileName;
      }

      return null;
    } on Exception catch (e) {
      AILogger.e('Error saving base64 $mediaType: $e');
      return null;
    }
  }

  /// Guardar imagen desde base64
  Future<String?> saveBase64Image(
    final String base64, {
    final String prefix = 'img',
  }) async {
    try {
      if (base64.trim().isEmpty) return null;

      // Generar UUID único para el archivo
      final fileName = '${_generateUuidV4()}.jpg';
      final result = await _saveBase64ToFile(
        base64,
        prefix: prefix,
        fileName: fileName,
        mediaType: 'image',
      );

      if (result != null) {
        AILogger.d('[MediaPersistence] Saved image as $result');
        return result;
      }

      AILogger.w('[MediaPersistence] saveBase64Image returned null');
      return null;
    } on Exception catch (e) {
      AILogger.e('[MediaPersistence] Error saving image', error: e);
      return null;
    }
  }

  /// Guardar audio desde base64
  Future<String?> saveBase64Audio(
    final String base64, {
    final String prefix = 'audio',
  }) async {
    try {
      if (base64.trim().isEmpty) return null;

      // Reutilizar la infraestructura para audio
      final result = await _saveBase64ToFile(
        base64,
        prefix: prefix,
        mediaType: 'audio',
      );

      if (result == null) {
        AILogger.w('[MediaPersistence] saveBase64Audio returned null');
        return null;
      }

      AILogger.d('[MediaPersistence] Saved audio as $result');
      return result;
    } on Exception catch (e) {
      AILogger.w('[MediaPersistence] Error saving audio: $e');
      return null;
    }
  }

  /// Cargar audio como bytes desde fileName relativo
  Future<List<int>?> loadAudioAsBytes(final String fileName) async {
    try {
      final dir = await _getAudioDir();
      final file = File(p.join(dir.path, fileName));
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } on Exception catch (e) {
      AILogger.w('[MediaPersistence] Error loading audio $fileName: $e');
      return null;
    }
  }

  /// Cargar imagen como bytes desde fileName relativo
  Future<List<int>?> loadImageAsBytes(final String fileName) async {
    try {
      final dir = await _getImagesDir();
      final file = File(p.join(dir.path, fileName));
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } on Exception catch (e) {
      AILogger.w('[MediaPersistence] Error loading image $fileName: $e');
      return null;
    }
  }

  /// Eliminar archivo multimedia (busca en ambos directorios)
  Future<bool> deleteMediaFile(final String fileName) async {
    try {
      // Intentar eliminar de imágenes primero
      final imageDir = await _getImagesDir();
      final imageFile = File(p.join(imageDir.path, fileName));
      if (imageFile.existsSync()) {
        await imageFile.delete();
        AILogger.d('[MediaPersistence] Deleted image file: $fileName');
        return true;
      }

      // Si no está en imágenes, intentar en audio
      final audioDir = await _getAudioDir();
      final audioFile = File(p.join(audioDir.path, fileName));
      if (audioFile.existsSync()) {
        await audioFile.delete();
        AILogger.d('[MediaPersistence] Deleted audio file: $fileName');
        return true;
      }

      return false;
    } on Exception catch (e) {
      AILogger.w('[MediaPersistence] Error deleting file $fileName: $e');
      return false;
    }
  }

  /// Generar UUID v4 para nombres únicos
  String _generateUuidV4() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (final _) => rand.nextInt(256));

    // Set version to 4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String toHex(final List<int> b) =>
        b.map((final e) => e.toRadixString(16).padLeft(2, '0')).join();

    final hex = toHex(bytes);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// Backward compatibility - Image persistence
class ImagePersistenceService {
  ImagePersistenceService._();
  static final ImagePersistenceService instance = ImagePersistenceService._();

  Future<String?> saveBase64Image(
    final String base64, {
    final String prefix = 'img',
  }) =>
      MediaPersistenceService.instance.saveBase64Image(base64, prefix: prefix);
}

/// Backward compatibility - Audio persistence
class AudioPersistenceService {
  AudioPersistenceService._();
  static final AudioPersistenceService instance = AudioPersistenceService._();

  Future<String?> saveBase64Audio(
    final String base64, {
    final String prefix = 'audio',
  }) =>
      MediaPersistenceService.instance.saveBase64Audio(base64, prefix: prefix);

  Future<List<int>?> loadAudioAsBytes(final String fileName) =>
      MediaPersistenceService.instance.loadAudioAsBytes(fileName);
}
