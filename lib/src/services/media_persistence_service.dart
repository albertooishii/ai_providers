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

  Future<int> _clearDirectoryContents(final Directory dir) async {
    if (!dir.existsSync()) return 0;

    int deletedFiles = 0;
    final entities = dir.listSync();
    for (final entity in entities) {
      try {
        if (entity is File) {
          await entity.delete();
          deletedFiles++;
        } else if (entity is Directory) {
          deletedFiles += await _clearDirectoryContents(entity);
          await entity.delete(recursive: true);
        }
      } on Exception catch (e) {
        AILogger.w('[MediaPersistence] Error clearing cache entry: $e');
      }
    }

    return deletedFiles;
  }

  Future<int> clearAudioCache() async {
    final audioDir = await _getAudioDir();
    final deleted = await _clearDirectoryContents(audioDir);
    AILogger.d('[MediaPersistence] Cleared $deleted audio cache files');
    return deleted;
  }

  Future<int> clearImageCache() async {
    final imagesDir = await _getImagesDir();
    final deleted = await _clearDirectoryContents(imagesDir);
    AILogger.d('[MediaPersistence] Cleared $deleted image cache files');
    return deleted;
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
        AILogger.d(
            '[MediaPersistence] Base64 decoded to ${bytes.length} bytes');
        if (bytes.length > 10) {
          final header = bytes
              .take(10)
              .map((final b) => b.toRadixString(16).padLeft(2, '0'))
              .join(' ');
          AILogger.d('[MediaPersistence] File header: $header');
        }
      } on FormatException catch (e) {
        AILogger.w('Invalid base64 format: $e');
        return null;
      }

      // Generate filename with appropriate extension
      final extension = mediaType == 'image' ? 'jpg' : 'wav';
      final finalFileName = fileName ??
          '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      // Get appropriate directory
      final mediaDir =
          mediaType == 'image' ? await _getImagesDir() : await _getAudioDir();
      final filePath = '${mediaDir.path}/$finalFileName';
      final file = await File(filePath).writeAsBytes(bytes);

      if (file.existsSync()) {
        AILogger.d('$mediaType saved: $filePath');
        return filePath; // Devolver ruta completa en lugar de solo el nombre
      }

      return null;
    } on Exception catch (e) {
      AILogger.e('Error saving base64 $mediaType: $e');
      return null;
    }
  }

  /// Guardar imagen desde base64
  /// Retorna la ruta completa del archivo guardado o null si falló
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

  /// Guardar audio desde base64 (Google TTS devuelve PCM, lo convertimos a WAV)
  /// Retorna la ruta completa del archivo guardado o null si falló
  Future<String?> saveBase64Audio(
    final String base64, {
    final String prefix = 'tts',
  }) async {
    try {
      if (base64.trim().isEmpty) return null;

      // Decode base64 to PCM data
      String normalized = base64.trim();
      if (normalized.startsWith('data:')) {
        final idx = normalized.indexOf('base64,');
        if (idx != -1 && idx + 7 < normalized.length) {
          normalized = normalized.substring(idx + 7);
        }
      }

      Uint8List pcmData;
      try {
        pcmData = base64Decode(normalized);
        AILogger.d(
            '[MediaPersistence] Decoded ${pcmData.length} PCM bytes from Google');
      } on FormatException catch (e) {
        AILogger.w('Invalid base64 format: $e');
        return null;
      }

      // Generate filename
      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.wav';
      final audioDir = await _getAudioDir();
      final filePath = '${audioDir.path}/$fileName';

      // Convert PCM to WAV format (Google TTS uses 24kHz, mono, 16-bit)
      final wavData = _createWavFile(pcmData,
          sampleRate: 24000, channels: 1, bitsPerSample: 16);

      final file = await File(filePath).writeAsBytes(wavData);

      if (file.existsSync()) {
        AILogger.d('[MediaPersistence] Saved WAV audio as $filePath');
        return filePath;
      }

      return null;
    } on Exception catch (e) {
      AILogger.w('[MediaPersistence] Error saving audio: $e');
      return null;
    }
  }

  /// Create WAV file from PCM data
  Uint8List _createWavFile(
    final Uint8List pcmData, {
    required final int sampleRate,
    required final int channels,
    required final int bitsPerSample,
  }) {
    final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final int blockAlign = channels * (bitsPerSample ~/ 8);
    final int dataSize = pcmData.length;
    final int chunkSize = 36 + dataSize;

    final ByteData header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, chunkSize, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // subchunk1Size
    header.setUint16(20, 1, Endian.little); // audioFormat (PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    // Combine header and PCM data
    final wavFile = Uint8List(44 + dataSize);
    wavFile.setRange(0, 44, header.buffer.asUint8List());
    wavFile.setRange(44, 44 + dataSize, pcmData);

    return wavFile;
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
