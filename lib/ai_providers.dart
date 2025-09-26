/// 🎯 AI PROVIDERS PLUGIN - RESTRICTED ACCESS API
///
/// 🚨 IMPORTANTE: Este plugin ahora SOLO expone la API AI.*
/// No se puede acceder directamente a managers, services o registry.
///
/// ## ✅ ÚNICO USO PERMITIDO:
/// ```dart
/// import 'package:ai_providers/ai_providers.dart';
///
/// // 🎯 API Ultra-Limpia - ÚNICA FORMA DE USAR AI
/// final textResponse = await AI.text(history, systemPrompt);
/// final audioResponse = await AI.speak('¡Hola mundo!');
/// final imageResponse = await AI.image('Un gato espacial');
/// final transcription = await AI.listen(audioFile);
/// final chatResponse = await AI.chat(message, profile);
/// ```
///
/// ## ❌ YA NO PERMITIDO:
/// ```dart
/// // ❌ PROHIBIDO - No se exporta AIProviderManager
/// final manager = AIProviderManager.instance; // COMPILE ERROR
///
/// // ❌ PROHIBIDO - No se exportan services individuales
/// final service = TextGenerationService(); // COMPILE ERROR
///
/// // ❌ PROHIBIDO - No se exporta registry
/// final registry = ProviderRegistry.instance; // COMPILE ERROR
/// ```
library;

// ═══════════════════════════════════════════════════════════════════════════════
// 🔧 CORE INTERFACES
// ═══════════════════════════════════════════════════════════════════════════════

/// Main interface that all AI providers must implement
// provider_interface.dart removed - no more abstract interfaces!

// ═══════════════════════════════════════════════════════════════════════════════
// 🎯 ESSENTIAL MODELS
// ═══════════════════════════════════════════════════════════════════════════════

/// Core capability definitions (textGeneration, imageGeneration, etc.)
export 'src/models/ai_capability.dart';

/// Provider configuration from YAML
export 'src/models/ai_provider_config.dart';

/// Provider metadata (name, version, capabilities, etc.)
export 'src/models/ai_provider_metadata.dart';

/// AI response models (text, image, etc.)
export 'src/models/ai_response.dart';

/// Provider response wrapper
export 'src/models/provider_response.dart';

/// Audio models (voice, synthesis, playback, etc.)
export 'src/models/audio_models.dart';

/// Retry configuration for resilient requests
export 'src/models/retry_config.dart';

/// Internal configuration model for AI initialization
export 'src/models/ai_init_config.dart';

/// Generic system prompt model for AI providers
export 'src/models/ai_system_prompt.dart';

/// Instructions for voice synthesis (Text-to-Speech)
export 'src/models/synthesize_instructions.dart';

/// Instructions for audio transcription (Speech-to-Text)
export 'src/models/transcribe_instructions.dart';

/// Image model for AI providers
export 'src/models/image.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🎮 MAIN API (AI.* - ÚNICA FORMA DE ACCESO)
// ═══════════════════════════════════════════════════════════════════════════════

/// 🚀 New AI class with ultra-clean API - ONLY PUBLIC ACCESS POINT
/// Use AI.text(), AI.speak(), AI.image(), AI.listen(), etc.
export 'src/ai.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🚫 INTERNAL SERVICES (NO LONGER EXPORTED - USE AI.* INSTEAD)
// ═══════════════════════════════════════════════════════════════════════════════
//
// ❌ AIProviderManager - INTERNAL ONLY (use AI.* instead)
// ❌ TextGenerationService - INTERNAL ONLY (use AI.text() instead)
// ❌ AudioGenerationService - INTERNAL ONLY (use AI.speak() instead)
// ❌ ImageGenerationService - INTERNAL ONLY (use AI.image() instead)
// ❌ MultiModelRouter - INTERNAL ONLY
// ✅ ConfigLoader - YA NO EXPORTADO (usar AI.getDefaultAudioProvider() en su lugar)

// ✅ HybridConversationService - PÚBLICO para conversación híbrida con streams
// Necesario para declarar variables del tipo, se crea con AI.createConversation()
export 'src/capabilities/hybrid_conversation_service.dart';

// ✅ AudioTranscriptionService - Para uso avanzado (grabación con streams)
// Uso básico: AI.listen() | Uso avanzado: AudioTranscriptionService.instance
export 'src/capabilities/audio_transcription_service.dart';

// ✅ ImageGenerationService - Para uso avanzado (tipos de imagen, análisis)
// Uso básico: AI.image() | Uso avanzado: ImageGenerationService.instance
export 'src/capabilities/image_generation_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// � INTERNAL REGISTRY (NO LONGER EXPORTED)
// ═══════════════════════════════════════════════════════════════════════════════
//
// ❌ ProviderRegistry - INTERNAL ONLY (initialization happens automatically)

// ═══════════════════════════════════════════════════════════════════════════════
// 🛠️ UTILITIES (Public-facing)
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// 📋 WHAT'S NOT EXPORTED (Internal Implementation)
// ═══════════════════════════════════════════════════════════════════════════════
//
// ❌ providers/ - Provider implementations are internal
// ❌ services/audio/ - Audio services are internal
// ❌ services/media_persistence_service.dart - Internal service
// ❌ services/monitoring_service.dart - Internal service
// ❌ services/http_connection_pool.dart - Internal service
// ❌ services/in_memory_cache_service.dart - Internal service
// ❌ services/api_key_manager.dart - Internal service
// ❌ services/intelligent_retry_service.dart - Internal service
//
// This maintains encapsulation and allows internal refactoring without
// breaking external code that depends on this plugin.
