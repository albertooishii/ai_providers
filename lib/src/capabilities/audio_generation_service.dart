import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import '../../ai_providers.dart';
import '../core/ai_provider_manager.dart';
import '../services/media_persistence_service.dart';
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
  // Sistema de reproducción REAL usando flutter_tts
  late FlutterTts _flutterTts;
  final StreamController<AudioPlaybackState> _playbackStateController =
      StreamController<AudioPlaybackState>.broadcast();
  AudioPlaybackState _currentState = AudioPlaybackState.idle;

  // Streams públicos para estado de reproducción
  Stream<AudioPlaybackState> get playbackStateStream =>
      _playbackStateController.stream;
  AudioPlaybackState get playbackState => _currentState;
  bool get isPlaying => _currentState == AudioPlaybackState.playing;

  // Constructor privado con inicialización
  AudioGenerationService._() {
    _initializeTts();
  }

  static final AudioGenerationService _instance = AudioGenerationService._();
  static AudioGenerationService get instance => _instance;

  /// 🎯 MÉTODO DE INTEGRACIÓN - usado por AI.speak()
  ///
  /// Recibe mismos parámetros que AI.speak() y delega a AIProviderManager.
  /// Esta es la firma EXACTA que necesita AI.speak() para evitar circular dependency.
  Future<AIResponse> synthesize(
    String text, [
    SynthesizeInstructions? instructions,
    bool saveToCache = false,
  ]) async {
    try {
      AILogger.d(
          '[AudioGenerationService] 🎤 Sintetizando audio: ${text.substring(0, text.length.clamp(0, 50))}...');

      // Crear SystemPrompt con instrucciones de síntesis
      final systemPrompt = _createSynthesizeSystemPrompt(instructions);

      // Llamar directamente a AIProviderManager (no a AI.speak() para evitar circular dependency)
      return await AIProviderManager.instance.sendMessage(
        message: text,
        systemPrompt: systemPrompt,
        capability: AICapability.audioGeneration,
        saveToCache: saveToCache,
      );
    } catch (e) {
      AILogger.e('[AudioGenerationService] ❌ Error sintetizando audio: $e');
      rethrow;
    }
  }

  /// Genera audio/TTS usando AI.speak() (simplificado)
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

      AILogger.d(
          '[AudioGenerationService] 🎤 Generando TTS: ${text.substring(0, text.length.clamp(0, 50))}...');

      // 🚀 Usar nuestro método de integración (no AI.speak() para evitar circular)
      final response = await synthesize(text, null, true);

      // Si hay archivo de audio, devolverlo
      if (response.audioFileName.isNotEmpty) {
        AILogger.d(
            '[AudioGenerationService] ✅ TTS generado: ${response.audioFileName}');
        return response.audioFileName;
      }

      // Si hay audioBase64 (de providers IA), guardarlo con MediaPersistenceService
      if (response.audioBase64 != null && response.audioBase64!.isNotEmpty) {
        final savedFileName = await MediaPersistenceService.instance
            .saveBase64Audio(response.audioBase64!);
        if (savedFileName != null) {
          AILogger.d(
              '[AudioGenerationService] ✅ Audio IA guardado: $savedFileName');
          return savedFileName;
        }
      }

      AILogger.w('[AudioGenerationService] No se pudo generar audio');
      return null;
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error generando TTS: $e');
      return null;
    }
  }

  /// Inicializar TTS con callbacks
  void _initializeTts() {
    _flutterTts = FlutterTts();
    _setupTtsHandlers();
  }

  /// Configurar handlers de TTS
  void _setupTtsHandlers() {
    _flutterTts.setStartHandler(() {
      _updateState(AudioPlaybackState.playing);
      AILogger.d('[AudioGenerationService] TTS iniciado');
    });

    _flutterTts.setCompletionHandler(() {
      _updateState(AudioPlaybackState.completed);
      AILogger.d('[AudioGenerationService] TTS completado');
    });

    _flutterTts.setErrorHandler((msg) {
      _updateState(AudioPlaybackState.error);
      AILogger.e('[AudioGenerationService] Error TTS: $msg');
    });
  }

  /// Sintetizar y reproducir inmediatamente - SDK COMPLETO
  Future<bool> synthesizeAndPlay(
    final String text, {
    final String? languageCode,
  }) async {
    try {
      AILogger.d(
          '[AudioGenerationService] 🎤🔊 SynthesizeAndPlay: ${text.substring(0, text.length.clamp(0, 50))}...');

      // Generar audio usando AI.speak() (siempre hay providers)
      final audioFile = await synthesizeTts(text, languageCode: languageCode);

      if (audioFile != null) {
        // Reproducir el archivo generado
        return await playAudioFile(audioFile);
      } else {
        AILogger.w('[AudioGenerationService] No se pudo generar audio');
        _updateState(AudioPlaybackState.error);
        return false;
      }
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error en synthesizeAndPlay: $e');
      _updateState(AudioPlaybackState.error);
      return false;
    }
  }

  // playTextDirectly() eliminado - siempre usamos providers IA

  /// Reproducir archivo de audio (archivos reales de providers IA)
  Future<bool> playAudioFile(final String filePath) async {
    try {
      AILogger.d(
          '[AudioGenerationService] 🔊 Reproduciendo archivo: $filePath');

      if (!File(filePath).existsSync()) {
        AILogger.w('[AudioGenerationService] Archivo no existe: $filePath');
        return false;
      }

      _updateState(AudioPlaybackState.loading);

      // TODO: Para soportar archivos reales necesitamos audioplayers package
      // Por ahora, notificamos que el archivo está listo y simulamos reproducción
      _updateState(AudioPlaybackState.playing);

      AILogger.i(
          '[AudioGenerationService] 📁 Archivo de audio listo para reproducir: $filePath');
      AILogger.w(
          '[AudioGenerationService] ⚠️  Necesita audioplayers package para reproducción real de archivos');

      // Simular completado después de un segundo
      Timer(const Duration(seconds: 1), () {
        _updateState(AudioPlaybackState.completed);
      });

      return true;
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error reproduciendo archivo: $e');
      _updateState(AudioPlaybackState.error);
      return false;
    }
  }

  /// Detener reproducción
  Future<bool> stopPlayback() async {
    try {
      final result = await _flutterTts.stop();
      _updateState(AudioPlaybackState.stopped);
      AILogger.d('[AudioGenerationService] Reproducción detenida');
      return result == 1;
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error deteniendo: $e');
      return false;
    }
  }

  /// Pausar reproducción
  Future<bool> pausePlayback() async {
    try {
      final result = await _flutterTts.pause();
      _updateState(AudioPlaybackState.paused);
      AILogger.d('[AudioGenerationService] Reproducción pausada');
      return result == 1;
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error pausando: $e');
      return false;
    }
  }

  // === MÉTODOS PRIVADOS ===

  /// Crea SystemPrompt para síntesis de audio con instrucciones
  AISystemPrompt _createSynthesizeSystemPrompt(
      SynthesizeInstructions? instructions) {
    final effectiveInstructions =
        instructions ?? const SynthesizeInstructions();

    final context = <String, dynamic>{
      'task': 'audio_generation',
      'tts': true,
    };

    return AISystemPrompt(
      context: context,
      dateTime: DateTime.now(),
      instructions: effectiveInstructions.toMap(),
    );
  }

  /// Actualizar estado de reproducción
  void _updateState(AudioPlaybackState newState) {
    _currentState = newState;
    _playbackStateController.add(newState);
    AILogger.d('[AudioGenerationService] Estado: $newState');
  }

  /// Limpiar recursos
  void dispose() {
    _flutterTts.stop();
    _playbackStateController.close();
    AILogger.d('[AudioGenerationService] Recursos liberados');
  }
}

/// Estados de reproducción de audio para SDK
enum AudioPlaybackState {
  idle,
  loading,
  playing,
  paused,
  stopped,
  completed,
  error
}
