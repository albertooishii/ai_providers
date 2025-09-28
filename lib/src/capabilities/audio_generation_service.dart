import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../ai_providers.dart';
import '../core/ai_provider_manager.dart';
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
  // Constructor privado con inicialización
  AudioGenerationService._() {
    _initializeTts();
    _initializeAudioPlayer();
  }
  // Sistema de reproducción REAL usando flutter_tts
  late FlutterTts _flutterTts;
  final StreamController<AudioPlaybackState> _playbackStateController =
      StreamController<AudioPlaybackState>.broadcast();
  AudioPlaybackState _currentState = AudioPlaybackState.idle;

  // AudioPlayer para archivos reales
  AudioPlayer? _audioPlayer;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  // Rastrear qué tipo de reproducción está activa
  bool _isPlayingFile = false;

  // Streams públicos para estado de reproducción
  Stream<AudioPlaybackState> get playbackStateStream =>
      _playbackStateController.stream;
  AudioPlaybackState get playbackState => _currentState;
  bool get isPlaying => _currentState == AudioPlaybackState.playing;

  static final AudioGenerationService _instance = AudioGenerationService._();
  static AudioGenerationService get instance => _instance;

  /// 🎯 MÉTODO SIMPLE - usado por AI.speak()
  ///
  /// Versión simple que siempre guarda en caché para máxima facilidad de uso.
  /// Esta es la firma EXACTA que necesita AI.speak() para evitar circular dependency.
  Future<AIResponse> synthesize(
    final String text, [
    final AiAudioParams? audioParams,
    final bool play = false,
  ]) async {
    try {
      AILogger.d(
          '[AudioGenerationService] 🎤 Sintetizando audio: ${text.substring(0, text.length.clamp(0, 50))}...');

      // Crear SystemPrompt con parámetros de audio
      final systemPrompt = _createSynthesizeSystemPrompt(audioParams);

      // Llamar directamente a AIProviderManager - siempre guarda en caché para máxima flexibilidad
      final response = await AIProviderManager.instance.sendMessage(
        message: text,
        systemPrompt: systemPrompt,
        capability: AICapability.audioGeneration,
        additionalParams: audioParams?.toMap(),
        saveToCache: true,
      );

      // Si play=true, reproducir automáticamente el audio generado
      if (play && response.audioFileName.isNotEmpty) {
        unawaited(playAudioFile(response.audioFileName));
      }

      return response;
    } catch (e) {
      AILogger.e('[AudioGenerationService] ❌ Error sintetizando audio: $e');
      rethrow;
    }
  }

  /// 🎨 MÉTODO AVANZADO - Con control completo de configuración
  ///
  /// Permite control total sobre parámetros de audio, caché y reproducción automática.
  /// Para uso avanzado cuando se necesita control específico.
  Future<AIResponse> synthesizeAdvanced(
    final String text, {
    final AiAudioParams? audioParams,
    final bool saveToCache = true,
    final bool play = false,
  }) async {
    try {
      AILogger.d(
          '[AudioGenerationService] 🎨 Sintetizando audio (avanzado): ${text.substring(0, text.length.clamp(0, 50))}... (saveToCache: $saveToCache, play: $play)');

      // Crear SystemPrompt con parámetros de audio
      final systemPrompt = _createSynthesizeSystemPrompt(audioParams);

      // Llamar directamente a AIProviderManager con control completo
      final response = await AIProviderManager.instance.sendMessage(
        message: text,
        systemPrompt: systemPrompt,
        capability: AICapability.audioGeneration,
        additionalParams: audioParams?.toMap(),
        saveToCache: saveToCache,
      );

      // Si play=true, reproducir automáticamente el audio generado
      if (play && response.audioFileName.isNotEmpty) {
        unawaited(playAudioFile(response.audioFileName));
      }

      return response;
    } catch (e) {
      AILogger.e('[AudioGenerationService] ❌ Error en synthesizeAdvanced: $e');
      rethrow;
    }
  }

  /// Genera audio/TTS simplificado (wrapper para compatibilidad)
  /// DEPRECATED: Usar synthesize() directamente
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

      // Usar synthesize() directamente - más eficiente y sin duplicación
      final response = await synthesize(text);

      return response.audioFileName.isNotEmpty ? response.audioFileName : null;
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

    _flutterTts.setErrorHandler((final msg) {
      _updateState(AudioPlaybackState.error);
      AILogger.e('[AudioGenerationService] Error TTS: $msg');
    });
  }

  /// Sintetizar y reproducir inmediatamente (wrapper para compatibilidad)
  /// DEPRECATED: Usar synthesize(text, audioParams, play: true) directamente
  Future<bool> synthesizeAndPlay(
    final String text, {
    final String? languageCode,
  }) async {
    try {
      AILogger.d(
          '[AudioGenerationService] 🎤🔊 SynthesizeAndPlay: ${text.substring(0, text.length.clamp(0, 50))}...');

      // Crear parámetros básicos si se especifica idioma (compatibilidad)
      final audioParams =
          languageCode != null ? AiAudioParams(language: languageCode) : null;

      // Usar synthesize() con play=true - más eficiente y sin duplicación
      final response = await synthesize(text, audioParams, true);

      return response.audioFileName.isNotEmpty;
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error en synthesizeAndPlay: $e');
      _updateState(AudioPlaybackState.error);
      return false;
    }
  }

  /// Reproducir archivo de audio (archivos reales de providers IA)
  Future<bool> playAudioFile(final String fileName) async {
    try {
      AILogger.d(
          '[AudioGenerationService] 🔊 Reproduciendo archivo: $fileName');

      // Construct full path for audio files
      String fullPath;
      if (fileName.startsWith('/')) {
        // Already a full path
        fullPath = fileName;
      } else {
        // Construct path using MediaPersistenceService - need to get audio directory
        // For now, use the standard temp cache path
        fullPath = '/tmp/ai_providers_cache/audio/$fileName';
      }

      if (!File(fullPath).existsSync()) {
        AILogger.w('[AudioGenerationService] Archivo no existe: $fullPath');
        return false;
      }

      _updateState(AudioPlaybackState.loading);

      // Use AudioPlayer for real file playback
      return await _playWithAudioPlayer(fullPath);
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error reproduciendo archivo: $e');
      _updateState(AudioPlaybackState.error);
      return false;
    }
  }

  /// Detener reproducción
  Future<bool> stopPlayback() async {
    try {
      bool success = true;

      if (_isPlayingFile) {
        // Stop AudioPlayer if playing a file
        if (_audioPlayer != null) {
          await _audioPlayer!.stop();
          AILogger.d('[AudioGenerationService] AudioPlayer detenido');
        }
      } else {
        // Stop TTS if playing via flutter_tts
        final ttsResult = await _flutterTts.stop();
        if (ttsResult != 1) success = false;
      }

      _isPlayingFile = false;
      _updateState(AudioPlaybackState.stopped);
      AILogger.d('[AudioGenerationService] Reproducción detenida');
      return success;
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error deteniendo: $e');
      return false;
    }
  }

  /// Pausar reproducción
  Future<bool> pausePlayback() async {
    try {
      bool success = true;

      if (_isPlayingFile) {
        // Pause AudioPlayer if playing a file
        if (_audioPlayer != null) {
          await _audioPlayer!.pause();
          AILogger.d('[AudioGenerationService] AudioPlayer pausado');
        }
      } else {
        // Pause TTS if playing via flutter_tts
        final result = await _flutterTts.pause();
        success = result == 1;
      }

      _updateState(AudioPlaybackState.paused);
      AILogger.d('[AudioGenerationService] Reproducción pausada');
      return success;
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error pausando: $e');
      return false;
    }
  }

  // === MÉTODOS PRIVADOS ===

  /// Crea SystemPrompt para síntesis de audio con parámetros tipados
  AISystemPrompt _createSynthesizeSystemPrompt(
      final AiAudioParams? audioParams) {
    final effectiveParams = audioParams ?? const AiAudioParams();

    final context = <String, dynamic>{
      'task': 'audio_generation',
      'tts': true,
    };

    // Combinar contexto con parámetros de audio para máxima información
    final instructions = <String, dynamic>{
      ...context,
      ...effectiveParams.toMap(),
    };

    return AISystemPrompt(
      context: context,
      dateTime: DateTime.now(),
      instructions: instructions,
    );
  }

  /// Actualizar estado de reproducción
  void _updateState(final AudioPlaybackState newState) {
    _currentState = newState;
    _playbackStateController.add(newState);
    AILogger.d('[AudioGenerationService] Estado: $newState');
  }

  /// Inicializar AudioPlayer
  void _initializeAudioPlayer() {
    try {
      _audioPlayer = AudioPlayer();
      _setupAudioPlayerHandlers();
      AILogger.i(
          '[AudioGenerationService] ✅ AudioPlayer inicializado correctamente');
    } on Exception catch (e) {
      AILogger.w(
          '[AudioGenerationService] ⚠️  Error inicializando AudioPlayer: $e');
    }
  }

  /// Configurar handlers de AudioPlayer
  void _setupAudioPlayerHandlers() {
    if (_audioPlayer == null) return;

    _playerStateSubscription =
        _audioPlayer!.onPlayerStateChanged.listen((final PlayerState state) {
      switch (state) {
        case PlayerState.playing:
          _updateState(AudioPlaybackState.playing);
          break;
        case PlayerState.paused:
          _updateState(AudioPlaybackState.paused);
          break;
        case PlayerState.stopped:
          _isPlayingFile = false;
          _updateState(AudioPlaybackState.stopped);
          break;
        case PlayerState.completed:
          _isPlayingFile = false;
          _updateState(AudioPlaybackState.completed);
          break;
        case PlayerState.disposed:
          _isPlayingFile = false;
          _updateState(AudioPlaybackState.idle);
          break;
      }
    });
  }

  /// Reproducir con AudioPlayer real
  Future<bool> _playWithAudioPlayer(final String fullPath) async {
    try {
      if (_audioPlayer == null) {
        _initializeAudioPlayer();
      }

      if (_audioPlayer == null) {
        AILogger.e('[AudioGenerationService] AudioPlayer no disponible');
        return false;
      }

      _updateState(AudioPlaybackState.loading);

      // Mark that we're playing a file (not TTS)
      _isPlayingFile = true;

      // Play the audio file
      await _audioPlayer!.play(DeviceFileSource(fullPath));

      AILogger.i(
          '[AudioGenerationService] 🎵 Reproduciendo con AudioPlayer: $fullPath');
      return true;
    } on Exception catch (e) {
      AILogger.e('[AudioGenerationService] Error con AudioPlayer: $e');
      _updateState(AudioPlaybackState.error);
      return false;
    }
  }

  /// Limpiar recursos
  void dispose() {
    _flutterTts.stop();
    _playerStateSubscription?.cancel();
    _audioPlayer?.dispose();
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
