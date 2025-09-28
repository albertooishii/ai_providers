import 'package:ai_providers/ai_providers.dart';
import '../core/ai_provider_manager.dart';
import '../utils/logger.dart';

/// 🖼️ ImageGenerationService - Servicio completo de generación de imágenes
///
/// Consolida TODA la funcionalidad de generación de imágenes:
/// - Generación usando AI.image()
/// - Guardado automático con MediaPersistenceService
/// - Diferentes tipos de prompts (general, avatar, artístico)
/// - Gestión de archivos y persistencia
///
/// Reemplaza múltiples servicios con funcionalidad consolidada
class ImageGenerationService {
  ImageGenerationService._();
  static final ImageGenerationService _instance = ImageGenerationService._();
  static ImageGenerationService get instance => _instance;

  /// 🎯 MÉTODO UNIFICADO - usado por AI.image() y casos avanzados
  ///
  /// Versión unificada que combina simplicidad y funcionalidad avanzada.
  /// Acepta parámetros opcionales para casos avanzados pero mantiene simplicidad.
  Future<AIResponse> generateImage(
    final String prompt, [
    final AISystemPrompt? systemPrompt,
    final bool saveToCache = true,
    final AiImageParams? imageParams,
  ]) async {
    try {
      AILogger.d(
        '[ImageGenerationService] 🖼️ Generando imagen: ${prompt.substring(0, prompt.length.clamp(0, 50))}... (saveToCache: $saveToCache)',
      );

      // Crear SystemPrompt usando imageParams o valores por defecto
      final finalSystemPrompt =
          systemPrompt ?? _createSystemPromptFromParams(imageParams);

      // Llamar directamente a AIProviderManager con todos los parámetros
      return await AIProviderManager.instance.sendMessage(
        message: prompt,
        systemPrompt: finalSystemPrompt,
        capability: AICapability.imageGeneration,
        saveToCache: saveToCache,
        additionalParams: imageParams?.toMap(),
      );
    } catch (e) {
      AILogger.e('[ImageGenerationService] ❌ Error generando imagen: $e');
      rethrow;
    }
  }

  // === MÉTODOS PRIVADOS ===

  /// Crea SystemPrompt desde AiImageParams o valores por defecto
  AISystemPrompt _createSystemPromptFromParams(final AiImageParams? params) {
    final context = <String, dynamic>{
      'task': 'image_generation',
    };

    final instructions = <String, dynamic>{
      'quality': params?.quality ?? 'high',
      'style': 'Generate high-quality images based on the provided prompt.',
      'format': 'Create visually appealing and accurate representations.',
    };

    // Añadir parámetros específicos si están disponibles
    if (params != null) {
      if (params.format != null) instructions['image_format'] = params.format;
      if (params.background != null) {
        instructions['background'] = params.background;
      }
      if (params.fidelity != null) instructions['fidelity'] = params.fidelity;
      if (params.seed != null) instructions['seed'] = params.seed;
    }

    return AISystemPrompt(
      context: context,
      dateTime: DateTime.now(),
      instructions: instructions,
    );
  }
}

/// Tipos de imagen soportados (mantenidos para compatibilidad futura)
enum ImageType {
  general,
  avatar,
  artistic,
  photorealistic,
}

/// Calidades de imagen soportadas (mantenidos para compatibilidad futura)
enum ImageQuality {
  standard,
  high,
  ultra,
}
