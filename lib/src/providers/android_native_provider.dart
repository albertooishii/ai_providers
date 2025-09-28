import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../core/provider_registry.dart';

// provider_interface.dart removed - no more abstract interfaces!
import '../models/ai_provider_metadata.dart';
import '../models/provider_response.dart';
import '../models/ai_capability.dart';
import '../models/ai_system_prompt.dart';
import '../models/audio_models.dart';
import '../models/ai_audio_params.dart';
// RealtimeClient removed - replaced by HybridConversationService
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Provider nativo de Android usando flutter_tts y speech_to_text directamente
/// Sin dependencias de archivos viejos - implementación limpia desde cero
class AndroidNativeProvider {
  AndroidNativeProvider() {
    _flutterTts = FlutterTts();
    _speechToText = SpeechToText();
  }
  static const String _providerId = 'android_native';
  static const String _providerName = 'Android Native TTS/STT';
  static const String _version = '1.0.0';

  late final FlutterTts _flutterTts;
  late final SpeechToText _speechToText;
  bool _initialized = false;

  /// Register this provider with the registry
  static void register() {
    final registry = ProviderRegistry.instance;
    registry.registerConstructor(
      _providerId,
      (final config) => AndroidNativeProvider(),
      modelPrefixes: ['android_native'],
    );
  }

  String get providerId => _providerId;

  String get providerName => _providerName;

  String get version => _version;

  AIProviderMetadata get metadata => const AIProviderMetadata(
        providerId: _providerId,
        providerName: _providerName,
        company: 'Android System',
        version: _version,
        description:
            'Síntesis y reconocimiento de voz nativo de Android usando flutter_tts y speech_to_text',
        supportedCapabilities: [
          AICapability.audioGeneration,
          AICapability.audioTranscription
        ],
        defaultModels: {
          AICapability.audioGeneration: 'android_native_tts',
          AICapability.audioTranscription: 'android_native_stt',
        },
        availableModels: {
          AICapability.audioGeneration: ['android_native_tts'],
          AICapability.audioTranscription: ['android_native_stt'],
        },
        rateLimits: {'requests_per_minute': 1000}, // Sin límites reales
        requiresAuthentication: false,
        requiredConfigKeys: [],
        supportsStreaming: false,
        supportsFunctionCalling: false,
      );

  List<AICapability> get supportedCapabilities =>
      [AICapability.audioGeneration, AICapability.audioTranscription];

  Map<AICapability, List<String>> get availableModels => {
        AICapability.audioGeneration: ['android_native_tts'],
        AICapability.audioTranscription: ['android_native_stt'],
      };

  Future<bool> initialize(final Map<String, dynamic> config) async {
    if (_initialized) return true;

    try {
      if (!Platform.isAndroid) {
        return false; // Solo funciona en Android
      }

      // Configurar TTS básico
      await _flutterTts.setLanguage('es-ES');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);

      // Inicializar STT
      final sttAvailable = await _speechToText.initialize(
        onError: (final val) {
          // Log en modo debug solamente
          if (Platform.isAndroid) {
            debugPrint('AndroidNativeProvider STT Error: $val');
          }
        },
        onStatus: (final val) {
          // Log en modo debug solamente
          if (Platform.isAndroid) {
            debugPrint('AndroidNativeProvider STT Status: $val');
          }
        },
      );

      _initialized = sttAvailable;
      return _initialized;
    } on Exception catch (_) {
      _initialized = false;
      return false;
    }
  }

  Future<bool> isHealthy() async {
    if (!Platform.isAndroid) return false;

    try {
      // Verificar que flutter_tts funciona
      final languages = await _flutterTts.getLanguages;
      final ttsOk = languages != null && languages.isNotEmpty;

      // Verificar que speech_to_text funciona
      final sttOk = _speechToText.isAvailable;

      return ttsOk && sttOk;
    } on Exception catch (_) {
      return false;
    }
  }

  bool supportsCapability(final AICapability capability) {
    return capability == AICapability.audioGeneration ||
        capability == AICapability.audioTranscription;
  }

  bool supportsModel(final AICapability capability, final String model) {
    if (capability == AICapability.audioGeneration) {
      return model == 'android_native_tts';
    }
    if (capability == AICapability.audioTranscription) {
      return model == 'android_native_stt';
    }
    return false;
  }

  String? getDefaultModel(final AICapability capability) {
    if (capability == AICapability.audioGeneration) {
      return 'android_native_tts';
    }
    if (capability == AICapability.audioTranscription) {
      return 'android_native_stt';
    }
    return null;
  }

  Future<ProviderResponse> sendMessage({
    required final List<Map<String, String>> history,
    required final AISystemPrompt systemPrompt,
    required final AICapability capability,
    final String? model,
    final String? imageBase64,
    final String? imageMimeType,
    final Map<String, dynamic>? additionalParams,
  }) async {
    throw UnsupportedError(
        'AndroidNativeProvider no soporta sendMessage - solo generateAudio');
  }

  Future<List<String>> getAvailableModelsForCapability(
      final AICapability capability) async {
    if (capability == AICapability.audioGeneration) {
      return ['android_native_tts'];
    }
    if (capability == AICapability.audioTranscription) {
      return ['android_native_stt'];
    }
    return [];
  }

  Map<String, int> getRateLimits() => {'requests_per_minute': 1000};

  Future<ProviderResponse> generateAudio({
    required final String text,
    final String? voice,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  }) async {
    if (!_initialized) {
      throw StateError('AndroidNativeProvider no inicializado');
    }

    if (!Platform.isAndroid) {
      throw UnsupportedError('AndroidNativeProvider solo funciona en Android');
    }

    try {
      // Crear AiAudioParams desde additionalParams para usar parámetros tipados
      final audioParams = AiAudioParams.fromMap(additionalParams);

      // Configurar idioma si se especifica (filtrado ISO para Android Native)
      if (audioParams.language != null) {
        await _flutterTts.setLanguage(audioParams.language!);
      }

      // Configurar voz si se especifica
      if (voice != null) {
        final locale = audioParams.language ?? 'es-ES';
        await _flutterTts.setVoice({'name': voice, 'locale': locale});
      }

      // Configurar velocidad usando parámetros tipados
      await _flutterTts.setSpeechRate(audioParams.speed);

      // Nota: Android Native no soporta accent, emotion, temperature, audioFormat
      // Solo usa language (ISO) y speed como documentado en AiAudioParams

      // Crear archivo temporal
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/android_tts_${DateTime.now().millisecondsSinceEpoch}.wav');

      // Sintetizar a archivo
      await _flutterTts.awaitSynthCompletion(true);
      final result = await _flutterTts.synthesizeToFile(
        text,
        tempFile.path,
      );

      if (result == 1 && tempFile.existsSync()) {
        // Leer el archivo y convertir a base64
        final audioBytes = await tempFile.readAsBytes();
        final audioBase64 = base64Encode(audioBytes);

        // Limpiar archivo temporal
        try {
          await tempFile.delete();
        } on Exception catch (_) {}

        return ProviderResponse(
          text: 'Audio generado con TTS nativo de Android',
          audioBase64: audioBase64,
          prompt: text,
        );
      } else {
        throw Exception('Error al sintetizar audio con flutter_tts');
      }
    } catch (e) {
      throw Exception('Error en AndroidNativeProvider.generateAudio: $e');
    }
  }

  Future<ProviderResponse> transcribeAudio({
    required final String audioBase64,
    final String? audioFormat,
    final String? model,
    final String? language,
    final Map<String, dynamic>? additionalParams,
  }) async {
    if (!_initialized) {
      throw StateError('AndroidNativeProvider no inicializado');
    }

    if (!Platform.isAndroid) {
      throw UnsupportedError('AndroidNativeProvider solo funciona en Android');
    }

    try {
      // Nota: speech_to_text normalmente funciona con audio en vivo
      // Para transcribir audio pre-grabado desde base64, necesitaríamos
      // reproducir el audio y capturarlo, lo cual es más complejo.
      // Por ahora implementamos un enfoque básico usando el micrófono.

      final completer = Completer<String>();
      var recognizedText = '';

      // Configurar idioma
      final locale = language ?? 'es-ES';

      // Iniciar escucha
      final available = await _speechToText.listen(
        onResult: (final result) {
          recognizedText = result.recognizedWords;
          if (result.finalResult) {
            completer.complete(recognizedText);
          }
        },
        listenFor: const Duration(seconds: 10), // Timeout de 10 segundos
        pauseFor:
            const Duration(seconds: 3), // Pausa después de 3 segundos sin habla
        listenOptions: SpeechListenOptions(partialResults: false),
        localeId: locale,
      );

      if (!available) {
        throw Exception('Speech-to-text no disponible');
      }

      // Esperar resultado o timeout
      try {
        final result = await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            _speechToText.stop();
            return recognizedText.isEmpty
                ? 'No se detectó habla'
                : recognizedText;
          },
        );

        return ProviderResponse(
            text: result,
            prompt: 'Transcripción de audio con STT nativo de Android');
      } finally {
        await _speechToText.stop();
      }
    } catch (e) {
      throw Exception('Error en AndroidNativeProvider.transcribeAudio: $e');
    }
  }

  /// [REMOVED] createRealtimeClient - Replaced by HybridConversationService
  /// Use HybridConversationService for real-time conversation features

  bool supportsRealtimeForModel(final String? model) => false;

  List<String> getAvailableRealtimeModels() => [];

  bool get supportsRealtime => false;

  String? get defaultRealtimeModel => null;

  // Voice management for Android TTS
  Future<List<VoiceInfo>> getAvailableVoices() async {
    try {
      if (!_initialized) await initialize({});

      // Get available voices from Flutter TTS
      final voices = await _flutterTts.getVoices;
      if (voices == null) return [];

      return (voices as List).map((final voice) {
        final voiceMap = voice as Map<String, dynamic>;
        return VoiceInfo(
          id: voiceMap['name'] ?? 'unknown',
          name: voiceMap['name'] ?? 'Unknown Voice',
          language: voiceMap['locale'] ?? 'es-ES',
          gender: _parseGender(voiceMap['name']),
        );
      }).toList();
    } on Exception {
      return [
        // Default fallback voice
        const VoiceInfo(
          id: 'es-ES-default',
          name: 'Spanish Default',
          gender: VoiceGender.neutral,
          isDefault: true,
        ),
      ];
    }
  }

  VoiceGender _parseGender(final String? voiceName) {
    if (voiceName == null) return VoiceGender.neutral;
    final name = voiceName.toLowerCase();
    if (name.contains('female') ||
        name.contains('woman') ||
        name.contains('maria')) {
      return VoiceGender.female;
    } else if (name.contains('male') ||
        name.contains('man') ||
        name.contains('juan')) {
      return VoiceGender.male;
    }
    return VoiceGender.neutral;
  }

  VoiceGender getVoiceGender(final String voiceName) => _parseGender(voiceName);

  List<String> getVoiceNames() => ['es-ES-default'];

  bool isValidVoice(final String voiceName) => true;

  Future<void> dispose() async {
    _initialized = false;

    // Detener STT si está escuchando
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    // flutter_tts no necesita dispose manual
  }
}
