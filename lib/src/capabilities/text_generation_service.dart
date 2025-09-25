import 'package:ai_providers/ai_providers.dart';
import '../utils/logger.dart';

/// Servicio concreto para generación de texto usando la nueva API AI
///
/// Métodos súper básicos que wrappean la nueva API AI internamente.
/// Los SystemPrompt deben pasarse desde fuera para mantener flexibilidad.
class TextGenerationService {
  /// Genera texto usando AI.text() internamente
  Future<AIResponse> generateText(
      final String message, final AISystemPrompt prompt) async {
    try {
      AILogger.d(
          '[TextGenerationService] ✨ Generando texto: ${message.substring(0, message.length.clamp(0, 50))}...');

      return await AI.text(message, prompt);
    } catch (e) {
      AILogger.e('[TextGenerationService] Error generando texto: $e');
      rethrow;
    }
  }

  /// Analiza imagen usando AI.generate() con capability manual
  Future<AIResponse> analyzeImage(
    final String imageBase64,
    final String question,
    final AISystemPrompt prompt, {
    final String? mimeType,
  }) async {
    try {
      AILogger.d('[TextGenerationService] 📸 Analizando imagen: $question');

      return await AI.generate(
        message: question,
        systemPrompt: prompt,
        capability: AICapability.imageAnalysis,
        imageBase64: imageBase64,
        imageMimeType: mimeType ?? 'image/jpeg',
      );
    } catch (e) {
      AILogger.e('[TextGenerationService] Error analizando imagen: $e');
      rethrow;
    }
  }
}
