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

  /// 🎯 MÉTODO PRINCIPAL: Generar imagen y guardar automáticamente
  /// Este es el método principal del servicio para funcionalidad completa
  Future<String?> generateAndSave(
    final String prompt, {
    final ImageType type = ImageType.general,
    final ImageQuality quality = ImageQuality.high,
  }) async {
    try {
      AILogger.d(
        '[ImageGenerationService] 🎯 generateAndSave() - ${prompt.substring(0, prompt.length.clamp(0, 50))}...',
      );

      // Crear SystemPrompt según el tipo
      final systemPrompt = _createSystemPrompt(type, quality);

      // Generar imagen usando nuestro método de integración (saveToCache: true)
      final response = await generateImage(prompt, systemPrompt, true);

      if (response.imageFileName.isNotEmpty) {
        AILogger.d(
          '[ImageGenerationService] ✅ Imagen guardada: ${response.imageFileName}',
        );
        return response.imageFileName;
      } else {
        AILogger.w('[ImageGenerationService] No se generó archivo de imagen');
        return null;
      }
    } catch (e) {
      AILogger.e('[ImageGenerationService] Error en generateAndSave(): $e');
      rethrow;
    }
  }

  /// 🎯 MÉTODO DE INTEGRACIÓN - usado por AI.image()
  ///
  /// Recibe mismos parámetros que AI.image() y delega a AIProviderManager.
  /// Esta es la firma EXACTA que necesita AI.image() para evitar circular dependency.
  Future<AIResponse> generateImage(
    String prompt, [
    AISystemPrompt? systemPrompt,
    bool saveToCache = false,
  ]) async {
    try {
      AILogger.d(
        '[ImageGenerationService] 🖼️ Generando imagen: ${prompt.substring(0, prompt.length.clamp(0, 50))}...',
      );

      // Crear SystemPrompt por defecto si no se proporciona
      final effectiveSystemPrompt =
          systemPrompt ?? _createDefaultImageSystemPrompt();

      // Llamar directamente a AIProviderManager (no a AI.image() para evitar circular dependency)
      return await AIProviderManager.instance.sendMessage(
        message: prompt,
        systemPrompt: effectiveSystemPrompt,
        capability: AICapability.imageGeneration,
        saveToCache: saveToCache,
      );
    } catch (e) {
      AILogger.e('[ImageGenerationService] ❌ Error generando imagen: $e');
      rethrow;
    }
  }

  /// Generar imagen con configuración avanzada (tipos y calidades)
  Future<AIResponse> generateImageAdvanced(
    final String prompt, {
    final ImageType type = ImageType.general,
    final ImageQuality quality = ImageQuality.high,
    final bool saveToCache = false,
  }) async {
    try {
      AILogger.d(
        '[ImageGenerationService] 🎨 Generación avanzada: ${prompt.substring(0, prompt.length.clamp(0, 50))}...',
      );

      final systemPrompt = _createSystemPrompt(type, quality);
      return await generateImage(prompt, systemPrompt, saveToCache);
    } catch (e) {
      AILogger.e('[ImageGenerationService] Error en generateImageAdvanced: $e');
      rethrow;
    }
  }

  /// Generar imagen desde base64 existente (análisis/modificación)
  Future<AIResponse> analyzeImage(
      final String imageBase64, final String prompt) async {
    try {
      AILogger.d('[ImageGenerationService] �️ Analizando imagen...');

      final systemPrompt = AISystemPrompt(
        context: {'image_type': 'analysis'},
        dateTime: DateTime.now(),
        instructions: {'task': 'analysis', 'quality': 'detailed'},
      );

      return await AI.vision(imageBase64, prompt, systemPrompt);
    } catch (e) {
      AILogger.e('[ImageGenerationService] Error analizando imagen: $e');
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

  AISystemPrompt _createSystemPrompt(ImageType type, ImageQuality quality) {
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
