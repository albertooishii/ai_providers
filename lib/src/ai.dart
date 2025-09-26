/// 🚀 Nueva API Ultra-Limpia para AI Providers
/// Reemplaza el horrible AIProviderManager.instance con algo elegante y directo
library;

import 'dart:io';
import 'package:ai_providers/ai_providers.dart';

import 'core/ai_provider_manager.dart';
import 'core/config_loader.dart';
import 'capabilities/text_generation_service.dart';
import 'capabilities/audio_generation_service.dart';
import 'utils/logger.dart';

/// 🎯 Clase AI - API Principal Ultra-Directa
///
/// Arquitectura estratificada:
/// 🎮 Métodos directos: AI.text(), AI.image(), AI.vision(), AI.speak(), AI.listen() (capability automático)
/// 🔧 Método universal: AI.generate() (capability manual)
class AI {
  // Singleton del manager interno (oculto del usuario)
  static AIProviderManager get _manager => AIProviderManager.instance;

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🎮 MÉTODOS DIRECTOS (Capability Automático - Súper Fácil)
  // ═══════════════════════════════════════════════════════════════════════════════

  /// 💬 Generación de texto/conversación
  /// Capability automático: textGeneration
  static Future<AIResponse> text(
      final String message, final AISystemPrompt systemPrompt) async {
    AILogger.d('[AI] 💬 text() - generating response: ${message.length} chars');
    await _manager.initialize();

    // Delegar a TextGenerationService (nueva arquitectura)
    return TextGenerationService.instance.generate(message, systemPrompt);
  }

  /// 🖼️ Generación de imágenes
  /// Capability automático: imageGeneration
  ///
  /// [systemPrompt] - Opcional. Si no se proporciona, usa configuración por defecto
  /// [saveToCache] - Si es true, guarda la imagen en caché y devuelve imageFileName.
  /// Si es false (por defecto), devuelve imageBase64 para uso directo.
  static Future<AIResponse> image(
    final String prompt, [
    final AISystemPrompt? systemPrompt,
    final bool saveToCache = false,
  ]) async {
    AILogger.d(
        '[AI] 🖼️ image() - generating image: ${prompt.length} chars, saveToCache: $saveToCache');
    await _manager.initialize();

    // Delegar a ImageGenerationService (nueva arquitectura)
    return ImageGenerationService.instance
        .generateImage(prompt, systemPrompt, saveToCache);
  }

  /// 👁️ Análisis de imagen/visión
  /// Capability automático: imageAnalysis
  static Future<AIResponse> vision(
    final String imageBase64,
    final String prompt,
    final AISystemPrompt systemPrompt, {
    final String? imageMimeType,
  }) async {
    AILogger.d(
        '[AI] 👁️ vision() - analyzing image with prompt: ${prompt.length} chars');
    await _manager.initialize();

    return _manager.sendMessage(
      message: prompt,
      systemPrompt: systemPrompt,
      capability: AICapability.imageAnalysis,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType ?? 'image/jpeg',
    );
  }

  /// 🎤 Síntesis de voz/TTS
  /// Capability automático: audioGeneration
  ///
  /// [text] - Texto a sintetizar
  /// [instructions] - Instrucciones opcionales de síntesis (voz, velocidad, etc.)
  /// [saveToCache] - Si es true, guarda el audio en caché y devuelve audioFileName.
  /// Si es false (por defecto), devuelve audioBase64 para uso directo.
  static Future<AIResponse> speak(
    final String text, [
    final SynthesizeInstructions? instructions,
    final bool saveToCache = false,
  ]) async {
    AILogger.d('[AI] 🎤 speak() - generating audio: ${text.length} chars');
    await _manager.initialize();

    // Delegar a AudioGenerationService (nueva arquitectura)
    return AudioGenerationService.instance.synthesize(text, instructions, saveToCache);
  }

  /// 🎧 Escuchar/transcribir audio/STT
  /// Capability automático: audioTranscription
  ///
  /// [audioBase64] - Audio en formato base64 a transcribir
  /// [instructions] - Instrucciones opcionales de transcripción (idioma, formato, etc.)
  static Future<AIResponse> listen(final String audioBase64,
      [final TranscribeInstructions? instructions]) async {
    AILogger.d('[AI] 🎧 listen() - transcribing audio');
    await _manager.initialize();

    // Delegar a AudioTranscriptionService (nueva arquitectura)
    return AudioTranscriptionService.instance.transcribe(audioBase64, instructions);
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
  // 💾 CACHE MANAGEMENT APIs
  // ═══════════════════════════════════════════════════════════════════════════════

  /// 🗂️ Obtiene archivo de audio TTS cacheado
  static Future<File?> getCachedAudioFile({
    required final String text,
    required final String voice,
    required final String languageCode,
    required final String provider,
    final double speakingRate = 1.0,
    final double pitch = 0.0,
    final String? extension,
  }) async {
    await _manager.initialize();
    return _manager.cacheService?.getCachedAudioFile(
      text: text,
      voice: voice,
      languageCode: languageCode,
      provider: provider,
      speakingRate: speakingRate,
      pitch: pitch,
      extension: extension,
    );
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
      String providerId, AICapability capability) async {
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

  /// 🎤 Establece la voz seleccionada para un proveedor específico
  static Future<void> setSelectedVoiceForProvider(
      final String provider, final String voice) async {
    await _manager.initialize();
    await _manager.setSelectedVoiceForProvider(provider, voice);
  }

  /// 🔊 Obtiene el proveedor de audio por defecto desde la configuración YAML
  /// Usado por PreferencesManagementService para valores por defecto
  static String getDefaultAudioProvider() {
    return AIProviderConfigLoader.getDefaultAudioProvider();
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
    } catch (e) {
      AILogger.w('Error getting current voice for provider $providerId: $e');
      return getDefaultVoiceForProvider(providerId);
    }
  }

  ///  Obtiene todos los proveedores disponibles para TTS
  static List<String> getAvailableAudioProviders() {
    if (!_manager.isInitialized) return [];
    return _manager.getProvidersByCapability(AICapability.audioGeneration);
  }

  /// 🎤 Obtiene el proveedor de audio actualmente seleccionado
  static Future<String?> getCurrentAudioProvider() async {
    return await getCurrentProvider(AICapability.audioGeneration);
  }

  /// 🎛️ Obtiene el proveedor actualmente activo para una capability
  static Future<String?> getCurrentProvider(
      final AICapability capability) async {
    await _manager.initialize();
    return _manager.getPrimaryProvider(capability);
  }

  /// 🎛️ Obtiene todos los proveedores disponibles con información rica para una capability
  static List<Map<String, dynamic>> getAvailableProviders(
      final AICapability capability) {
    if (!_manager.isInitialized || _manager.config == null) return [];

    // Get provider IDs that support the capability in fallback order
    final providerIds = _manager.getProvidersForCapabilityInOrder(capability);

    // Convert provider IDs to rich information from YAML config
    return providerIds.map((final providerId) {
      final providerConfig = _manager.config!.aiProviders[providerId];
      if (providerConfig == null) {
        throw StateError(
          'Provider "$providerId" is initialized but not found in configuration. '
          'This indicates a configuration mismatch - check ai_providers_config.yaml',
        );
      }

      return {
        'id': providerId,
        'displayName': providerConfig.displayName,
        'description': providerConfig.description,
        'capabilities':
            providerConfig.capabilities.map((final c) => c.identifier).toList(),
        'enabled': providerConfig.enabled,
      };
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
