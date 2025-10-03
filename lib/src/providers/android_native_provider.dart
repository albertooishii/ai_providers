import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:path_provider/path_provider.dart';

import '../core/provider_registry.dart';
import '../models/additional_params.dart';
import '../models/ai_provider_metadata.dart';
import '../models/provider_response.dart';
import '../models/ai_capability.dart';
import '../models/ai_system_prompt.dart';
import '../models/audio_models.dart';
import '../models/ai_audio_params.dart';
import '../core/base_provider.dart';
import '../utils/logger.dart';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Android Native Provider - Complete rewrite with BaseProvider extension

/// Uses flutter_tts and speech_to_text for native Android TTS/STT capabilities
class AndroidNativeProvider extends BaseProvider {
  AndroidNativeProvider(super.config) {
    _flutterTts = FlutterTts();
    _speechToText = SpeechToText();
  }

  late final FlutterTts _flutterTts;
  late final SpeechToText _speechToText;
  bool _initialized = false;

  static void register() {
    ProviderRegistry.instance.registerConstructor(
        'android_native', (final config) => AndroidNativeProvider(config));
  }

  @override
  String get providerId => 'android_native';

  @override
  AIProviderMetadata createMetadata() {
    return AIProviderMetadata(
      providerId: providerId,
      providerName: config.displayName,
      company: 'Android System',
      version: '1.0.0',
      description: config.description,
      supportedCapabilities: config.capabilities,
      defaultModels: config.defaults,
      availableModels: config.models,
      rateLimits: {
        'requests_per_minute': config.rateLimits.requestsPerMinute,
        'tokens_per_minute': config.rateLimits.tokensPerMinute,
      },
      requiresAuthentication: false,
      requiredConfigKeys: [],
      maxContextTokens: config.configuration.maxContextTokens,
      maxOutputTokens: config.configuration.maxOutputTokens,
      supportsStreaming: false,
      supportsFunctionCalling: false,
    );
  }

  @override
  Map<String, String> buildAuthHeaders() {
    // Android Native no requiere autenticación
    return {'Content-Type': 'application/json'};
  }

  @override
  Future<List<String>?> fetchModelsFromAPI() async {
    // Use flutter_tts getEngines to get actual TTS engines (voice models)
    final models = <String>[];

    try {
      if (!_initialized) {
        await initialize();
      }

      if (_initialized && supportsCapability(AICapability.audioGeneration)) {
        // Get available TTS engines from Android system
        final engines = await _flutterTts.getEngines;
        AILogger.d('[AndroidNativeProvider] Available TTS engines: $engines');

        if (engines != null && engines.isNotEmpty) {
          // Add each engine as a model with prefix for clarity
          for (final engine in engines) {
            final engineName = engine.toString();
            models.add('tts_engine_$engineName');
            AILogger.d(
                '[AndroidNativeProvider] Added TTS engine model: tts_engine_$engineName');
          }
        } else {
          // Fallback to default if no engines found
          models.add('android_native_tts_default');
          AILogger.w(
              '[AndroidNativeProvider] No TTS engines found, using default model');
        }
      }

      if (supportsCapability(AICapability.audioTranscription)) {
        models.add('android_native_stt');
      }

      AILogger.d(
          '[AndroidNativeProvider] Total available models: ${models.length}');
      return models;
    } on Exception catch (e) {
      AILogger.e('[AndroidNativeProvider] Error fetching engines: $e');
      // Fallback to basic models on error
      if (supportsCapability(AICapability.audioGeneration)) {
        models.add('android_native_tts_fallback');
      }
      if (supportsCapability(AICapability.audioTranscription)) {
        models.add('android_native_stt');
      }
      return models;
    }
  }

  @override
  int compareModels(final String a, final String b) {
    // Orden simple: TTS primero, luego STT
    if (a.contains('tts') && !b.contains('tts')) return -1;
    if (!a.contains('tts') && b.contains('tts')) return 1;
    return a.compareTo(b);
  }

  @override
  ({
    List<Map<String, dynamic>> history,
    AISystemPrompt systemPromptWithoutHistory
  }) processHistory(final AISystemPrompt systemPrompt) {
    // Android Native es simple, no necesita procesamiento complejo de history
    return (
      history: systemPrompt.history ?? [],
      systemPromptWithoutHistory: systemPrompt,
    );
  }

  @override
  Future<bool> initialize([final Map<String, dynamic>? config]) async {
    if (_initialized) return true;

    try {
      if (!Platform.isAndroid) {
        AILogger.w(
            '[AndroidNativeProvider] Only available on Android platform');
        return false;
      }

      // Configurar TTS básico
      await _flutterTts.setLanguage('es-ES');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);

      // Inicializar STT
      final sttAvailable = await _speechToText.initialize(
        onError: (final val) {
          AILogger.d('[AndroidNativeProvider] STT Error: $val');
        },
        onStatus: (final val) {
          AILogger.d('[AndroidNativeProvider] STT Status: $val');
        },
      );

      _initialized = sttAvailable;
      AILogger.d(
          '[AndroidNativeProvider] Initialization complete: $_initialized');
      return _initialized;
    } on Exception catch (e) {
      AILogger.e('[AndroidNativeProvider] Initialization failed: $e');
      _initialized = false;
      return false;
    }
  }

  @override
  Future<ProviderResponse> sendMessage({
    required final AISystemPrompt systemPrompt,
    required final AICapability capability,
    final String? model,
    final String? imageBase64,
    final String? imageMimeType,
    final AdditionalParams? additionalParams,
    final String? voice,
  }) async {
    switch (capability) {
      case AICapability.audioGeneration:
        return _sendTTSRequest(systemPrompt, model, additionalParams, voice);
      case AICapability.audioTranscription:
        return _sendSTTRequest(imageBase64 ?? '', systemPrompt, model);
      default:
        return ProviderResponse(
          text:
              'AndroidNativeProvider only supports audio generation and transcription',
        );
    }
  }

  Future<ProviderResponse> _sendTTSRequest(
    final AISystemPrompt systemPrompt,
    final String? model,
    final AdditionalParams? additionalParams,
    final String? voice,
  ) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) {
        return ProviderResponse(
          text: 'AndroidNativeProvider not initialized',
        );
      }
    }

    final history = systemPrompt.history ?? [];
    final text = history.isNotEmpty ? history.last['content'] ?? '' : '';
    if (text.isEmpty) {
      return ProviderResponse(text: 'Error: No text provided for TTS.');
    }

    try {
      final audioParams =
          additionalParams?.audioParams ?? const AiAudioParams();

      // Configurar motor TTS si se especifica en el modelo
      if (model != null && model.startsWith('tts_engine_')) {
        final engineName = model.substring('tts_engine_'.length);
        AILogger.d('[AndroidNativeProvider] Setting TTS engine: $engineName');
        try {
          await _flutterTts.setEngine(engineName);
          AILogger.d(
              '[AndroidNativeProvider] Successfully set TTS engine: $engineName');
        } on Exception catch (e) {
          AILogger.w(
              '[AndroidNativeProvider] Failed to set TTS engine $engineName: $e');
          // Continue with default engine
        }
      }

      // Configurar idioma si se especifica
      if (audioParams.language != null) {
        await _flutterTts.setLanguage(audioParams.language!);
        AILogger.d(
            '[AndroidNativeProvider] Set language: ${audioParams.language}');
      }

      // Configurar voz si se especifica
      if (voice != null) {
        final locale = audioParams.language ?? 'es-ES';

        // Verificar si la voz está disponible
        AILogger.d(
            '[AndroidNativeProvider] Checking available voices for: $voice');
        final availableVoices = await _flutterTts.getVoices;
        AILogger.d(
            '[AndroidNativeProvider] Available voices count: ${availableVoices?.length ?? 0}');

        if (availableVoices != null && availableVoices.isNotEmpty) {
          AILogger.d(
              '[AndroidNativeProvider] Searching for voice: $voice in ${availableVoices.length} available voices');

          // Buscar la voz específica SIN FILTROS - usar exactamente la voz seleccionada
          final voiceExists =
              availableVoices.any((final v) => v['name'] == voice);

          AILogger.d(
              '[AndroidNativeProvider] Voice $voice exists (exact match): $voiceExists');

          if (voiceExists) {
            // Usar la voz encontrada sin filtros - exactamente la que se seleccionó
            final selectedVoice =
                availableVoices.firstWhere((final v) => v['name'] == voice);
            final realLocale = selectedVoice['locale']?.toString() ?? locale;

            // Configurar la voz específica seleccionada
            final voiceMap = <String, String>{
              'name': voice,
              'locale': realLocale
            };
            await _flutterTts.setVoice(voiceMap);
            AILogger.d(
                '[AndroidNativeProvider] Set exact voice: $voice ($realLocale)');
          } else {
            AILogger.w(
                '[AndroidNativeProvider] Voice $voice not found in available voices');
            AILogger.w(
                '[AndroidNativeProvider] Using system default voice with configured language');
          }
        } else {
          AILogger.w(
              '[AndroidNativeProvider] No available voices found, using system default');
          await _flutterTts.setVoice({'name': voice, 'locale': locale});
        }
      }

      // Configurar parámetros de audio - velocidad fija 0.7 que se oye bien
      AILogger.d(
          '[AndroidNativeProvider] Using fixed speed: 0.7 (input: ${audioParams.speed})');
      await _flutterTts.setSpeechRate(audioParams.speed * 0.7);
      await _flutterTts.setVolume(1.0); // Máximo volumen
      await _flutterTts.setPitch(1.0); // Tono normal

      // Android: Configurar para navegación (mejor calidad)
      try {
        await _flutterTts.setQueueMode(0); // Modo inmediato
        await _flutterTts.setAudioAttributesForNavigation();
      } on Exception catch (e) {
        AILogger.d(
            '[AndroidNativeProvider] Audio attributes not available: $e');
      }

      AILogger.d(
          '[AndroidNativeProvider] Audio config - Speed: 0.7 (fixed), Volume: 1.0, Pitch: 1.0');

      // Crear archivo temporal para síntesis (necesario para obtener el audio como base64)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/android_tts_$timestamp.wav');

      await _flutterTts.awaitSynthCompletion(true);
      // Usar isFullPath = true para que Android use nuestra ruta completa
      final result =
          await _flutterTts.synthesizeToFile(text, tempFile.path, true);

      AILogger.d('[AndroidNativeProvider] synthesizeToFile result: $result');

      if (result == 1) {
        // Esperar a que se complete la síntesis
        await Future.delayed(const Duration(milliseconds: 2000));

        // Leer directamente del archivo temporal
        try {
          if (tempFile.existsSync()) {
            AILogger.d(
                '[AndroidNativeProvider] Reading TTS file: ${tempFile.path}');
            final bytes = await tempFile.readAsBytes();
            final audioBase64 = base64Encode(bytes);

            // Limpiar el archivo temporal
            try {
              await tempFile.delete();
            } on Exception catch (e) {
              AILogger.w(
                  '[AndroidNativeProvider] Could not delete temp file: $e');
            }

            AILogger.d('[AndroidNativeProvider] TTS synthesis successful');
            AILogger.d(
                '[AndroidNativeProvider] Base64 encoded: ${audioBase64.length} chars');

            return ProviderResponse(
              text: 'Audio generated with Android native TTS',
              audioBase64: audioBase64,
            );
          } else {
            AILogger.w(
                '[AndroidNativeProvider] TTS file does not exist: ${tempFile.path}');
            throw Exception('TTS file does not exist');
          }
        } on Exception catch (e) {
          AILogger.e('[AndroidNativeProvider] Error reading TTS file: $e');
          throw Exception('Error reading TTS file: $e');
        }
      } else {
        AILogger.e(
            '[AndroidNativeProvider] TTS synthesis failed with result: $result');
        AILogger.e(
            '[AndroidNativeProvider] This usually means the voice was not found or TTS engine error');
        throw Exception(
            'TTS synthesis failed: result=$result (voice may not be available)');
      }
    } on Exception catch (e) {
      AILogger.e('[AndroidNativeProvider] TTS request failed: $e');
      return ProviderResponse(text: 'Error generating audio: $e');
    }
  }

  Future<ProviderResponse> _sendSTTRequest(
    final String audioBase64,
    final AISystemPrompt systemPrompt,
    final String? model,
  ) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) {
        return ProviderResponse(
          text: 'AndroidNativeProvider not initialized',
        );
      }
    }

    // NOTA IMPORTANTE: speech_to_text NO soporta archivos de audio pre-grabados
    // Solo funciona con micrófono en tiempo real.
    // Si recibimos audioBase64 (archivo pre-grabado), debemos fallar para que use otro provider

    if (audioBase64.isNotEmpty) {
      AILogger.d(
          '[AndroidNativeProvider] 🚫 Pre-recorded audio detected - android_native STT only works with real-time microphone');
      AILogger.d(
          '[AndroidNativeProvider] 💡 Failing gracefully to allow fallback to Google/OpenAI STT for file transcription');

      // Retornar error específico para que el sistema use otro provider
      throw UnsupportedError(
          'AndroidNativeProvider STT only supports real-time microphone transcription, not pre-recorded audio files. Use Google or OpenAI providers for file transcription.');
    }

    AILogger.d(
        '[AndroidNativeProvider] 🎤 Android Native STT: Real-time microphone transcription mode');
    AILogger.d(
        '[AndroidNativeProvider] 📝 Note: This only works during live recording, not with pre-recorded files');

    try {
      // Verificar disponibilidad del STT nativo
      if (!_speechToText.isAvailable) {
        AILogger.w(
            '[AndroidNativeProvider] Speech recognition not initialized or unavailable');
        return ProviderResponse(
          text:
              'Speech recognition service not available on this device. Please ensure microphone permissions are granted and Google Speech services are enabled.',
        );
      }

      final completer = Completer<String>();
      var recognizedText = '';
      var hasCompleted = false;

      // Configurar idioma (extraer de systemPrompt si está disponible)
      final contextJson = systemPrompt.toJson();
      final locale = _extractLanguageFromContext(contextJson) ?? 'es-ES';

      AILogger.d(
          '[AndroidNativeProvider] 🎙️ Starting real-time STT with locale: $locale');

      // Configurar callbacks para manejo de estados
      void onStatus(final String status) {
        AILogger.d('[AndroidNativeProvider] STT Status: $status');
      }

      void onError(final dynamic error) {
        AILogger.e('[AndroidNativeProvider] STT Error: $error');
        // Solo completar con error si realmente no hay texto reconocido
        if (!hasCompleted && recognizedText.isEmpty) {
          hasCompleted = true;
          completer.complete('Speech recognition error: ${error.toString()}');
        } else if (!hasCompleted && recognizedText.isNotEmpty) {
          // Si hay texto reconocido pero hubo error, usar el texto disponible
          AILogger.d(
              '[AndroidNativeProvider] Error occurred but using recognized text: "$recognizedText"');
          hasCompleted = true;
          completer.complete(recognizedText);
        }
      }

      // Inicializar STT con callbacks actualizados
      await _speechToText.initialize(
        onStatus: onStatus,
        onError: onError,
      );

      // Verificar disponibilidad después de inicialización
      if (!_speechToText.isAvailable) {
        return ProviderResponse(
          text:
              'Speech recognition not available. Please check microphone permissions and device speech services.',
        );
      }

      // Iniciar escucha en tiempo real
      final available = await _speechToText.listen(
        onResult: (final result) {
          recognizedText = result.recognizedWords;
          AILogger.d(
              '[AndroidNativeProvider] STT partial result: "$recognizedText" (final: ${result.finalResult})');

          // Completar cuando tengamos resultado final
          if (result.finalResult && !hasCompleted) {
            hasCompleted = true;
            completer.complete(recognizedText.isNotEmpty
                ? recognizedText
                : 'No speech detected');
          }
        },
        listenFor: const Duration(seconds: 8), // Tiempo reducido para mejor UX
        pauseFor: const Duration(seconds: 2), // Pausa más corta
        listenOptions: SpeechListenOptions(
          enableHapticFeedback: true,
          autoPunctuation: true,
        ),
        localeId: locale,
      );

      // Verificar si el listening se inició correctamente
      if (available != true) {
        AILogger.w(
            '[AndroidNativeProvider] Initial start failed, but continuing - STT may still work');
      } else {
        AILogger.d(
            '[AndroidNativeProvider] 🎤 Listening started successfully - speak now...');
      }

      // Dar tiempo al STT para estabilizarse si hubo problema inicial
      if (available != true) {
        await Future.delayed(const Duration(milliseconds: 500));
        AILogger.d(
            '[AndroidNativeProvider] 🎤 Continuing with STT despite initial warning...');
      }

      // Esperar resultado con timeout apropiado
      try {
        final result = await completer.future.timeout(
          const Duration(seconds: 12), // Timeout total más generoso
          onTimeout: () {
            AILogger.w('[AndroidNativeProvider] STT timeout reached');
            if (_speechToText.isListening) {
              _speechToText.stop();
            }
            return recognizedText.isNotEmpty
                ? recognizedText
                : 'No speech detected within timeout period';
          },
        );

        AILogger.d('[AndroidNativeProvider] ✅ STT final result: "$result"');
        return ProviderResponse(text: result);
      } finally {
        // Asegurar que el listening se detenga
        if (_speechToText.isListening) {
          await _speechToText.stop();
        }
      }
    } on Exception catch (e) {
      AILogger.e('[AndroidNativeProvider] STT request failed: $e');
      return ProviderResponse(
        text: 'Speech recognition error: ${e.toString()}',
      );
    }
  }

  String? _extractLanguageFromContext(final Map<String, dynamic> contextJson) {
    // Intentar extraer idioma del contexto
    try {
      final contextData = contextJson['context'];
      if (contextData is Map<String, dynamic>) {
        final language = contextData['language'] ?? contextData['locale'];
        return language?.toString();
      }
    } on Exception catch (e) {
      AILogger.d(
          '[AndroidNativeProvider] Could not extract language from context: $e');
    }
    return null;
  }

  Future<ProviderResponse> transcribeAudio({
    required final String audioBase64,
    final String? model,
    final AISystemPrompt? systemPrompt,
  }) async {
    final effectiveContext = systemPrompt ??
        AISystemPrompt(
          context: {'task': 'audio_transcription'},
          dateTime: DateTime.now(),
          instructions: {},
        );
    return _sendSTTRequest(audioBase64, effectiveContext, model);
  }

  // Voice management for Android TTS - Spanish voices only
  static final List<VoiceInfo> _defaultVoices = [
    const VoiceInfo(
      id: 'es-ES-default',
      name: 'Español (España)',
      gender: VoiceGender.neutral,
      description: 'Voz española por defecto de Android',
    ),
    const VoiceInfo(
      id: 'es-MX-default',
      name: 'Español (México)',
      gender: VoiceGender.neutral,
      language: 'es-MX',
      description: 'Voz mexicana por defecto de Android',
    ),
    const VoiceInfo(
      id: 'es-AR-default',
      name: 'Español (Argentina)',
      gender: VoiceGender.neutral,
      language: 'es-AR',
      description: 'Voz argentina por defecto de Android',
    ),
  ];

  Future<List<VoiceInfo>> getAvailableVoices() async {
    AILogger.d('[AndroidNativeProvider] getAvailableVoices() called');
    try {
      if (!_initialized) {
        AILogger.d('[AndroidNativeProvider] Not initialized, initializing...');
        await initialize();
      }
      if (!_initialized) {
        AILogger.w(
            '[AndroidNativeProvider] Failed to initialize, returning default voices');
        return _defaultVoices;
      }

      // Get available voices from Flutter TTS
      AILogger.d('[AndroidNativeProvider] Getting voices from flutter_tts...');
      final voices = await _flutterTts.getVoices;
      AILogger.d(
          '[AndroidNativeProvider] Raw voices from flutter_tts: $voices');

      if (voices == null) {
        AILogger.w(
            '[AndroidNativeProvider] No voices returned from flutter_tts, using defaults');
        return _defaultVoices;
      }

      final voiceList = <VoiceInfo>[];
      for (final voice in voices) {
        try {
          // Convert Map<Object?, Object?> to Map<String, dynamic>
          final voiceMap = Map<String, dynamic>.from(voice as Map);
          final voiceName = voiceMap['name']?.toString();
          final voiceLocale = voiceMap['locale']?.toString();

          if (voiceName != null && voiceLocale != null) {
            // Filter for high-quality voices (network, wavenet, neural2, etc.) - all languages
            final isNetworkVoice = voice['network_required'] == true ||
                voiceName.contains('network');
            final isWaveNetVoice = voiceName.contains('wavenet') ||
                voiceName.contains('neural2') ||
                voiceName.contains('standard');
            final isHighQualityVoice = isNetworkVoice || isWaveNetVoice;

            // Incluir solo voces de alta calidad en español para la UI
            if (isHighQualityVoice &&
                _matchesLanguage(voiceName, voiceLocale, 'es')) {
              final voiceInfo = VoiceInfo(
                id: voiceName,
                name: voiceName,
                language: voiceLocale,
                gender: _parseGender(voiceName),
                description: 'Android native high-quality voice: $voiceName',
              );
              voiceList.add(voiceInfo);
            }
          } else {
            AILogger.w(
                '[AndroidNativeProvider] Skipping invalid voice: $voice');
          }
        } on Exception catch (e) {
          AILogger.w(
              '[AndroidNativeProvider] Error processing voice $voice: $e');
        }
      }

      AILogger.d(
          '[AndroidNativeProvider] Found ${voiceList.length} high-quality Spanish voices for UI');

      // Voice export functionality available via exportAllVoicesData() method if needed
      // Auto-export disabled for production use

      return voiceList.isNotEmpty ? voiceList : [];
    } on Exception catch (e) {
      AILogger.w('[AndroidNativeProvider] Could not get voices: $e');
      return _defaultVoices;
    }
  }

  /// Helper method to detect if a voice is Spanish
  bool _isSpanishVoice(final String voiceName, final String voiceLocale) {
    final locale = voiceLocale.toLowerCase();
    final name = voiceName.toLowerCase();

    return locale.startsWith('es') ||
        locale.contains('es-') ||
        locale.contains('es_') ||
        locale == 'es' ||
        locale.contains('spanish') ||
        name.contains('spanish') ||
        name.contains('español') ||
        name.contains('espanol') ||
        name.contains('spa-') ||
        name.contains('castellano');
  }

  /// Helper para determinar si una voz coincide con el idioma solicitado
  bool _matchesLanguage(final String voiceName, final String voiceLocale,
      final String? targetLanguage) {
    // Si no se especifica idioma, usar 'es' por defecto
    final effectiveLanguage = targetLanguage ?? 'es';

    final lowerName = voiceName.toLowerCase();
    final lowerLocale = voiceLocale.toLowerCase();
    final lowerTarget = effectiveLanguage.toLowerCase();

    // Debug: Log de matching para debugging (solo para primeras 5 voces para no saturar logs)
    // AILogger.d(
    //     '[AndroidNativeProvider] 🔍 Checking voice: $voiceName (locale: $voiceLocale) against target: $effectiveLanguage');

    // Coincidencia exacta por locale (ej: es-ES, en-US)
    if (lowerLocale == lowerTarget) return true;

    // Coincidencia por código de idioma base (ej: 'es' coincide con 'es-ES')
    if (lowerLocale.startsWith('$lowerTarget-')) return true;
    if (lowerTarget.length == 2 && lowerLocale.startsWith(lowerTarget)) {
      return true;
    }

    // Coincidencia por nombre de voz que contenga el código de idioma
    if (lowerName.contains(lowerTarget)) return true;

    return false;
  }

  VoiceGender _parseGender(final String? voiceName) {
    if (voiceName == null) return VoiceGender.neutral;
    final name = voiceName.toLowerCase();

    // Códigos específicos de Android TTS/Google TTS para español
    // Basado en pruebas reales de audio y feedback del usuario

    // Códigos femeninos conocidos (confirmado por pruebas reales de sonido)
    if (name.contains('-sfb-') || // Spanish Female B
        name.contains('-sfd-') || // Spanish Female D
        name.contains('-esc-') || // Spanish Female C
        name.contains('-esd-') || // Spanish Female (variante)
        name.contains('-esf-') || // Spanish Female F
        name.contains('-eee-') || // Spanish Female (variante)
        name.contains('-eef-') || // Spanish Female F
        name.contains(
            '-eec-') || // Spanish Female C (confirmado: suena femenino)
        name.contains(
            '-eea-') || // Spanish Female A (confirmado: suena femenino)
        name.contains('female') ||
        name.contains('woman')) {
      return VoiceGender.female;
    }

    // Códigos masculinos conocidos (basado en pruebas reales de sonido)
    if (name.contains('-eeb-') || // Spanish Male B
        name.contains('-eed-') || // Spanish Male D
        name.contains('-eeg-') || // Spanish Male G
        name.contains('male') ||
        name.contains('man')) {
      return VoiceGender.male;
    }

    // Patrones de Google Cloud TTS
    if (name.contains('wavenet-a') ||
        name.contains('neural2-a') ||
        name.contains('standard-a')) {
      return VoiceGender.female;
    }

    if (name.contains('wavenet-b') ||
        name.contains('wavenet-c') ||
        name.contains('neural2-b') ||
        name.contains('neural2-c') ||
        name.contains('standard-b') ||
        name.contains('standard-c')) {
      return VoiceGender.male;
    }

    // Si contiene "language" probablemente sea neutral
    if (name.contains('language')) {
      return VoiceGender.neutral;
    }

    return VoiceGender.neutral;
  }

  VoiceGender getVoiceGender(final String voiceName) => _parseGender(voiceName);

  List<String> getVoiceNames() =>
      _defaultVoices.map((final v) => v.name).toList();

  bool isValidVoice(final String voiceName) => true;

  /// Android Native no soporta conversación en tiempo real
  bool supportsRealtimeForModel(final String? model) => false;
  List<String> getAvailableRealtimeModels() => [];
  bool get supportsRealtime => false;
  String? get defaultRealtimeModel => null;

  /// Helper method to determine voice type (network, local, or other)
  String _getVoiceType(final Map<Object?, Object?> voice) {
    final voiceName = voice['name']?.toString() ?? '';
    final networkRequired = voice['network_required'];

    if (networkRequired == true || voiceName.contains('network')) {
      return 'network';
    } else if (networkRequired == false || voiceName.contains('local')) {
      return 'local';
    } else {
      return 'other';
    }
  }

  /// Get available TTS engines from Android system
  Future<List<String>> getAvailableEngines() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final engines = await _flutterTts.getEngines;
      AILogger.d('[AndroidNativeProvider] Available engines: $engines');

      if (engines != null && engines.isNotEmpty) {
        // Explicit casting to handle List<dynamic> from flutter_tts
        final List<dynamic> dynamicEngines = engines as List<dynamic>;
        return dynamicEngines.map((final e) => e.toString()).toList();
      }
      return [];
    } on Exception catch (e) {
      AILogger.e('[AndroidNativeProvider] Error getting engines: $e');
      return [];
    }
  }

  /// Get default TTS engine
  Future<String?> getDefaultEngine() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final defaultEngine = await _flutterTts.getDefaultEngine;
      AILogger.d('[AndroidNativeProvider] Default engine: $defaultEngine');
      return defaultEngine?.toString();
    } on Exception catch (e) {
      AILogger.e('[AndroidNativeProvider] Error getting default engine: $e');
      return null;
    }
  }

  /// Set TTS engine
  Future<bool> setEngine(final String engineName) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      await _flutterTts.setEngine(engineName);
      AILogger.d('[AndroidNativeProvider] Set engine: $engineName');
      return true;
    } on Exception catch (e) {
      AILogger.e(
          '[AndroidNativeProvider] Error setting engine $engineName: $e');
      return false;
    }
  }

  /// Export all voices from all engines to JSON file in Downloads folder
  Future<String?> exportVoicesToJson() async {
    try {
      if (!_initialized) {
        await initialize();
      }
      if (!_initialized) {
        AILogger.e('[AndroidNativeProvider] Cannot export - not initialized');
        return null;
      }

      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];

      // Crear estructura de datos para el JSON
      final Map<String, dynamic> voicesData = {
        'timestamp': timestamp,
        'device_info': {
          'platform': Platform.operatingSystem,
          'platform_version': Platform.operatingSystemVersion,
        },
        'engines': {},
        'summary': {
          'total_engines': 0,
          'total_voices': 0,
          'spanish_voices': 0,
          'network_voices': 0,
          'wavenet_voices': 0,
        }
      };

      // Obtener motores disponibles
      final engines = await getAvailableEngines();
      AILogger.d(
          '[AndroidNativeProvider] Exporting voices from ${engines.length} engines');
      voicesData['summary']['total_engines'] = engines.length;

      // Guardar el motor actual para restaurarlo después
      final originalEngine = await getDefaultEngine();

      // Recorrer cada motor y obtener sus voces
      for (final engine in engines) {
        AILogger.d('[AndroidNativeProvider] Processing engine: $engine');

        try {
          // Cambiar al motor específico
          await setEngine(engine);

          // Esperar un poco para que el motor se configure
          await Future.delayed(const Duration(milliseconds: 500));

          // Obtener voces de este motor
          final voices = await _flutterTts.getVoices;

          final engineVoices = <Map<String, dynamic>>[];
          int spanishCount = 0, networkCount = 0, wavenetCount = 0;

          if (voices != null) {
            for (final voice in voices) {
              try {
                final voiceMap = Map<String, dynamic>.from(voice as Map);
                final voiceName = voiceMap['name']?.toString() ?? 'unknown';
                final voiceLocale = voiceMap['locale']?.toString() ?? 'unknown';

                // Analizar propiedades de la voz
                final isSpanish = _isSpanishVoice(voiceName, voiceLocale);
                final isNetwork = voice['network_required'] == true ||
                    voiceName.contains('network');
                final isWavenet = voiceName.contains('wavenet') ||
                    voiceName.contains('neural2') ||
                    voiceName.contains('standard');

                if (isSpanish) spanishCount++;
                if (isNetwork) networkCount++;
                if (isWavenet) wavenetCount++;

                // Crear entrada de voz completa
                final voiceEntry = {
                  'name': voiceName,
                  'locale': voiceLocale,
                  'gender': _parseGender(voiceName).name,
                  'quality': voice['quality']?.toString() ?? 'unknown',
                  'network_required': voice['network_required'] ?? false,
                  'latency': voice['latency']?.toString() ?? 'unknown',
                  'features': voice['features']?.toString() ?? 'none',
                  'analysis': {
                    'is_spanish': isSpanish,
                    'is_network': isNetwork,
                    'is_wavenet': isWavenet,
                    'voice_type': _getVoiceType(voice),
                  },
                  'raw_data': voiceMap, // Datos completos originales
                };

                engineVoices.add(voiceEntry);
              } on Exception catch (e) {
                AILogger.w(
                    '[AndroidNativeProvider] Error processing voice in engine $engine: $e');
              }
            }
          }

          // Guardar datos del motor
          voicesData['engines'][engine] = {
            'engine_name': engine,
            'voice_count': engineVoices.length,
            'spanish_voices': spanishCount,
            'network_voices': networkCount,
            'wavenet_voices': wavenetCount,
            'voices': engineVoices,
          };

          // Actualizar resumen global
          voicesData['summary']['total_voices'] += engineVoices.length;
          voicesData['summary']['spanish_voices'] += spanishCount;
          voicesData['summary']['network_voices'] += networkCount;
          voicesData['summary']['wavenet_voices'] += wavenetCount;

          AILogger.d(
              '[AndroidNativeProvider] Engine $engine: ${engineVoices.length} voices (ES:$spanishCount, NET:$networkCount, WAVE:$wavenetCount)');
        } on Exception catch (e) {
          AILogger.e(
              '[AndroidNativeProvider] Error processing engine $engine: $e');
          voicesData['engines'][engine] = {
            'engine_name': engine,
            'error': e.toString(),
            'voice_count': 0,
            'voices': [],
          };
        }
      }

      // Restaurar motor original
      if (originalEngine != null) {
        try {
          await setEngine(originalEngine);
        } on Exception catch (e) {
          AILogger.w(
              '[AndroidNativeProvider] Could not restore original engine: $e');
        }
      }

      // Convertir a JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(voicesData);

      // Guardar en Downloads
      final fileName = 'android_tts_voices_$timestamp.json';
      final filePath = await _saveToDownloads(fileName, jsonString);

      if (filePath != null) {
        AILogger.d(
            '[AndroidNativeProvider] Voices exported successfully to: $filePath');
        AILogger.d(
            '[AndroidNativeProvider] Summary: ${voicesData['summary']['total_engines']} engines, ${voicesData['summary']['total_voices']} total voices, ${voicesData['summary']['spanish_voices']} Spanish voices');
        return filePath;
      } else {
        AILogger.e('[AndroidNativeProvider] Failed to save voices file');
        return null;
      }
    } on Exception catch (e) {
      AILogger.e('[AndroidNativeProvider] Error exporting voices to JSON: $e');
      return null;
    }
  }

  /// Save file to Android Downloads folder
  Future<String?> _saveToDownloads(
      final String fileName, final String content) async {
    try {
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        // En Android, usar el directorio de descargas externo
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navegar hasta Downloads desde el directorio externo
          final downloadsPath = '/storage/emulated/0/Download';
          downloadsDir = Directory(downloadsPath);

          // Si no existe, intentar crear o usar directorio alternativo
          if (!downloadsDir.existsSync()) {
            // Usar directorio del app como fallback
            downloadsDir = Directory('${externalDir.path}/Downloads');
            await downloadsDir.create(recursive: true);
          }
        }
      }

      downloadsDir ??= await getTemporaryDirectory();

      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsString(content);

      AILogger.d('[AndroidNativeProvider] File saved to: ${file.path}');
      return file.path;
    } on Exception catch (e) {
      AILogger.e('[AndroidNativeProvider] Error saving file: $e');
      return null;
    }
  }

  /// Public method to export all TTS voices to JSON file
  /// Returns the file path if successful, null if failed
  Future<String?> exportAllVoicesData() async {
    AILogger.d('[AndroidNativeProvider] Starting voice export...');
    final filePath = await exportVoicesToJson();
    if (filePath != null) {
      AILogger.d('[AndroidNativeProvider] Voice data exported to: $filePath');
    } else {
      AILogger.e('[AndroidNativeProvider] Failed to export voice data');
    }
    return filePath;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;

    try {
      // Detener STT si está escuchando
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }

      AILogger.d('[AndroidNativeProvider] Disposed successfully');
    } on Exception catch (e) {
      AILogger.w('[AndroidNativeProvider] Error during dispose: $e');
    }
  }
}
