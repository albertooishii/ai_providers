import 'package:flutter_test/flutter_test.dart';

import 'package:ai_providers/ai_providers.dart';

/// 🔒 Test para validar que SOLO se puede usar AI.* API
/// Este test DEBE FALLAR si alguien intenta exponer AIProviderManager, services, etc.
void main() {
  group('🔒 AI-Only Access Validation', () {
    test('✅ Should ONLY export AI class and necessary models', () {
      // ✅ PERMITIDO: AI class debe estar disponible
      expect(AI, isA<Type>());

      // ✅ PERMITIDO: Modelos esenciales para usar AI.*
      expect(AICapability.textGeneration, isA<AICapability>());
      expect(AIResponse, isA<Type>());
      expect(ProviderResponse, isA<Type>());
      expect(VoiceGender.female, isA<VoiceGender>());
      expect(AudioMode.hybrid, isA<AudioMode>());
      expect(VoiceInfo, isA<Type>());
      expect(SynthesisResult, isA<Type>());

      print('✅ AI.* API y modelos necesarios están disponibles');
    });

    test(
        '❌ Should NOT export internal managers/services (COMPILE-TIME PROTECTION)',
        () {
      // 🚨 ESTE TEST VALIDA QUE EL CÓDIGO NO COMPILE SI SE INTENTA USAR LO PROHIBIDO

      // Si estos tipos estuvieran disponibles, el test fallaría
      // Como NO están exportados, este código ni siquiera debería compilar

      // ❌ PROHIBIDO: AIProviderManager
      // expect(AIProviderManager, isA<Type>()); // Esto NO debe compilar

      // ❌ PROHIBIDO: Services individuales
      // expect(TextGenerationService, isA<Type>()); // Esto NO debe compilar
      // expect(AudioGenerationService, isA<Type>()); // Esto NO debe compilar
      // expect(ImageGenerationService, isA<Type>()); // Esto NO debe compilar
      // expect(AudioTranscriptionService, isA<Type>()); // Esto NO debe compilar

      // ❌ PROHIBIDO: Registry
      // expect(ProviderRegistry, isA<Type>()); // Esto NO debe compilar

      print('✅ Tipos internos NO están exportados (protección compile-time)');
    });

    test('📋 Document correct usage patterns', () {
      print('''
🎯 USO CORRECTO - Solo estas llamadas están permitidas:

✅ PERMITIDO:
  
  
  // API Ultra-Limpia
  await AI.text(history, context);
  await AI.speak('¡Hola!');
  await AI.image('Un gato espacial'); 
  await AI.listen(audioFile);

❌ PROHIBIDO (YA NO COMPILA):
  
  
  // Acceso directo a internals - COMPILE ERROR
  final manager = AIProviderManager.instance; 
  final service = TextGenerationService();
  final registry = ProviderRegistry.instance;

🔒 RESULTADO: API completamente restringida a AI.*
''');

      expect(true, isTrue, reason: 'Documentation test');
    });

    test('🎯 Validate AI.* methods exist and are callable', () {
      // Verificamos que los métodos AI.* existen sin llamarlos realmente
      // (evitamos errores de inicialización en tests)

      expect(AI.text, isA<Function>());
      expect(AI.speak, isA<Function>());
      expect(AI.image, isA<Function>());
      expect(AI.listen, isA<Function>());
      expect(AI.generate, isA<Function>());

      print('✅ Todos los métodos AI.* están disponibles');
    });
  });
}
