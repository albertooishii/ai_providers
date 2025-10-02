/// 🚀 Nueva API Ultra-Limpia para AI Providers
library;

import 'package:ai_providers/ai_providers.dart';

import 'capabilities/audio_generation_service.dart';
import 'capabilities/audio_transcription_service.dart';
import 'capabilities/image_analysis_service.dart';
import 'capabilities/image_generation_service.dart';
import 'capabilities/text_generation_service.dart';
import 'core/ai_provider_manager.dart';
import 'core/config_loader.dart';
import 'models/ai_user_preferences.dart';
import 'utils/logger.dart';

/// 🎯 Clase AI - API Principal Ultra-Directa
///
/// Arquitectura estratificada:
/// 🎮 Métodos directos: AI.text(), AI.image(), AI.vision(), AI.speak(), AI.listen() (con detección de silencio), AI.transcribe() (capability automático)
/// 🔧 Método universal: AI.generate() (capability manual)
class AI {
  // Singleton del manager interno (oculto del usuario)
  static AIProviderManager get _manager => AIProviderManager.instance;

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🎮 MÉTODOS DIRECTOS (Capability Automático - Súper Fácil)
  // ═══════════════════════════════════════════════════════════════════════════════

  /// 💬 Generación de texto/conversación
  /// Capability automático: textGeneration
  ///
  /// [context] - Opcional. Si no se proporciona, usa configuración por defecto
  static Future<AIResponse> text(final String message,
      [final AISystemPrompt? systemPrompt]) async {
    AILogger.d('[AI] 💬 text() - generating response: ${message.length} chars');
    await _manager.initialize();

    // Delegar a TextGenerationService (nueva arquitectura)
    return TextGenerationService.instance.generate(message, systemPrompt);
  }

  /// 🖼️ Generación de imágenes
  /// Capability automático: imageGeneration
  ///
  /// Siempre devuelve tanto imageBase64 como imageFileName (si se guarda en caché)
  /// para máxima flexibilidad del usuario.
  ///
  /// **Ejemplo básico:**
  /// ```dart
  /// final image = await AI.image('Robot pintando un mural retro futurista');
  /// ```
  ///
  /// **Ejemplo con parámetros avanzados:**
  /// ```dart
  /// final logo = await AI.image(
  ///   'Mascota robótica con estilo pixel art',
  ///   null,
  ///   const AiImageParams(
  ///     aspectRatio: AiImageAspectRatio.landscape,
  ///     quality: AiImageQuality.high,
  ///     format: AiImageFormat.png,
  ///     background: AiImageBackground.transparent,
  ///     fidelity: AiImageFidelity.high,
  ///     seed: 'logo-v1',
  ///   ),
  /// );
  /// ```
  ///
  /// [prompt] - Descripción de la imagen a generar
  /// [context] - Opcional. Si no se proporciona, usa configuración por defecto
  /// [imageParams] - Opcional. Parámetros específicos de imagen. Ver [AiImageParams] para detalles completos
  static Future<AIResponse> image(
    final String prompt, [
    final AISystemPrompt? systemPrompt,
    final AiImageParams? imageParams,
  ]) async {
    AILogger.d(
        '[AI] 🖼️ image() - generating image: ${prompt.length} chars${imageParams != null ? ', params: $imageParams' : ''}');
    await _manager.initialize();

    // Delegar siempre a ImageGenerationService que maneja todos los casos
    return ImageGenerationService.instance
        .generateImage(prompt, systemPrompt, true, imageParams);
  }

  /// 👁️ Análisis de imagen/visión
  /// Capability automático: imageAnalysis
  ///
  /// [prompt] - Opcional. Si no se proporciona, usa 'Describe esta imagen'
  /// [context] - Opcional. Si no se proporciona, usa configuración por defecto
  static Future<AIResponse> vision(
    final String imageBase64, [
    final String? prompt,
    final AISystemPrompt? systemPrompt,
    final String? imageMimeType,
  ]) async {
    AILogger.d('[AI] 👁️ vision() - analyzing image');
    await _manager.initialize();

    // Delegar a ImageAnalysisService (nueva arquitectura)
    return ImageAnalysisService.instance.analyze(
      imageBase64,
      prompt,
      systemPrompt,
      imageMimeType,
    );
  }

  /// 🎤 Síntesis de voz/TTS/audio
  /// Capability automático: audioGeneration
  ///
  /// Siempre devuelve tanto audioBase64 como audioFileName (guardado en caché)
  /// para máxima flexibilidad del usuario.
  ///
  /// **Ejemplo básico:**
  /// ```dart
  /// final audio = await AI.speak('Hola mundo');
  /// ```
  ///
  /// **Ejemplo con parámetros avanzados:**
  /// ```dart
  /// final audio = await AI.speak(
  ///   'Buenos días, ¿cómo estás?',
  ///   AiAudioParams(
  ///     speed: 1.2,
  ///     audioFormat: AiAudioFormat.wav,
  ///     language: 'es',
  ///     accent: 'español con acento japonés',
  ///     emotion: 'susurrando pero asustada como si acabaras de despertar',
  ///   ),
  ///   play: true,  // Reproduce automáticamente
  /// );
  /// ```
  ///
  /// [text] - Texto a sintetizar
  /// [audioParams] - Parámetros tipados de audio (velocidad, formato, idioma, acento, emoción)
  /// [play] - Si es true, reproduce el audio automáticamente después de generarlo
  static Future<AIResponse> speak(
    final String text, [
    final AiAudioParams? audioParams,
    final bool play = false,
  ]) async {
    AILogger.d(
        '[AI] 🎤 speak() - generating audio: ${text.length} chars, play: $play${audioParams != null ? ', params: $audioParams' : ''}');
    await _manager.initialize();

    // Delegar toda la lógica al AudioGenerationService - siempre guarda en caché
    return AudioGenerationService.instance.synthesize(text, audioParams, play);
  }

  /// 🎧 Escuchar/grabar y transcribir audio automáticamente
  /// Capability automático: audioTranscription
  ///
  /// **CON autoStop=true (default):** Graba hasta detectar silencio y retorna AIResponse
  /// **CON autoStop=false:** Solo inicia grabación y retorna null (usar AI.stopListen() para resultado)
  ///
  /// **Ejemplos:**
  /// ```dart
  /// // Auto-detección
  /// final result = await AI.listen();
  /// if (result != null) print(result.text);
  ///
  /// // Control manual
  /// await AI.listen(autoStop: false); // retorna null
  /// final result = await AI.stopListen(); // retorna AIResponse
  /// ```
  ///
  /// [duration] - Duración máxima de grabación (null = ilimitado hasta silencio)
  /// [silenceTimeout] - Tiempo de silencio para auto-detención (default: 2s)
  /// [autoStop] - Detener automáticamente al detectar silencio (default: true)
  /// [systemPrompt] - Instrucciones del sistema para la transcripción
  ///
  /// **Retorna:** AIResponse con transcripción si autoStop=true, null si autoStop=false
  static Future<AIResponse?> listen({
    final Duration? duration,
    final Duration silenceTimeout = const Duration(seconds: 2),
    final bool autoStop = true,
    final AISystemPrompt? systemPrompt,
  }) async {
    // Log de configuración inteligente
    final configLog = duration != null
        ? 'fixed duration: ${duration.inSeconds}s'
        : autoStop
            ? 'auto-stop on silence (${silenceTimeout.inSeconds}s timeout)'
            : 'manual stop only';

    AILogger.d('[AI] 🎧 listen() - recording with $configLog');
    await _manager.initialize();

    // Delegar toda la lógica avanzada al AudioTranscriptionService
    final result = await AudioTranscriptionService.instance.recordAndTranscribe(
      duration: duration,
      silenceTimeout: silenceTimeout,
      autoStop: autoStop,
      systemPrompt: systemPrompt,
    );

    // Retornar AIResponse completo (incluye audio grabado)
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🎛️ CONTROL Y UTILIDADES (Métodos de Control y Funciones Avanzadas)
  // ═══════════════════════════════════════════════════════════════════════════════

  /// 🛑 Detener reproducción de audio/TTS
  /// Detiene cualquier audio que esté siendo reproducido actualmente
  static Future<bool> stopSpeak() async {
    AILogger.d('[AI] 🛑 stopSpeak() - stopping audio playback');
    await _manager.initialize();

    // Delegar al AudioGenerationService
    return AudioGenerationService.instance.stopPlayback();
  }

  /// ⏸️ Pausar reproducción de audio/TTS
  /// Pausa el audio que está siendo reproducido actualmente
  static Future<bool> pauseSpeak() async {
    AILogger.d('[AI] ⏸️ pauseSpeak() - pausing audio playback');
    await _manager.initialize();

    // Delegar al AudioGenerationService
    return AudioGenerationService.instance.pausePlayback();
  }

  /// 🛑 Detener grabación de audio en curso
  /// Detiene la grabación actual y retorna AIResponse con transcripción y audio grabado
  ///
  /// **Devuelve:** AIResponse con `text` (transcripción) y `audio` (URL + base64 del archivo grabado)
  static Future<AIResponse?> stopListen() async {
    AILogger.d('[AI] 🛑 stopListen() - stopping audio recording');
    await _manager.initialize();

    // Delegar al AudioTranscriptionService
    return AudioTranscriptionService.instance.stopRecording();
  }

  /// 🎧 Transcribir audio existente/STT
  /// Capability automático: audioTranscription
  ///
  /// [audioBase64] - Audio en formato base64 a transcribir
  /// [context] - Instrucciones del sistema para la transcripción
  static Future<AIResponse> transcribe(final String audioBase64,
      [final AISystemPrompt? systemPrompt]) async {
    AILogger.d('[AI] 🎧 transcribe() - transcribing audio');
    await _manager.initialize();

    // Delegar a AudioTranscriptionService (nueva arquitectura)
    return AudioTranscriptionService.instance
        .transcribe(audioBase64, systemPrompt);
  }

  /// 💬 Crear conversación híbrida con streams TTS/STT/respuesta
  /// Permite conversaciones en tiempo real con transcripción y síntesis automática
  static HybridConversationService createConversation() {
    AILogger.d('[AI] 💬 createConversation() - creating hybrid conversation');
    return HybridConversationService();
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🔧 MÉTODO UNIVERSAL (Capability Manual - Casos Complejos)
  // ═══════════════════════════════════════════════════════════════════════════════

  /// 🔧 Método universal para casos complejos
  /// Permite especificar capability manualmente cuando necesites control total
  static Future<AIResponse> generate({
    required final String message,
    required final AISystemPrompt systemPrompt,
    required final AICapability capability,
    final String? imageBase64,
    final String? imageMimeType,
  }) async {
    AILogger.d('[AI] 🔧 generate() - capability: ${capability.name}');
    await _manager.initialize();
    return _manager.sendMessage(
      message: message,
      systemPrompt: systemPrompt,
      capability: capability,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🛠️ UTILIDADES Y ESTADO
  // ═══════════════════════════════════════════════════════════════════════════════

  /// ⚡ Inicialización del sistema AI (automática en primer uso de API)
  /// Carga la configuración desde assets y registra todos los providers
  static Future<void> initialize({final AIInitConfig? config}) async {
    AILogger.d('[AI] ⚡ initialize() - initializing AI system');
    await _manager.initialize(config: config);
  }

  /// 📊 Estado de inicialización
  static bool get isInitialized => _manager.isInitialized;

  /// 🔍 Información de debug
  static String get debugInfo {
    return '''
AI API Status:
- Initialized: ${_manager.isInitialized}
- Providers loaded: ${_manager.providers.length}
- Available capabilities: ${AICapability.values.map((final c) => c.name).join(', ')}
''';
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ⚙️ CONFIGURATION APIs
  // ═══════════════════════════════════════════════════════════════════════════════

  /// 🎯 Obtiene el modelo actualmente configurado para una capability específica
  /// Considera tanto el modelo guardado en preferencias como el del YAML
  static Future<String?> getCurrentModel(final AICapability capability) async {
    await _manager.initialize();

    // Primero intentar obtener el modelo guardado en preferencias
    final savedModel =
        await _manager.getSavedModelForCapabilityIfSupported(capability);
    if (savedModel != null && savedModel.isNotEmpty) {
      return savedModel;
    }

    // Si no hay modelo guardado, usar el modelo por defecto del YAML
    return await _manager.getDefaultModelForCapability(capability);
  }

  /// Get the default model for a specific provider (text generation)
  static Future<String?> getDefaultModelForProvider(
      final String providerId, final AICapability capability) async {
    await _manager.initialize();
    return await _manager.getDefaultModelForProvider(providerId, capability);
  }

  /// 🎯 Establece proveedor y modelo para una capacidad específica
  /// API UNIFICADA que reemplaza setSelectedModel() y setSelectedAudioProvider()
  /// Persiste la selección para que se use automáticamente en próximas sesiones
  static Future<void> setModel(
    final String providerId,
    final String modelId,
    final AICapability capability,
  ) async {
    await _manager.initialize();
    await _manager.setModel(providerId, modelId, capability);
  }

  /// 🧹 Limpia la caché de texto en memoria y devuelve cuántas entradas fueron eliminadas
  static Future<int> clearTextCache() async {
    await _manager.initialize();
    return _manager.clearTextCache();
  }

  /// 🧹 Limpia la caché de audio en disco y devuelve cuántos archivos fueron eliminados
  static Future<int> clearAudioCache() async {
    await _manager.initialize();
    return _manager.clearAudioCache();
  }

  /// 🧹 Limpia la caché de imágenes en disco y devuelve cuántos archivos fueron eliminados
  static Future<int> clearImageCache() async {
    await _manager.initialize();
    return _manager.clearImageCache();
  }

  /// 🧹 Limpia la caché de modelos persistidos y devuelve cuántos archivos fueron eliminados
  static Future<int> clearModelsCache() async {
    await _manager.initialize();
    return _manager.clearModelsCache();
  }

  /// 🎤 Establece la voz seleccionada para un proveedor específico
  static Future<void> setSelectedVoiceForProvider(
      final String provider, final String voice) async {
    await _manager.initialize();
    await _manager.setSelectedVoiceForProvider(provider, voice);
  }

  /// 🎤 Obtiene la voz por defecto para un proveedor específico
  /// Usado por PrefsUtils para obtener valores por defecto de configuración
  static String? getDefaultVoiceForProvider(final String providerId) {
    return AIProviderConfigLoader.getDefaultVoiceForProvider(providerId);
  }

  /// 🎯 Obtiene todos los modelos disponibles de un proveedor específico
  static Future<List<String>> getAvailableModels(
      final String providerId) async {
    await _manager.initialize();
    try {
      return await _manager.getAvailableModels(providerId);
    } on Exception catch (e) {
      AILogger.w('Error getting models for provider $providerId: $e');
      return [];
    }
  }

  /// 🎤 Obtiene la voz configurada para un proveedor específico
  static Future<String?> getCurrentVoiceForProvider(
      final String providerId) async {
    await _manager.initialize();
    try {
      // Try to get saved voice from preferences
      final savedVoice = await _manager.getSavedVoiceForProvider(providerId);
      if (savedVoice != null && savedVoice.isNotEmpty) {
        return savedVoice;
      }

      // Fallback to default voice from configuration
      return getDefaultVoiceForProvider(providerId);
    } on Exception catch (e) {
      AILogger.w('Error getting current voice for provider $providerId: $e');
      return getDefaultVoiceForProvider(providerId);
    }
  }

  /// 🎛️ Obtiene el proveedor actualmente activo para una capability
  static Future<String?> getCurrentProvider(
      final AICapability capability) async {
    await _manager.initialize();
    try {
      final savedConfig =
          await AIUserPreferences.getConfigForCapability(capability);
      if (savedConfig != null) {
        final supportedProviders =
            _manager.getProvidersByCapability(capability);
        if (supportedProviders.contains(savedConfig.provider)) {
          return savedConfig.provider;
        }
      }
    } on Exception catch (e) {
      AILogger.w(
          '[AI] getCurrentProvider: failed to read user preferences for ${capability.name}: $e');
    }

    return _manager.getPrimaryProvider(capability);
  }

  /// 🎛️ Obtiene todos los proveedores disponibles con información rica para una capability
  static List<AIProvider> getAvailableProviders(final AICapability capability) {
    if (!_manager.isInitialized || _manager.config == null) return [];

    // Get provider IDs that support the capability in fallback order
    final providerIds = _manager.getProvidersForCapabilityInOrder(capability);

    // Convert provider IDs to AIProvider objects from YAML config
    return providerIds.map((final providerId) {
      final providerConfig = _manager.config!.aiProviders[providerId];
      if (providerConfig == null) {
        throw StateError(
          'Provider "$providerId" is initialized but not found in configuration. '
          'This indicates a configuration mismatch - check ai_providers_config.yaml',
        );
      }

      // Use the new AIProvider.fromConfig factory method
      return AIProvider.fromConfig(
        id: providerId,
        config: providerConfig,
      );
    }).toList();
    // No need to sort again as _getProvidersForCapability already returns in fallback order
  }

  /// 🗣️ Obtiene las voces disponibles para un proveedor específico
  static Future<List<Map<String, dynamic>>> getVoicesForProvider(
    final String providerId,
  ) async {
    await _manager.initialize();
    try {
      final voices = await _manager.getAvailableVoices(providerId);
      return voices;
    } on Exception catch (e) {
      AILogger.w('Error getting voices for provider $providerId: $e');
      return [];
    }
  }
}
