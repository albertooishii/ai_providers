/// 🚀 Nueva API Ultra-Limpia para AI Providers
/// Reemplaza el horrible AIProviderManager.instance con algo elegante y directo
library;

import 'dart:io';
import 'package:ai_providers/ai_providers.dart';

import 'core/ai_provider_manager.dart';
import 'core/config_loader.dart';
import 'utils/logger.dart';

/// 🎯 Clase AI - API Principal Ultra-Directa
///
/// Arquitectura estratificada:
/// 🎮 Métodos directos: AI.text(), AI.image(), AI.vision(), AI.speak(), AI.transcribe() (capability automático)
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

    return _manager.sendMessage(message: message, systemPrompt: systemPrompt);
  }

  /// 🖼️ Generación de imágenes
  /// Capability automático: imageGeneration
  static Future<AIResponse> image(
      final String prompt, final AISystemPrompt systemPrompt) async {
    AILogger.d('[AI] 🖼️ image() - generating image: ${prompt.length} chars');
    await _manager.initialize();

    return _manager.sendMessage(
        message: prompt,
        systemPrompt: systemPrompt,
        capability: AICapability.imageGeneration);
  }

  /// 👁️ Análisis de imagen/visión
  /// Capability automático: imageAnalysis
  static Future<AIResponse> vision(
    final String imageBase64,
    final String prompt,
    final AISystemPrompt systemPrompt,
  ) async {
    AILogger.d(
        '[AI] 👁️ vision() - analyzing image with prompt: ${prompt.length} chars');
    await _manager.initialize();

    return _manager.sendMessage(
      message: prompt,
      systemPrompt: systemPrompt,
      capability: AICapability.imageAnalysis,
      imageBase64: imageBase64,
      imageMimeType: 'image/jpeg',
    );
  }

  /// 🎤 Síntesis de voz/TTS
  /// Capability automático: audioGeneration
  ///
  /// [text] - Texto a sintetizar
  /// [instructions] - Instrucciones opcionales de síntesis (voz, velocidad, etc.)
  static Future<AIResponse> speak(final String text,
      [final SynthesizeInstructions? instructions]) async {
    AILogger.d('[AI] 🎤 speak() - generating audio: ${text.length} chars');
    await _manager.initialize();

    // Usar instrucciones por defecto si no se proporcionan
    final synthesizeInstructions =
        instructions ?? const SynthesizeInstructions();

    // Crear un AISystemPrompt con las instrucciones de síntesis
    final systemPrompt = AISystemPrompt(
      context: synthesizeInstructions.toMap(),
      dateTime: DateTime.now(),
      instructions: synthesizeInstructions.toMap(),
    );

    return _manager.sendMessage(
        message: text,
        systemPrompt: systemPrompt,
        capability: AICapability.audioGeneration);
  }

  /// 🎧 Transcripción de audio/STT
  /// Capability automático: audioTranscription
  ///
  /// [audioBase64] - Audio en formato base64 a transcribir
  /// [instructions] - Instrucciones opcionales de transcripción (idioma, formato, etc.)
  static Future<AIResponse> transcribe(final String audioBase64,
      [final TranscribeInstructions? instructions]) async {
    AILogger.d('[AI] 🎧 transcribe() - transcribing audio');
    await _manager.initialize();

    // Usar instrucciones por defecto si no se proporcionan
    final transcribeInstructions =
        instructions ?? const TranscribeInstructions();

    // Crear un AISystemPrompt con las instrucciones de transcripción
    final systemPrompt = AISystemPrompt(
      context: transcribeInstructions.toMap(),
      dateTime: DateTime.now(),
      instructions: transcribeInstructions.toMap(),
    );

    return _manager.sendMessage(
      message:
          'Transcribe the provided audio according to the given instructions',
      systemPrompt: systemPrompt,
      capability: AICapability.audioTranscription,
      imageBase64: audioBase64, // Reutilizamos imageBase64 para audio
    );
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

  /// 📋 Obtiene modelos cacheados por proveedor
  static Future<List<String>?> getCachedModels({
    required final String provider,
    final bool forceRefresh = false,
  }) async {
    await _manager.initialize();
    return _manager.cacheService
        ?.getCachedModels(provider: provider, forceRefresh: forceRefresh);
  }

  /// 💾 Guarda modelos en caché
  static Future<void> saveModelsToCache(
      {required final List<String> models,
      required final String provider}) async {
    await _manager.initialize();
    await _manager.cacheService
        ?.saveModelsToCache(models: models, provider: provider);
  }

  /// 🧹 Limpia todo el caché de modelos
  static Future<void> clearModelCache() async {
    await _manager.initialize();
    await _manager.cacheService?.clearAllModelsCache();
  }

  /// 📊 Obtiene el tamaño total del caché
  static Future<int> getCacheSize() async {
    await _manager.initialize();
    return await _manager.cacheService?.getCacheSize() ?? 0;
  }

  /// 📏 Formatea el tamaño del caché a texto legible
  static String formatCacheSize(final int bytes) {
    return _manager.cacheService?.formatCacheSize(bytes) ?? '0 B';
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ⚙️ CONFIGURATION APIs
  // ═══════════════════════════════════════════════════════════════════════════════

  /// 🎯 Obtiene el modelo actualmente configurado para una capability específica
  /// Considera tanto el modelo guardado en preferencias como el del YAML
  static Future<String?> getCurrentModel(final AICapability capability) async {
    await _manager.initialize();
    return await _manager.getSavedModelForCapabilityIfSupported(capability);
  }

  /// 🎯 Obtiene el modelo seleccionado para text generation (reemplaza PrefsUtils.getSelectedModel)
  /// Este método es específicamente lo que PrefsUtils.getSelectedModel() necesita
  static Future<String?> getSelectedModel() async {
    await _manager.initialize();
    return await _manager
        .getSavedModelForCapabilityIfSupported(AICapability.textGeneration);
  }

  /// 💾 Establece el modelo seleccionado (usado desde dialogs de configuración)
  /// Persiste la selección para que se use automáticamente en próximas sesiones
  static Future<void> setSelectedModel(final String model) async {
    await _manager.initialize();
    await _manager.setSelectedModel(model, AICapability.textGeneration);
  }

  /// 🗣️ Establece el proveedor de audio seleccionado
  static Future<void> setSelectedAudioProvider(final String provider) async {
    await _manager.initialize();
    await _manager.setSelectedAudioProvider(provider);
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

  /// 🏷️ Obtiene el nombre de visualización de un proveedor TTS
  /// Usado para mostrar nombres amigables en las interfaces de usuario
  static String getTtsProviderDisplayName(final String providerId) {
    return AIProviderConfigLoader.getTtsProviderDisplayName(providerId);
  }

  /// 📝 Obtiene la descripción de un proveedor TTS
  /// Usado para mostrar información detallada en las interfaces de usuario
  static String getTtsProviderDescription(final String providerId) {
    return AIProviderConfigLoader.getTtsProviderDescription(providerId);
  }

  /// 📋 Obtiene la plantilla de subtítulo de un proveedor TTS
  /// Usado para mostrar información dinámica como conteo de voces
  static String getTtsProviderSubtitleTemplate(final String providerId) {
    return AIProviderConfigLoader.getTtsProviderSubtitleTemplate(providerId);
  }

  /// ⚠️ Obtiene el subtítulo para proveedores TTS no configurados
  /// Usado para mostrar mensajes de estado cuando un proveedor no está disponible
  static String getTtsProviderNotConfiguredSubtitle(final String providerId) {
    return AIProviderConfigLoader.getTtsProviderNotConfiguredSubtitle(
        providerId);
  }

  /// 🎤 Obtiene la voz por defecto para un proveedor específico
  /// Usado por PrefsUtils para obtener valores por defecto de configuración
  static String? getDefaultVoiceForProvider(final String providerId) {
    return AIProviderConfigLoader.getDefaultVoiceForProvider(providerId);
  }

  /// 🎯 Obtiene todos los modelos disponibles para una capability específica
  static Future<List<String>> getAvailableModels(
      final AICapability capability) async {
    await _manager.initialize();
    return await _manager.getAvailableModels(capability);
  }

  /// 🗣️ Obtiene la voz TTS actualmente configurada
  static Future<String?> getCurrentVoice() async {
    await _manager.initialize();
    // TODO: Implementar método para obtener voz actual del provider configurado
    // Por ahora retornamos la voz por defecto
    final audioProvider = _manager
        .getProvidersByCapability(AICapability.audioGeneration)
        .firstOrNull;
    if (audioProvider != null) {
      // Aquí iría la lógica para obtener la voz configurada del provider específico
      return 'default'; // Placeholder
    }
    return null;
  }

  /// 🗣️ Obtiene todas las voces disponibles para TTS
  static Future<List<Map<String, dynamic>>> getAvailableVoices() async {
    await _manager.initialize();
    final audioProvider = _manager
        .getProvidersByCapability(AICapability.audioGeneration)
        .firstOrNull;
    if (audioProvider != null) {
      return await _manager.getAvailableVoices(audioProvider);
    }
    return [];
  }

  /// 🔊 Obtiene todos los proveedores disponibles para TTS
  static List<String> getAvailableAudioProviders() {
    if (!_manager.isInitialized) return [];
    return _manager.getProvidersByCapability(AICapability.audioGeneration);
  }

  /// 🎤 Obtiene el proveedor de audio actualmente seleccionado
  static Future<String?> getCurrentAudioProvider() async {
    return await getCurrentProvider(AICapability.audioGeneration);
  }

  /// 🔍 Verifica si un proveedor específico está disponible y saludable
  static Future<bool> isProviderHealthy(final String providerId) async {
    await _manager.initialize();
    final provider = _manager.providers[providerId];
    if (provider == null) return false;
    return await provider.isHealthy();
  }

  /// 🎯 Verifica si un proveedor soporta una capability específica
  static bool providerSupportsCapability(
      final String providerId, final AICapability capability) {
    if (!_manager.isInitialized) return false;
    final provider = _manager.providers[providerId];
    return provider?.supportsCapability(capability) ?? false;
  }

  /// 🎛️ Obtiene el proveedor actualmente activo para una capability
  static Future<String?> getCurrentProvider(
      final AICapability capability) async {
    await _manager.initialize();
    final providers = _manager.getProvidersByCapability(capability);
    return providers.isNotEmpty ? providers.first : null;
  }

  /// 🎛️ Obtiene todos los proveedores disponibles para una capability
  static List<String> getAvailableProviders(final AICapability capability) {
    if (!_manager.isInitialized) return [];
    return _manager.getProvidersByCapability(capability);
  }

  /// 🔧 Obtiene información sobre todos los proveedores cargados
  static Map<String, dynamic> getProvidersInfo() {
    if (!_manager.isInitialized) return {};
    return _manager.providers.map(
      (final key, final value) => MapEntry(key, {
        'id': key,
        'capabilities': value.capabilities.map((final c) => c.name).toList(),
        'isActive': true, // TODO: Implementar estado de actividad
      }),
    );
  }

  /// 📋 Obtiene todos los modelos por proveedor para una capability específica
  static Future<Map<String, List<String>>> getAllModelsByProvider(
      final AICapability capability) async {
    await _manager.initialize();
    final result = <String, List<String>>{};
    final providers = _manager.getProvidersByCapability(capability);

    for (final provider in providers) {
      try {
        final models =
            await _manager.getAvailableModels(capability, providerId: provider);
        if (models.isNotEmpty) {
          result[provider] = models;
        }
      } on Exception catch (e) {
        AILogger.w('Error getting models for provider $provider: $e');
      }
    }

    return result;
  }

  /// 🗣️ Obtiene todas las voces por proveedor
  static Future<Map<String, List<Map<String, dynamic>>>>
      getAllVoicesByProvider() async {
    await _manager.initialize();
    final result = <String, List<Map<String, dynamic>>>{};
    final providers =
        _manager.getProvidersByCapability(AICapability.audioGeneration);

    for (final provider in providers) {
      try {
        final voices = await _manager.getAvailableVoices(provider);
        if (voices.isNotEmpty) {
          result[provider] = voices;
        }
      } on Exception catch (e) {
        AILogger.w('Error getting voices for provider $provider: $e');
      }
    }

    return result;
  }
}
