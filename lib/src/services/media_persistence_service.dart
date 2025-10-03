import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../utils/logger.dart';
import '../infrastructure/cache_service.dart';

/// Información del formato de audio detectado
class AudioFormatInfo {
  AudioFormatInfo({
    required this.isWav,
    required this.isPcm,
    required this.formatName,
    this.sampleRate,
    this.channels,
    this.bitsPerSample,
  });
  final bool isWav;
  final bool isPcm;
  final String formatName;
  final int? sampleRate;
  final int? channels;
  final int? bitsPerSample;
}

/// Resultado del guardado de audio con ruta y base64 del archivo final
class AudioSaveResult {
  AudioSaveResult({
    required this.filePath,
    required this.base64,
  });

  final String filePath;
  final String base64;
}

/// Parámetros unificados para conversión FFmpeg
class _FFmpegParams {
  _FFmpegParams({
    required this.inputPath,
    required this.outputPath,
    required this.format,
    required this.sampleRate,
    required this.channels,
    required this.bitrate,
  });
  final String inputPath;
  final String outputPath;
  final String format;
  final int sampleRate;
  final int channels;
  final int bitrate;

  /// Generar argumentos FFmpeg unificados
  List<String> get args {
    final List<String> baseArgs = [
      '-f',
      's16le',
      '-ar',
      sampleRate.toString(),
      '-ac',
      channels.toString(),
      '-i',
      inputPath,
    ];

    switch (format.toLowerCase()) {
      case 'm4a':
      case 'aac':
        return baseArgs +
            ['-c:a', 'aac', '-b:a', '${bitrate}k', '-y', outputPath];
      case 'mp3':
        return baseArgs +
            ['-c:a', 'libmp3lame', '-b:a', '${bitrate}k', '-y', outputPath];
      default:
        throw ArgumentError('Formato no soportado: $format');
    }
  }

  /// Generar comando FFmpeg unificado para FFmpeg Kit
  String get command {
    return args
        .join(' ')
        .replaceAll(inputPath, '"$inputPath"')
        .replaceAll(outputPath, '"$outputPath"');
  }
}

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

  /// Guardar audio desde base64 (OPTIMIZADO)
  /// Pipeline optimizado:
  /// - Detección inteligente de formato
  /// - Conversión directa PCM→M4A sin archivos temporales
  /// - Cache basado en hash de contenido
  /// Retorna la ruta completa del archivo guardado o null si falló
  /// Guarda audio desde base64 y devuelve tanto la ruta como el base64 del archivo final
  Future<AudioSaveResult?> saveBase64AudioComplete(
    final String base64, {
    final String prefix = 'tts',
    final String outputFormat = 'm4a', // 'm4a', 'wav', 'mp3'
    final int bitrate = 128, // kbps para formatos comprimidos
  }) async {
    try {
      final filePath = await saveBase64Audio(
        base64,
        prefix: prefix,
        outputFormat: outputFormat,
        bitrate: bitrate,
      );

      if (filePath == null) return null;

      // Leer el archivo convertido y generar base64
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final convertedBytes = await file.readAsBytes();
      final convertedBase64 = base64Encode(convertedBytes);

      return AudioSaveResult(
        filePath: filePath,
        base64: convertedBase64,
      );
    } on Exception catch (e) {
      AILogger.w('[MediaPersistence] Error saving audio complete: $e');
      return null;
    }
  }

  /// Método legacy - mantener compatibilidad
  Future<String?> saveBase64Audio(
    final String base64, {
    final String prefix = 'tts',
    final String outputFormat = 'm4a', // 'm4a', 'wav', 'mp3'
    final int bitrate = 128, // kbps para formatos comprimidos
  }) async {
    try {
      if (base64.trim().isEmpty) return null;

      // Decode base64 to audio data
      String normalized = base64.trim();
      if (normalized.startsWith('data:')) {
        final idx = normalized.indexOf('base64,');
        if (idx != -1 && idx + 7 < normalized.length) {
          normalized = normalized.substring(idx + 7);
        }
      }

      Uint8List audioData;
      AudioFormatInfo formatInfo;

      try {
        audioData = base64Decode(normalized);
        formatInfo = _detectAudioFormat(audioData);

        AILogger.d(
            '[MediaPersistence] Decoded ${audioData.length} bytes as ${formatInfo.formatName}');
      } on FormatException catch (e) {
        AILogger.w('Invalid base64 format: $e');
        return null;
      }

      // Cache inteligente basado en hash
      final contentHash = _calculateContentHash(audioData);
      final cachedPath = await _checkAudioCache(contentHash, outputFormat);
      if (cachedPath != null) {
        AILogger.d('[MediaPersistence] ♻️ Using cached audio: $cachedPath');
        return cachedPath;
      }

      // Generate filename with appropriate extension
      final extension = outputFormat.toLowerCase();
      final fileName =
          '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final audioDir = await _getAudioDir();
      final finalPath = '${audioDir.path}/$fileName';

      // Optimización: evitar conversión si el formato ya es el deseado
      if (_isFormatCompatible(formatInfo, outputFormat)) {
        await File(finalPath).writeAsBytes(audioData);
        await _cacheAudioFile(contentHash, finalPath, outputFormat);
        AILogger.d(
            '[MediaPersistence] 🚀 Saved audio directly (no conversion): $finalPath');
        return finalPath;
      }

      // Si es WAV y lo solicitamos, usar directamente
      if (extension == 'wav') {
        final Uint8List wavData = formatInfo.isWav
            ? audioData
            : _createWavFile(audioData,
                sampleRate: 24000, channels: 1, bitsPerSample: 16);
        await File(finalPath).writeAsBytes(wavData);
        await _cacheAudioFile(contentHash, finalPath, outputFormat);
        AILogger.d('[MediaPersistence] Saved WAV audio: $finalPath');
        return finalPath;
      }

      // Conversión optimizada sin archivos temporales
      final success = await _convertToCompressedFormatOptimized(
        audioData,
        formatInfo,
        finalPath,
        outputFormat,
        bitrate,
      );

      if (success && File(finalPath).existsSync()) {
        await _cacheAudioFile(contentHash, finalPath, outputFormat);
        AILogger.d(
            '[MediaPersistence] 🎵 Saved optimized $outputFormat: $finalPath');
        return finalPath;
      }

      return null;
    } on Exception catch (e) {
      AILogger.w('[MediaPersistence] Error saving audio: $e');
      return null;
    }
  }

  /// Cache de archivos de audio para evitar reconversiones
  final Map<String, String> _audioCache = {};

  /// Detectar formato de audio automáticamente
  AudioFormatInfo _detectAudioFormat(final Uint8List audioData) {
    if (audioData.length < 4) {
      return AudioFormatInfo(
          isWav: false, isPcm: true, formatName: 'PCM (Unknown)');
    }

    // Detectar WAV (RIFF header)
    final isWav = audioData.length > 12 &&
        audioData[0] == 0x52 && // 'R'
        audioData[1] == 0x49 && // 'I'
        audioData[2] == 0x46 && // 'F'
        audioData[3] == 0x46; // 'F'

    if (isWav) {
      // Extraer información del header WAV
      try {
        final byteData = ByteData.sublistView(audioData);
        final sampleRate = byteData.getUint32(24, Endian.little);
        final channels = byteData.getUint16(22, Endian.little);
        final bitsPerSample = byteData.getUint16(34, Endian.little);

        return AudioFormatInfo(
          isWav: true,
          isPcm: false,
          formatName:
              'WAV (${sampleRate}Hz, ${channels}ch, ${bitsPerSample}bit)',
          sampleRate: sampleRate,
          channels: channels,
          bitsPerSample: bitsPerSample,
        );
      } on Exception {
        return AudioFormatInfo(
            isWav: true, isPcm: false, formatName: 'WAV (Invalid header)');
      }
    }

    // Detectar M4A/AAC (ftyp header)
    if (audioData.length > 8) {
      final hasM4AHeader = audioData[4] == 0x66 && // 'f'
          audioData[5] == 0x74 && // 't'
          audioData[6] == 0x79 && // 'y'
          audioData[7] == 0x70; // 'p'

      if (hasM4AHeader) {
        return AudioFormatInfo(
            isWav: false, isPcm: false, formatName: 'M4A/MP4');
      }
    }

    // Default: PCM raw
    return AudioFormatInfo(
      isWav: false,
      isPcm: true,
      formatName: 'PCM Raw (${audioData.length} bytes)',
    );
  }

  /// Verificar si el formato actual es compatible con el solicitado
  bool _isFormatCompatible(
      final AudioFormatInfo current, final String requested) {
    final req = requested.toLowerCase();

    // WAV es compatible con WAV
    if (current.isWav && req == 'wav') return true;

    // M4A es compatible con M4A/AAC
    if (current.formatName.contains('M4A') && (req == 'm4a' || req == 'aac')) {
      return true;
    }

    return false;
  }

  /// Calcular hash del contenido para cache
  String _calculateContentHash(final Uint8List data) {
    // Hash simple basado en tamaño y primeros/últimos bytes
    final size = data.length;
    final start = data.take(16).join();
    final end = data.skip(size - 16).take(16).join();
    return '${size}_${start}_$end';
  }

  /// Verificar cache de audio
  Future<String?> _checkAudioCache(
      final String contentHash, final String format) async {
    final cacheKey = '${contentHash}_$format';
    final cachedPath = _audioCache[cacheKey];

    if (cachedPath != null && File(cachedPath).existsSync()) {
      return cachedPath;
    }

    // Limpiar cache si el archivo ya no existe
    _audioCache.remove(cacheKey);
    return null;
  }

  /// Guardar archivo en cache
  Future<void> _cacheAudioFile(final String contentHash, final String filePath,
      final String format) async {
    final cacheKey = '${contentHash}_$format';
    _audioCache[cacheKey] = filePath;

    // Limitar tamaño del cache (mantener últimos 50)
    if (_audioCache.length > 50) {
      final oldestKey = _audioCache.keys.first;
      _audioCache.remove(oldestKey);
    }
  }

  /// Conversión optimizada sin archivos temporales
  Future<bool> _convertToCompressedFormatOptimized(
    final Uint8List audioData,
    final AudioFormatInfo formatInfo,
    final String outputPath,
    final String format,
    final int bitrate,
  ) async {
    try {
      AILogger.d(
          '[MediaPersistence] 🚀 Optimized conversion: ${formatInfo.formatName} → $format ($bitrate kbps)');

      // Verificar si FFmpeg está disponible
      if (!_isFFmpegSupported()) {
        return _optimizedPlatformFallback(
            audioData, formatInfo, outputPath, format, bitrate);
      }

      return _convertWithFFmpegOptimized(
          audioData, formatInfo, outputPath, format, bitrate);
    } on Exception catch (e) {
      AILogger.e('[MediaPersistence] Error en conversión optimizada: $e');
      return _fallbackToWavOptimized(audioData, formatInfo, outputPath);
    }
  }

  /// Conversión unificada con FFmpeg (Kit o Nativo)
  Future<bool> _convertWithUnifiedFFmpeg(
    final Uint8List audioData,
    final AudioFormatInfo formatInfo,
    final String outputPath,
    final String format,
    final int bitrate,
    final bool useFFmpegKit,
  ) async {
    try {
      final String method = useFFmpegKit ? 'FFmpeg Kit' : 'Native FFmpeg';
      AILogger.d(
          '[MediaPersistence] 🎵 $method unified: ${formatInfo.formatName} → $format');

      // Preparar datos PCM comunes
      final Uint8List pcmData = formatInfo.isWav
          ? audioData.sublist(44) // Extraer PCM del WAV
          : audioData;

      // Crear archivo PCM temporal
      final tempPcmPath = '${outputPath}_temp.pcm';
      await File(tempPcmPath).writeAsBytes(pcmData);

      try {
        // Parámetros unificados
        final params = _FFmpegParams(
          inputPath: tempPcmPath,
          outputPath: outputPath,
          format: format,
          sampleRate: formatInfo.sampleRate ?? 24000,
          channels: formatInfo.channels ?? 1,
          bitrate: bitrate,
        );

        // Ejecutar según el método disponible
        final bool success = useFFmpegKit
            ? await _executeFFmpegKit(params)
            : await _executeNativeFFmpeg(params);

        if (success) {
          AILogger.d(
              '[MediaPersistence] ✅ $method unified success: $outputPath');
          return File(outputPath).existsSync();
        } else {
          AILogger.e('[MediaPersistence] $method unified failed');
          return false;
        }
      } finally {
        // Limpiar archivo temporal PCM siempre
        try {
          await File(tempPcmPath).delete();
        } on Exception catch (_) {}
      }
    } on Exception catch (e) {
      AILogger.e('[MediaPersistence] Error en conversión unificada: $e');
      return false;
    }
  }

  /// Ejecutar FFmpeg Kit con parámetros unificados
  Future<bool> _executeFFmpegKit(final _FFmpegParams params) async {
    try {
      final session = await FFmpegKit.execute(params.command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        AILogger.e('[MediaPersistence] FFmpeg Kit error: $output');
        return false;
      }
      return true;
    } on Exception catch (e) {
      AILogger.e('[MediaPersistence] FFmpeg Kit execution error: $e');
      return false;
    }
  }

  /// Ejecutar FFmpeg nativo con parámetros unificados
  Future<bool> _executeNativeFFmpeg(final _FFmpegParams params) async {
    try {
      // Verificar FFmpeg disponible
      final ffmpegResult = await Process.run('ffmpeg', ['-version']);
      if (ffmpegResult.exitCode != 0) {
        await _showFFmpegInstallInstructions();
        return false;
      }

      // Ejecutar comando
      final result = await Process.run('ffmpeg', params.args);

      if (result.exitCode != 0) {
        AILogger.e('[MediaPersistence] Native FFmpeg error: ${result.stderr}');
        return false;
      }
      return true;
    } on Exception catch (e) {
      AILogger.e('[MediaPersistence] Native FFmpeg execution error: $e');
      return false;
    }
  }

  /// Conversión con FFmpeg optimizada (ahora usa método unificado)
  Future<bool> _convertWithFFmpegOptimized(
    final Uint8List audioData,
    final AudioFormatInfo formatInfo,
    final String outputPath,
    final String format,
    final int bitrate,
  ) async {
    return _convertWithUnifiedFFmpeg(audioData, formatInfo, outputPath, format,
        bitrate, true); // useFFmpegKit = true
  }

  /// Fallback optimizado para plataformas no soportadas (ahora usa método unificado)
  Future<bool> _optimizedPlatformFallback(
    final Uint8List audioData,
    final AudioFormatInfo formatInfo,
    final String outputPath,
    final String format,
    final int bitrate,
  ) async {
    try {
      // Intentar FFmpeg nativo unificado
      final success = await _convertWithUnifiedFFmpeg(audioData, formatInfo,
          outputPath, format, bitrate, false); // useFFmpegKit = false

      if (success) {
        return true;
      }

      // Fallback WAV optimizado si FFmpeg no está disponible
      return _fallbackToWavOptimized(audioData, formatInfo, outputPath);
    } on Exception catch (e) {
      AILogger.e(
          '[MediaPersistence] Error en platform fallback optimizado: $e');
      return _fallbackToWavOptimized(audioData, formatInfo, outputPath);
    }
  }

  /// Fallback final optimizado: guardar como WAV
  Future<bool> _fallbackToWavOptimized(
    final Uint8List audioData,
    final AudioFormatInfo formatInfo,
    final String outputPath,
  ) async {
    try {
      // Cambiar extensión a WAV
      final wavPath =
          outputPath.replaceAll('.m4a', '.wav').replaceAll('.mp3', '.wav');

      Uint8List wavData;
      if (formatInfo.isWav) {
        // Ya es WAV, usar directamente
        wavData = audioData;
      } else {
        // Crear WAV desde PCM
        wavData = _createWavFile(audioData,
            sampleRate: 24000, channels: 1, bitsPerSample: 16);
      }

      await File(wavPath).writeAsBytes(wavData);

      AILogger.i(
          '[MediaPersistence] 🚨 Fallback optimizado: guardado como WAV en $wavPath');
      return File(wavPath).existsSync();
    } on Exception catch (e) {
      AILogger.e('[MediaPersistence] Error en WAV fallback optimizado: $e');
      return false;
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

  /// Verificar si FFmpeg está soportado en la plataforma actual
  bool _isFFmpegSupported() {
    // FFmpeg Kit soporta Android, iOS y macOS
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Mostrar instrucciones de instalación de FFmpeg según la plataforma
  Future<void> _showFFmpegInstallInstructions() async {
    String instructions;

    if (Platform.isLinux) {
      instructions = '''
╔══════════════════════════════════════════════════════════════════╗
║                    🎵 FFmpeg no encontrado                       ║
╠══════════════════════════════════════════════════════════════════╣
║ Para conversión de audio en Linux, instala FFmpeg:              ║
║                                                                  ║
║ Ubuntu/Debian:   sudo apt update && sudo apt install ffmpeg     ║
║ Fedora:          sudo dnf install ffmpeg                        ║
║ Arch:            sudo pacman -S ffmpeg                          ║
║ Snap:            sudo snap install ffmpeg                       ║
║                                                                  ║
║ Mientras tanto, usaremos formato WAV (sin compresión)           ║
╚══════════════════════════════════════════════════════════════════╝''';
    } else if (Platform.isWindows) {
      instructions = '''
╔══════════════════════════════════════════════════════════════════╗
║                    🎵 FFmpeg no encontrado                       ║
╠══════════════════════════════════════════════════════════════════╣
║ Para conversión de audio en Windows, instala FFmpeg:            ║
║                                                                  ║
║ Chocolatey:      choco install ffmpeg                           ║
║ Scoop:           scoop install ffmpeg                           ║
║ Winget:          winget install FFmpeg                          ║
║ Manual:          https://ffmpeg.org/download.html#build-windows ║
║                                                                  ║
║ Mientras tanto, usaremos formato WAV (sin compresión)           ║
╚══════════════════════════════════════════════════════════════════╝''';
    } else {
      instructions = '''
╔══════════════════════════════════════════════════════════════════╗
║                    🎵 FFmpeg no encontrado                       ║
╠══════════════════════════════════════════════════════════════════╣
║ Para conversión de audio, instala FFmpeg desde:                 ║
║ https://ffmpeg.org/download.html                                ║
║                                                                  ║
║ Mientras tanto, usaremos formato WAV (sin compresión)           ║
╚══════════════════════════════════════════════════════════════════╝''';
    }

    AILogger.i('\n$instructions');
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
    final String outputFormat = 'm4a',
    final int bitrate = 128,
  }) =>
      MediaPersistenceService.instance.saveBase64Audio(
        base64,
        prefix: prefix,
        outputFormat: outputFormat,
        bitrate: bitrate,
      );

  Future<List<int>?> loadAudioAsBytes(final String fileName) =>
      MediaPersistenceService.instance.loadAudioAsBytes(fileName);
}
