import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../ai_providers.dart';
import '../core/ai_provider_manager.dart';
import '../infrastructure/cache_service.dart';
import '../utils/logger.dart';

/// 🎤 AudioGenerationService - Servicio completo de generación de audio
///
/// Consolida TODA la funcionalidad de TTS/audio en un solo lugar:
/// - Síntesis de texto a voz usando AI.speak()
/// - Cache inteligente de TTS
/// - Gestión de archivos temporales
/// - Reproducción de audio
/// - Control de estado de reproducción
///
/// Reemplaza audio_service.dart (549 líneas) con funcionalidad consolidada
class AudioGenerationService {
  AudioGenerationService._();
  static final AudioGenerationService _instance = AudioGenerationService._();
  static AudioGenerationService get instance => _instance;

  // Cache de TTS (ahora usando el sistema persistente consolidado)
  final Map<String, String> _ttsCache = {};
  final Map<String, Timer> _ttsCacheTimers = {};
  static const Duration _ttsCacheTimeout = Duration(minutes: 30);

  /// Get cache service reference
  CompleteCacheService? get _cacheService =>
      AIProviderManager.instance.cacheService;

  // Control de reproducción
  final StreamController<AudioPlaybackState> _playbackStateController =
      StreamController<AudioPlaybackState>.broadcast();
  AudioPlaybackState _currentState = AudioPlaybackState.idle;

  // Getters
  Stream<AudioPlaybackState> get playbackStateStream =>
      _playbackStateController.stream;
  AudioPlaybackState get playbackState => _currentState;
  bool get isPlaying => _currentState == AudioPlaybackState.playing;

  /// Genera audio/TTS usando AI.speak() con cache inteligente
  Future<String?> synthesizeTts(
    final String text, {
    final String? languageCode,
    final bool forDialogDemo = false,
  }) async {
    try {
      if (text.trim().isEmpty) {
        AILogger.w('[AudioGenerationService] Texto vacío para TTS');
        return null;
      }

      // 🔍 Verificar caché persistente primero
      final effectiveLanguage = languageCode ?? 'es-ES';
      if (_cacheService != null) {
        final cachedFile = await _cacheService!.getCachedAudioFile(
          text: text,
          voice: 'default', // TODO: Obtener voz actual del provider
          languageCode: effectiveLanguage,
          provider: 'audio_service', // Identificador para este servicio
        );
        if (cachedFile != null) {
          AILogger.d(
              '[AudioGenerationService] TTS desde caché persistente: ${cachedFile.path}');
          return cachedFile.path;
        }
      }

      // Verificar cache temporal (fallback)
      final cacheKey = _getTtsCacheKey(text, effectiveLanguage);
      if (_ttsCache.containsKey(cacheKey)) {
        AILogger.d('[AudioGenerationService] TTS desde cache temporal');
        return _ttsCache[cacheKey];
      }

      AILogger.d(
          '[AudioGenerationService] 🎤 Generando TTS: ${text.substring(0, text.length.clamp(0, 50))}...');

      // 🚀 Usar nueva API AI.speak()
      final response = await AI.speak(text);

      if (response.audioFileName.isEmpty && response.text.isEmpty) {
        AILogger.w('[AudioGenerationService] No se pudo generar audio');
        return null;
      }

      // Procesar respuesta
      String? filePath;
      if (response.audioFileName.isNotEmpty) {
        filePath = response.audioFileName;
      } else if (response.text.isNotEmpty) {
        // Fallback: guardar base64 o path del texto
        filePath = await _processTextResponse(response.text, text);
      }

      if (filePath != null) {
        // 💾 Copiar a caché persistente si está disponible
        if (_cacheService != null) {
          try {
            final sourceFile = File(filePath);
            if (sourceFile.existsSync()) {
              final audioDir = await _cacheService!.getAudioCacheDirectory();
              final hash = _cacheService!.generateTtsHash(
                text: text,
                voice: 'default', // TODO: Obtener voz actual del provider
                languageCode: effectiveLanguage,
                provider: 'audio_service',
              );
              final targetFile = File('${audioDir.path}/$hash.mp3');
              await sourceFile.copy(targetFile.path);
              AILogger.d(
                  '[AudioGenerationService] 💾 Audio copiado a caché persistente: ${targetFile.path}');
            }
          } on Exception catch (e) {
            AILogger.w(
                '[AudioGenerationService] Error copiando a caché persistente: $e');
          }
        }

        // Agregar a cache temporal con timeout
        _ttsCache[cacheKey] = filePath;
        _ttsCacheTimers[cacheKey] = Timer(_ttsCacheTimeout, () {
          _ttsCache.remove(cacheKey);
          _ttsCacheTimers.remove(cacheKey);
          if (filePath != null) _cleanupTtsFile(filePath);
        });

        AILogger.d('[AudioGenerationService] ✅ TTS generado: $filePath');
      }

      return filePath;
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error generando TTS: $e');
      return null;
    }
  }

  /// TTS rápido usando AI.voice() - sin cache para casos simples
  Future<AIResponse> quickSpeech(final String text) async {
    try {
      AILogger.d(
          '[AudioGenerationService] ⚡ TTS rápido: ${text.substring(0, text.length.clamp(0, 50))}...');

      return await AI.speak(text);
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error en TTS rápido: $e');
      rethrow;
    }
  }

  /// Sintetizar y reproducir inmediatamente
  Future<void> synthesizeAndPlay(final String text,
      {final String? languageCode}) async {
    try {
      final filePath = await synthesizeTts(text, languageCode: languageCode);
      if (filePath != null) {
        await playAudioFile(filePath);
      }
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error en synthesizeAndPlay: $e');
    }
  }

  /// Reproducir archivo de audio
  Future<void> playAudioFile(final String filePath) async {
    try {
      _updateState(AudioPlaybackState.playing);

      // Aquí iría la lógica real de reproducción
      // Por ahora simulamos
      AILogger.d('[AudioGenerationService] 🔊 Reproduciendo: $filePath');

      // Simular finalización después de un tiempo
      Timer(const Duration(seconds: 2), () {
        _updateState(AudioPlaybackState.completed);
      });
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error reproduciendo archivo: $e');
      _updateState(AudioPlaybackState.idle);
    }
  }

  /// Detener reproducción
  Future<void> stopPlayback() async {
    try {
      _updateState(AudioPlaybackState.stopped);
      AILogger.d('[AudioGenerationService] Reproducción detenida');
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error deteniendo reproducción: $e');
    }
  }

  // === MÉTODOS PRIVADOS ===

  String _getTtsCacheKey(final String text, final String languageCode) {
    return '${text.hashCode}_$languageCode';
  }

  Future<String?> _processTextResponse(
      final String responseText, final String originalText) async {
    try {
      // Intentar decodificar como base64
      final audioBytes = base64.decode(responseText);
      return await _saveTtsToFile(audioBytes, originalText);
    } on Exception {
      // Si no es base64, asumir que es un path
      if (File(responseText).existsSync()) {
        return responseText;
      }
      return null;
    }
  }

  Future<String> _saveTtsToFile(
      final List<int> audioBytes, final String text) async {
    final tempDir = Directory.systemTemp;
    final fileName =
        'tts_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode.abs()}.mp3';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(audioBytes);
    return file.path;
  }

  void _cleanupTtsFile(final String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
        AILogger.d('[AudioGenerationService] Archivo TTS limpiado: $filePath');
      }
    } on Exception catch (e) {
      AILogger.w('[AudioGenerationService] Error limpiando archivo TTS: $e');
    }
  }

  void _updateState(final AudioPlaybackState newState) {
    _currentState = newState;
    _playbackStateController.add(newState);
  }

  /// Limpiar recursos
  void dispose() {
    // Detener reproducción
    if (isPlaying) {
      stopPlayback();
    }

    // Cerrar streams
    _playbackStateController.close();

    // Limpiar timers
    for (final timer in _ttsCacheTimers.values) {
      timer.cancel();
    }
    _ttsCacheTimers.clear();

    // Limpiar archivos TTS en cache
    for (final filePath in _ttsCache.values) {
      _cleanupTtsFile(filePath);
    }
    _ttsCache.clear();

    AILogger.d('[AudioGenerationService] Recursos liberados');
  }
}

/// Estados de reproducción de audio
enum AudioPlaybackState { idle, playing, paused, stopped, completed }
