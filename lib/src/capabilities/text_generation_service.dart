import 'package:ai_providers/ai_providers.dart';
import '../core/ai_provider_manager.dart';
import '../utils/logger.dart';

/// Servicio para generación de texto con manejo inteligente de Context
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
  /// [context] - Opcional. Si no se proporciona, usa configuración por defecto.
  Future<AIResponse> generate(
    final String message, [
    final AIContext? aiContext,
  ]) async {
    try {
      AILogger.d(
          '[TextGenerationService] 🤖 Generando texto: ${message.substring(0, message.length.clamp(0, 50))}...');

      // Usar system prompt por defecto si no se proporciona
      final effectiveContext = aiContext ?? _createDefaultTextContext();

      // Llamar directamente a AIProviderManager (no a AI.text() para evitar circular dependency)
      return await AIProviderManager.instance.sendMessage(
        message: message,
        aiContext: effectiveContext,
      );
    } catch (e) {
      AILogger.e('[TextGenerationService] ❌ Error generando texto: $e');
      rethrow;
    }
  }

  /// Genera texto con Context por defecto - para casos donde se omite
  Future<AIResponse> generateWithDefaults(
    final String message, {
    final Map<String, dynamic>? context,
    final List<Map<String, dynamic>>? conversationHistory,
  }) async {
    try {
      AILogger.d('[TextGenerationService] 🔧 Generando con defaults...');

      final aiContext = _createDefaultTextContext(
        context: context,
        conversationHistory: conversationHistory,
      );

      return await generate(message, aiContext);
    } catch (e) {
      AILogger.e('[TextGenerationService] ❌ Error generando con defaults: $e');
      rethrow;
    }
  }

  /// Genera conversación con historial - para uso avanzado
  Future<AIResponse> generateWithHistory(
    final String message, {
    final AIContext? aiContext,
    final List<Map<String, dynamic>>? conversationHistory,
  }) async {
    try {
      AILogger.d('[TextGenerationService] 💬 Generando con historial...');

      final effectiveContext = aiContext ??
          _createDefaultTextContext(conversationHistory: conversationHistory);

      // Añadir historial al context
      final contextWithHistory = effectiveContext.copyWith(
        history: conversationHistory,
      );

      return await generate(message, contextWithHistory);
    } catch (e) {
      AILogger.e('[TextGenerationService] ❌ Error generando con historial: $e');
      rethrow;
    }
  }

  /// Crea Context por defecto optimizado para generación de texto
  AIContext _createDefaultTextContext({
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

    return AIContext(
      context: defaultContext,
      dateTime: DateTime.now(),
      instructions: instructions,
      history: conversationHistory,
    );
  }
}
