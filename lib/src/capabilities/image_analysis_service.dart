import 'package:ai_providers/ai_providers.dart';
import '../core/ai_provider_manager.dart';
import '../utils/logger.dart';

/// Servicio para análisis de imágenes con manejo inteligente de Context
///
/// Este servicio es la capa intermedia entre AI.vision() y AIProviderManager,
/// siguiendo la nueva arquitectura donde Services manejan lógica específica.
class ImageAnalysisService {
  // Singleton pattern consistente con otros services
  ImageAnalysisService._internal();
  static final ImageAnalysisService _instance =
      ImageAnalysisService._internal();
  static ImageAnalysisService get instance => _instance;

  /// Método de integración principal - usado por AI.vision()
  ///
  /// Recibe mismos parámetros que AI.vision() y delega a AIProviderManager.
  /// [prompt] - Opcional. Si no se proporciona, usa 'Describe esta imagen detalladamente'
  /// [context] - Opcional. Si no se proporciona, usa configuración por defecto.
  Future<AIResponse> analyze(
    final String imageBase64, [
    final String? prompt,
    final AIContext? aiContext,
    final String? imageMimeType,
  ]) async {
    try {
      // Usar prompt por defecto si no se proporciona
      final effectivePrompt = prompt ?? 'Describe esta imagen detalladamente';

      // Usar system prompt por defecto si no se proporciona
      final effectiveContext =
          aiContext ?? _createDefaultImageAnalysisContext();

      AILogger.d(
          '[ImageAnalysisService] 👁️ Analizando imagen: ${effectivePrompt.substring(0, effectivePrompt.length.clamp(0, 50))}...');

      // Llamar directamente a AIProviderManager (no a AI.vision() para evitar circular dependency)
      return await AIProviderManager.instance.sendMessage(
        message: effectivePrompt,
        aiContext: effectiveContext,
        capability: AICapability.imageAnalysis,
        imageBase64: imageBase64,
        imageMimeType: imageMimeType ?? 'image/jpeg',
      );
    } catch (e) {
      AILogger.e('[ImageAnalysisService] ❌ Error analizando imagen: $e');
      rethrow;
    }
  }

  // === MÉTODOS PRIVADOS ===

  /// Crea un system prompt por defecto optimizado para análisis de imágenes
  AIContext _createDefaultImageAnalysisContext() {
    final instructions = <String, dynamic>{
      'role':
          'Eres un experto analizador de imágenes con capacidades de visión avanzada.',
      'style':
          'Describe las imágenes de manera detallada, precisa y estructurada.',
      'format':
          'Proporciona respuestas claras organizadas por elementos clave: objetos, personas, colores, composición, contexto.',
      'language':
          'Responde en español a menos que se solicite explícitamente otro idioma.',
      'detail_level':
          'Incluye detalles relevantes sin ser excesivamente verboso.',
      'accuracy':
          'Solo describe lo que puedes ver claramente, evita especulaciones.',
    };

    return AIContext(
      context: {
        'task': 'image_analysis',
        'mode': 'vision',
        'capability': 'detailed_description',
      },
      dateTime: DateTime.now(),
      instructions: instructions,
    );
  }
}
