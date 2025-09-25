import 'package:ai_providers/ai_providers.dart';
import '../utils/logger.dart';

/// Servicio concreto para generación de imágenes usando la nueva API AI
///
/// Métodos súper básicos que wrappean la nueva API AI internamente.
class ImageGenerationService {
  /// Genera imagen usando AI.image() internamente
  Future<AIResponse> generateImage(final String prompt) async {
    try {
      AILogger.d(
        '[ImageGenerationService] 🖼️ Generando imagen: ${prompt.substring(0, prompt.length.clamp(0, 50))}...',
      );

      // Crear un AISystemPrompt básico para generación de imágenes
      final systemPrompt = AISystemPrompt(
        context: {'image_type': 'general'},
        dateTime: DateTime.now(),
        instructions: {'quality': 'high'},
      );
      return await AI.image(prompt, systemPrompt);
    } catch (e) {
      AILogger.e('[ImageGenerationService] Error generando imagen: $e');
      rethrow;
    }
  }

  /// Genera avatar usando AI.image() con contexto específico para avatares
  Future<AIResponse> generateAvatar(final String appearance) async {
    try {
      AILogger.d(
        '[ImageGenerationService] 🧝‍♀️ Generando avatar: ${appearance.substring(0, appearance.length.clamp(0, 50))}...',
      );

      // Crear un AISystemPrompt específico para avatares
      final avatarSystemPrompt = AISystemPrompt(
        context: {'image_type': 'avatar', 'style': 'portrait'},
        dateTime: DateTime.now(),
        instructions: {
          'quality': 'high',
          'format': 'portrait',
          'style': 'anime'
        },
      );
      return await AI.image(appearance, avatarSystemPrompt);
    } catch (e) {
      AILogger.e('[ImageGenerationService] Error generando avatar: $e');
      rethrow;
    }
  }

  /// Genera imagen situacional específica para novia virtual
  /// Combina situación y emoción para contexto de pareja
  Future<AIResponse> generateSituationalImage(
      final String situation, final String emotion) async {
    try {
      AILogger.d(
          '[ImageGenerationService] 💕 Generando imagen situacional: $situation con $emotion');

      final prompt = '$situation with $emotion emotion';
      // Crear un AISystemPrompt específico para imágenes situacionales
      final situationalSystemPrompt = AISystemPrompt(
        context: {'image_type': 'situational', 'emotion': emotion},
        dateTime: DateTime.now(),
        instructions: {'quality': 'high', 'context': 'romantic_relationship'},
      );
      return await AI.image(prompt, situationalSystemPrompt);
    } catch (e) {
      AILogger.e(
          '[ImageGenerationService] Error generando imagen situacional: $e');
      rethrow;
    }
  }

  /// Crea avatar desde perfil completo de novia virtual
  /// Integra con perfil externo para generar apariencia
  Future<AIResponse> createAvatarFromProfile(
      final String profileAppearance) async {
    try {
      AILogger.d('[ImageGenerationService] 👩 Creando avatar desde perfil');

      // Crear un AISystemPrompt específico para avatares desde perfiles
      final profileAvatarSystemPrompt = AISystemPrompt(
        context: {'image_type': 'profile_avatar', 'source': 'profile'},
        dateTime: DateTime.now(),
        instructions: {
          'quality': 'high',
          'format': 'portrait',
          'style': 'detailed_anime'
        },
      );
      return await AI.image(profileAppearance, profileAvatarSystemPrompt);
    } catch (e) {
      AILogger.e(
          '[ImageGenerationService] Error creando avatar desde perfil: $e');
      rethrow;
    }
  }
}
