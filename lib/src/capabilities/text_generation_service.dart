import 'package:ai_providers/ai_providers.dart';
import '../core/ai_provider_manager.dart';
import '../utils/logger.dart';

/// Servicio para generación de texto con manejo inteligente de SystemPrompt
///
/// Este servicio es la capa intermedia entre AI.text() y AIProviderManager,
/// siguiendo la nueva arquitectura donde Services manejan lógica específica.
class TextGenerationService {
  // Singleton pattern consistente con otros services
  TextGenerationService._internal();
  static final TextGenerationService _instance =
      TextGenerationService._internal();
  static TextGenerationService get instance => _instance;

  /// Método de integración principal - usado por AI.text()
  ///
  /// Recibe mismos parámetros que AI.text() y delega a AIProviderManager.
  /// [systemPrompt] - Opcional. Si no se proporciona, usa configuración por defecto.
  Future<AIResponse> generate(
    final String message, [
    final AISystemPrompt? systemPrompt,
  ]) async {
    try {
      AILogger.d(
          '[TextGenerationService] 🤖 Generando texto: ${message.substring(0, message.length.clamp(0, 50))}...');

      // Usar system prompt por defecto si no se proporciona
      final effectiveSystemPrompt =
          systemPrompt ?? _createDefaultTextSystemPrompt();

      // Llamar directamente a AIProviderManager (no a AI.text() para evitar circular dependency)
      return await AIProviderManager.instance.sendMessage(
        message: message,
        systemPrompt: effectiveSystemPrompt,
      );
    } catch (e) {
      AILogger.e('[TextGenerationService] ❌ Error generando texto: $e');
      rethrow;
    }
  }

  /// Genera texto con SystemPrompt por defecto - para casos donde se omite
  Future<AIResponse> generateWithDefaults(
    final String message, {
    final Map<String, dynamic>? context,
    final List<Map<String, dynamic>>? conversationHistory,
  }) async {
    try {
      AILogger.d('[TextGenerationService] 🔧 Generando con defaults...');

      final systemPrompt = _createDefaultTextSystemPrompt(
        context: context,
        conversationHistory: conversationHistory,
      );

      return await generate(message, systemPrompt);
    } catch (e) {
      AILogger.e('[TextGenerationService] ❌ Error generando con defaults: $e');
      rethrow;
    }
  }

  /// Genera conversación con historial - para uso avanzado
  Future<AIResponse> generateWithHistory(
    final String message, {
    final AISystemPrompt? systemPrompt,
    final List<Map<String, dynamic>>? conversationHistory,
  }) async {
    try {
      AILogger.d('[TextGenerationService] 💬 Generando con historial...');

      final effectiveSystemPrompt = systemPrompt ??
          _createDefaultTextSystemPrompt(
              conversationHistory: conversationHistory);

      // Añadir historial al systemPrompt
      final systemPromptWithHistory = effectiveSystemPrompt.copyWith(
        history: conversationHistory,
      );

      return await generate(message, systemPromptWithHistory);
    } catch (e) {
      AILogger.e('[TextGenerationService] ❌ Error generando con historial: $e');
      rethrow;
    }
  }

  /// Crea SystemPrompt por defecto optimizado para generación de texto
  AISystemPrompt _createDefaultTextSystemPrompt({
    final Map<String, dynamic>? context,
    final List<Map<String, dynamic>>? conversationHistory,
  }) {
    final defaultContext = <String, dynamic>{
      'task': 'text_generation',
      'language': 'spanish',
      'tone': 'helpful_and_professional',
    };

    // Merge context if provided
    if (context != null) {
      defaultContext.addAll(context);
    }

    // Add chat mode if history exists
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      defaultContext['chat_mode'] = true;
      defaultContext['conversation_context'] = 'maintain_coherent_dialogue';
    }

    final instructions = <String, dynamic>{
      'role':
          'Eres un asistente de IA útil que genera texto de alta calidad en español.',
      'style': 'Responde de manera clara, precisa y útil.',
      'format': 'Usa markdown para formatear respuestas cuando sea apropiado.',
    };

    return AISystemPrompt(
      context: defaultContext,
      dateTime: DateTime.now(),
      instructions: instructions,
      history: conversationHistory,
    );
  }
}
