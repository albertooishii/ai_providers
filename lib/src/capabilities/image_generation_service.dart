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

  /// Generar imagen con tipos específicos (wrapper para compatibilidad)
  /// DEPRECATED: Usar generateImageAdvanced() directamente
  Future<String?> generateAndSave(
    final String prompt, {
    final ImageType type = ImageType.general,
    final ImageQuality quality = ImageQuality.high,
  }) async {
    try {
      AILogger.d(
        '[ImageGenerationService] 🎯 generateAndSave() - ${prompt.substring(0, prompt.length.clamp(0, 50))}...',
      );

      // Usar generateImageAdvanced() directamente - sin duplicación
      final response =
          await generateImageAdvanced(prompt, type: type, quality: quality);

      return response.imageFileName.isNotEmpty ? response.imageFileName : null;
    } catch (e) {
      AILogger.e('[ImageGenerationService] Error en generateAndSave(): $e');
      rethrow;
    }
  }

  /// 🎯 MÉTODO SIMPLE - usado por AI.image()
  ///
  /// Versión simple que siempre guarda en caché para máxima facilidad de uso.
  /// Esta es la firma EXACTA que necesita AI.image() para evitar circular dependency.
  Future<AIResponse> generateImage(
    final String prompt, [
    final AISystemPrompt? systemPrompt,
  ]) async {
    try {
      AILogger.d(
        '[ImageGenerationService] 🖼️ Generando imagen (simple): ${prompt.substring(0, prompt.length.clamp(0, 50))}...',
      );

      // Usar generateImageAdvanced() con parámetros por defecto - evita duplicación
      return await generateImageAdvanced(
        prompt,
        customSystemPrompt: systemPrompt ?? _createDefaultImageSystemPrompt(),
      );
    } catch (e) {
      AILogger.e('[ImageGenerationService] ❌ Error generando imagen: $e');
      rethrow;
    }
  }

  /// 🎨 MÉTODO AVANZADO - Con control completo de configuración
  ///
  /// Permite control total sobre tipos, calidades y si se quiere guardar en caché o no.
  /// Para uso avanzado cuando se necesita control específico.
  Future<AIResponse> generateImageAdvanced(
    final String prompt, {
    final ImageType type = ImageType.general,
    final ImageQuality quality = ImageQuality.high,
    final bool saveToCache = true,
    final AISystemPrompt? customSystemPrompt,
  }) async {
    try {
      AILogger.d(
        '[ImageGenerationService] 🎨 Generación avanzada: ${prompt.substring(0, prompt.length.clamp(0, 50))}... (saveToCache: $saveToCache)',
      );

      // Usar SystemPrompt personalizado o crear uno según tipo y calidad
      final systemPrompt =
          customSystemPrompt ?? _createSystemPrompt(type, quality);

      // Llamar directamente a AIProviderManager con control completo
      return await AIProviderManager.instance.sendMessage(
        message: prompt,
        systemPrompt: systemPrompt,
        capability: AICapability.imageGeneration,
        saveToCache: saveToCache,
      );
    } catch (e) {
      AILogger.e('[ImageGenerationService] Error en generateImageAdvanced: $e');
      rethrow;
    }
  }

  // === MÉTODOS PRIVADOS ===

  /// Crea SystemPrompt por defecto para generación de imágenes
  AISystemPrompt _createDefaultImageSystemPrompt() {
    final context = <String, dynamic>{
      'task': 'image_generation',
      'image_type': 'general',
    };

    final instructions = <String, dynamic>{
      'quality': 'high',
      'style': 'Generate high-quality images based on the provided prompt.',
      'format': 'Create visually appealing and accurate representations.',
    };

    return AISystemPrompt(
      context: context,
      dateTime: DateTime.now(),
      instructions: instructions,
    );
  }

  AISystemPrompt _createSystemPrompt(
      final ImageType type, final ImageQuality quality) {
    final Map<String, dynamic> context = {'image_type': type.name};
    final Map<String, dynamic> instructions = {'quality': quality.name};

    // Añadir instrucciones específicas según el tipo
    switch (type) {
      case ImageType.avatar:
        instructions.addAll({'format': 'portrait', 'style': 'character'});
        break;
      case ImageType.artistic:
        instructions.addAll({'style': 'artistic', 'creativity': 'high'});
        break;
      case ImageType.photorealistic:
        instructions.addAll({'style': 'photorealistic', 'detail': 'high'});
        break;
      case ImageType.general:
        // Usar configuración general por defecto
        break;
    }

    return AISystemPrompt(
      context: context,
      dateTime: DateTime.now(),
      instructions: instructions,
    );
  }
}

/// Tipos de imagen soportados
enum ImageType {
  general,
  avatar,
  artistic,
  photorealistic,
}

/// Calidades de imagen soportadas
enum ImageQuality {
  standard,
  high,
  ultra,
}
