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
/// final textResponse = await AI.text(history, context);
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

/// AI response models (text, image, etc.)
export 'src/models/ai_response.dart';

/// Provider response wrapper
export 'src/models/provider_response.dart';

/// Audio models (voice, synthesis, playback, etc.)
export 'src/models/audio_models.dart';

/// Internal configuration model for AI initialization
export 'src/models/ai_init_config.dart';

/// Generic system prompt model for AI providers
export 'src/models/ai_context.dart';

/// Instructions for audio transcription (Speech-to-Text)

/// Image models and utilities (for image generation and analysis)
export 'src/models/ai_image.dart';

/// Audio models and utilities (for audio generation and analysis)
export 'src/models/ai_audio.dart';

/// Enhanced image generation parameters (format, size, fidelity, seed, etc.)
export 'src/models/ai_image_params.dart';

/// Enhanced audio generation/transcription parameters (speed, format, language, temperature)
export 'src/models/ai_audio_params.dart';

/// Simple AI Provider model for public API (different from internal ProviderConfig)
export 'src/models/ai_provider.dart';

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
// ❌ MultiModelRouter - INTERNAL ONLY
// ❌ ConfigLoader - INTERNAL ONLY (use AI.* for everything)

// ═══════════════════════════════════════════════════════════════════════════════
// 🔧 ADVANCED SERVICES (For Power Users)
// ═══════════════════════════════════════════════════════════════════════════════
// Note: Most users should use AI.* methods instead of these services directly.
// These are exported for advanced use cases that require direct service access.

// ✅ HybridConversationService - ESSENTIAL for conversation streams
// Needed for type declarations, created with AI.createConversation()
export 'src/capabilities/hybrid_conversation_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🚫 INTERNAL SERVICES (Use AI.* methods instead)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Services moved to internal to improve pub.dev score:
// - TextGenerationService → Use AI.text() instead
// - AudioGenerationService → Use AI.speak() instead
// - AudioTranscriptionService → Use AI.listen() instead
// - ImageGenerationService → Use AI.image() instead
// - ImageAnalysisService → Use AI.vision() instead
//
// For advanced users who need direct service access, these can be accessed
// through the AI facade using AI.getService<ServiceType>() method.

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
