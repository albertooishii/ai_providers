/// Main orchestrator service for the Dynamic AI Providers system.
/// This service manages provider loading, fallback chains, smart routing,
/// and provides a unified interface for AI operations.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/config_loader.dart';
import '../core/provider_registry.dart';
import '../infrastructure/api_key_manager.dart';
import '../infrastructure/cache_service.dart';
import '../models/additional_params.dart';
import '../models/ai_user_preferences.dart';
import '../models/ai_system_prompt.dart';
import '../infrastructure/http_connection_pool.dart';
import '../infrastructure/monitoring_service.dart';
import '../infrastructure/retry_service.dart';
import '../models/ai_capability.dart';
import '../models/ai_provider_config.dart';
import '../models/ai_init_config.dart';
import '../models/ai_response.dart';
import '../models/ai_image.dart';
import '../models/ai_audio.dart';
import '../models/ai_audio_params.dart';
import '../models/provider_response.dart';
import '../models/retry_config.dart';
import '../services/media_persistence_service.dart';
import '../services/provider_alert_service.dart';
import '../utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Under Option B2 the manager persists any audio/image binary returned by providers.

/// Exception thrown when no suitable provider is available
class NoProviderAvailableException implements Exception {
  const NoProviderAvailableException(this.message);

  final String message;

  @override
  String toString() => 'NoProviderAvailableException: $message';
}

/// Main manager for the Dynamic AI Providers system
class AIProviderManager {
  AIProviderManager._internal();
  static final AIProviderManager _instance = AIProviderManager._internal();

  static AIProviderManager get instance {
    // No auto-initialization to prevent duplicate initialization
    // Users must call AI.initialize() explicitly before using the API
    return _instance;
  }

  /// Public getter for cache service
  CompleteCacheService? get cacheService => _cacheService;

  AIProvidersConfig? _config;
  final Map<String, dynamic> _providers = {};
  bool _initialized = false;

  // Performance and optimization services
  CompleteCacheService? _cacheService;
  MonitoringService? _monitoringService;

  // Advanced Phase 6 services
  HttpConnectionPool? _connectionPool;
  IntelligentRetryService? _retryService;
  ProviderAlertService? _alertService;

  /// Initialize the manager with configuration
  Future<void> initialize({final AIInitConfig? config}) async {
    if (_initialized) return;

    try {
      // Load configuration with automatic .env support and optional overrides
      _config = await AIProviderConfigLoader.loadConfig(initConfig: config);

      // Create effective config for ApiKeyManager initialization
      AIInitConfig effectiveConfig;
      if (config != null) {
        effectiveConfig = config;
      } else {
        // Create config automatically from .env when no config provided
        effectiveConfig = AIProviderConfigLoader.createInitConfigFromEnv();
      }

      // Initialize API Key Manager with effective config
      ApiKeyManager.initialize(effectiveConfig);

      // Configure internal logger
      AILogger.configure(level: _config!.globalSettings.logLevel);

      AILogger.i('Initializing AI Provider Manager...');

      // Register all providers first (auto-registration)
      registerAllProviders();

      AILogger.d(
          'Loaded configuration: ${_config!.aiProviders.length} providers defined');

      // Create providers using integrated registry
      final providers = await ProviderRegistry.instance
          .createMultipleProviders(_config!.aiProviders);
      _providers.clear();
      _providers.addAll(providers);

      // Initialize optimization services (cache, monitoring, deduplication)
      _initializeOptimizationServices();

      _initialized = true;
      AILogger.i('AI Provider Manager initialized successfully');
    } on Exception catch (e) {
      AILogger.e('Failed to initialize AI Provider Manager', error: e);
      rethrow;
    }
  }

  /// Initialize optimization services (cache, monitoring, deduplication)
  void _initializeOptimizationServices() {
    try {
      // Initialize cache service with global settings
      if (_config!.globalSettings.ttsCacheEnabled) {
        final ttlMinutes = _config!.globalSettings.ttsCacheDurationHours * 60;
        _cacheService = CompleteCacheService.instance;
        _cacheService!.initialize(config: CacheConfig(ttlMinutes: ttlMinutes));
        AILogger.d('Cache service initialized with TTL: ${ttlMinutes}min');
      } else {
        AILogger.d('Cache service disabled by configuration');
      }

      // Initialize monitoring service (consolidated)
      _monitoringService = MonitoringService.instance;
      _monitoringService!.initialize();
      AILogger.d('Monitoring service initialized');

      // Initialize advanced Phase 6 services
      _initializeAdvancedServices();
    } on Exception catch (e) {
      AILogger.w('Failed to initialize optimization services: $e');
      // Continue without optimization services
    }
  }

  /// Initialize advanced Phase 6 services
  void _initializeAdvancedServices() {
    try {
      // Initialize HTTP connection pool
      _connectionPool = HttpConnectionPool();
      _connectionPool!.initialize(const ConnectionPoolConfig());
      AILogger.d('HTTP connection pool initialized');

      // Initialize intelligent retry service
      _retryService = IntelligentRetryService();
      _retryService!.initialize(
        RetryConfig(
          maxAttempts: _config!.globalSettings.maxRetries,
          baseDelayMs: _config!.globalSettings.retryDelaySeconds * 1000,
          initialDelayMs: _config!.globalSettings.retryDelaySeconds * 1000,
          retryOnStatusCodes: const [429, 500, 502, 503, 504],
        ),
        const CircuitBreakerConfig(
          failureThreshold: 5,
          successThreshold: 3,
          timeoutMs: 30000,
          recoveryTimeoutMs: 60000,
          failureWindowMs: 300000,
          halfOpenMaxCalls: 3,
          halfOpenRequestPercent: 0.5,
        ),
      );
      AILogger.d('Intelligent retry service initialized');

      // Initialize provider alert service
      _alertService = ProviderAlertService();
      _alertService!.initialize(const AlertThresholds());
      AILogger.d('Provider alert service initialized');

      AILogger.i('Advanced Phase 6 services initialized successfully');
    } on Exception catch (e) {
      AILogger.w('Failed to initialize advanced services: $e');
      // Continue without advanced services
    }
  }

  /// Ensure the manager is initialized, waiting if necessary
  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // If already initializing, wait for it
    int attempts = 0;
    while (!_initialized && attempts < 50) {
      // Max 5 seconds wait
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    // If still not initialized, try to initialize
    if (!_initialized) {
      await initialize();
    }
  }

  /// Send a message using the best available provider for the capability
  /// Automatically selects the optimal provider and model based on capability and user preferences
  Future<AIResponse> sendMessage({
    required final String message,
    required final AISystemPrompt systemPrompt,
    final AICapability capability =
        AICapability.textGeneration, // Default to text generation
    final String? imageBase64,
    final String? imageMimeType,
    final AdditionalParams? additionalParams,
    final bool saveToCache = false, // Nueva opción para guardar en caché
  }) async {
    // Wait for initialization if needed
    if (!_initialized) {
      await _ensureInitialized();
    }

    if (!_initialized || _config == null) {
      throw StateError('AIProviderManager failed to initialize');
    }

    // Ignore deprecated parameters and use automatic selection
    // preferredProviderId and preferredModel are deprecated - we calculate optimal selection here

    // If the user has explicitly configured a provider/model for this capability,
    // use that configuration directly without attempting provider auto-discovery.
    // This ensures user preferences are respected exactly as configured.
    String? preferredProviderId;
    try {
      final config = await AIUserPreferences.getConfigForCapability(capability);
      if (config != null) {
        preferredProviderId = config.provider;
        AILogger.d(
          '[AIProviderManager] Using user-configured provider $preferredProviderId for capability ${capability.name}',
        );
      }
    } on Exception catch (e) {
      AILogger.w(
          '[AIProviderManager] Failed to read user config for provider selection: $e');
    }

    // Try deduplication service if available
    // Request deduplication temporarily disabled during consolidation
    // if (_monitoringService != null) {
    //   final fingerprint = _monitoringService!.createFingerprint(
    //     capability: capability.name,
    //     providerId: providerId,
    //     model: requestModel,
    //     history: history,
    //     systemPrompt: systemPrompt,
    //     imageBase64: imageBase64,
    //     imageMimeType: imageMimeType,
    //     additionalParams: additionalParams,
    //   );

    //   return _monitoringService!.getOrCreateRequest(
    //     fingerprint,
    //     () => _executeRequest(capability, providerId, history, systemPrompt, imageBase64, imageMimeType, additionalParams, requestModel),
    //   );
    // }

    // Add the user message to the context history before sending to provider
    final updatedHistory = <Map<String, dynamic>>[
      ...(systemPrompt.history ?? [])
    ];
    updatedHistory.add({'role': 'user', 'content': message});

    final contextWithMessage = AISystemPrompt(
      context: systemPrompt.context,
      dateTime: systemPrompt.dateTime,
      instructions: systemPrompt.instructions,
      history: updatedHistory,
    ); // AISystemPrompt now contains the complete history including the new user message
    return _sendMessageWithMonitoring(
      systemPrompt: contextWithMessage,
      capability: capability,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
      additionalParams: additionalParams,
      saveToCache: saveToCache,
    );
  }

  /// Internal method to send message with performance monitoring and caching
  /// Uses automatic provider and model selection - no manual preferences
  Future<AIResponse> _sendMessageWithMonitoring({
    required final AISystemPrompt systemPrompt,
    required final AICapability capability,
    final String? imageBase64,
    final String? imageMimeType,
    final AdditionalParams? additionalParams,
    final bool saveToCache = false,
  }) async {
    // Attempt to respect user-selected provider/model configuration
    String? preferredProviderId;
    try {
      final config = await AIUserPreferences.getConfigForCapability(capability);
      if (config != null) {
        preferredProviderId = config.provider;
        AILogger.d(
          '[AIProviderManager] _sendMessage: user-selected config: provider=${config.provider}, model=${config.model}${config.voice != null ? ', voice=${config.voice}' : ''}',
        );
      } else {
        AILogger.d(
          '[AIProviderManager] _sendMessage: no user configuration found for capability ${capability.name}, using default provider order',
        );
      }
    } on Exception catch (e) {
      AILogger.w(
          '[AIProviderManager] _sendMessage: failed reading user config: $e');
    }

    // Use the preferred provider id (if found) so the provider order respects user selection
    final providersToTry =
        _getProvidersForCapability(capability, preferredProviderId);

    if (providersToTry.isEmpty) {
      throw NoProviderAvailableException(
          'No providers available for capability: ${capability.name}');
    }

    AILogger.d(
        'Trying ${providersToTry.length} providers for ${capability.name}: ${providersToTry.join(', ')}');

    Object? lastException;

    for (final providerId in providersToTry) {
      final provider = _providers[providerId];
      if (provider == null) {
        AILogger.w('Provider $providerId not available, skipping');
        continue;
      }

      // Check cache first if available (ONLY for audio generation/TTS - not for text generation)
      CacheKey? cacheKey;
      if (_cacheService != null && capability == AICapability.audioGeneration) {
        // Get audio parameters for cache differentiation
        final audioParams =
            additionalParams?.audioParams ?? const AiAudioParams();

        // Extract text from system prompt history (user message is the last one)
        final userMessage = systemPrompt.history?.isNotEmpty == true
            ? systemPrompt.history!.last['content'] as String? ?? ''
            : '';

        // Get voice if this is audio generation
        String? voiceToUse;
        try {
          voiceToUse = await getVoiceForRequest(providerId, capability);
        } on Exception catch (_) {
          voiceToUse = 'default';
        }

        // ✅ CHECK PERSISTENT CACHE FIRST (CompleteCacheService)
        AILogger.i(
          '[AIProviderManager] 🔍 Checking persistent audio cache...',
          tag: 'AI_PROVIDERS',
        );
        AILogger.d(
          '[AIProviderManager] Cache params: text=${userMessage.substring(0, userMessage.length > 50 ? 50 : userMessage.length)}..., voice=${voiceToUse ?? 'default'}, lang=${audioParams.language ?? 'es'}, provider=$providerId, format=${audioParams.audioFormat}',
          tag: 'AI_PROVIDERS',
        );

        final cachedAudioFile = await _cacheService!.getCachedAudioFile(
          text: userMessage,
          voice: voiceToUse ?? 'default',
          languageCode: audioParams.language ?? 'es',
          provider: providerId,
          speakingRate: audioParams.speed,
          pitch: audioParams.temperature ?? 0.0,
          audioFormat: audioParams.audioFormat,
        );

        if (cachedAudioFile != null) {
          AILogger.i(
            '[AIProviderManager] ✅ CACHE HIT! Using cached audio: ${cachedAudioFile.path}',
            tag: 'AI_PROVIDERS',
          );
          try {
            // ✅ Leer archivo cacheado y convertir a base64
            final cachedBytes = await cachedAudioFile.readAsBytes();
            final cachedBase64 = base64Encode(cachedBytes);

            AILogger.i(
              '[AIProviderManager] 🎵 Cached audio loaded: ${cachedBytes.length} bytes → ${cachedBase64.length} base64 chars',
              tag: 'AI_PROVIDERS',
            );

            return AIResponse(
              text: userMessage,
              provider: providerId,
              audio: AiAudio(
                url: cachedAudioFile.path,
                base64: cachedBase64, // ✅ Base64 del archivo cacheado
                createdAtMs: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          } on Exception catch (e) {
            AILogger.e('[AIProviderManager] Error processing cached audio: $e');
            AILogger.e(
                '[AIProviderManager] Stack trace: ${StackTrace.current}');
            rethrow;
          }
        } else {
          AILogger.w(
            '[AIProviderManager] ❌ CACHE MISS - will generate with AI provider',
            tag: 'AI_PROVIDERS',
          );
        }

        // Calculate the model that will actually be used for proper cache key
        String? modelToUseForCache =
            await _getSavedModelForProviderIfSupported(capability, providerId);
        modelToUseForCache ??=
            await _getModelForCapability(capability, providerId);

        cacheKey = CacheKey(
            providerId: providerId,
            prompt: systemPrompt.history?.toString() ?? '',
            model: modelToUseForCache ?? '');

        final cachedResponse = await _cacheService!.memoryCache?.get(cacheKey);

        // ✅ CRITICAL: Validate memory cache entry is not null before returning
        // If memory cache contains null (corruption), skip and regenerate
        if (cachedResponse != null) {
          // Extra validation: ensure audio is not null
          if (cachedResponse.audio != null &&
              cachedResponse.audio!.base64 != null &&
              cachedResponse.audio!.base64!.isNotEmpty) {
            AILogger.d('Memory cache hit for provider: $providerId');
            try {
              return cachedResponse;
            } on Exception catch (e) {
              AILogger.e(
                  '[AIProviderManager] Error processing cached response: $e');
              AILogger.e(
                  '[AIProviderManager] Stack trace: ${StackTrace.current}');
              rethrow;
            }
          } else {
            // ⚠️ CACHE CORRUPTION: Memory cache has response but audio is null
            AILogger.w(
              '[AIProviderManager] ⚠️ CACHE CORRUPTION DETECTED - Memory cache has null audio for $providerId',
              tag: 'AI_PROVIDERS',
            );
            AILogger.d(
              '[AIProviderManager] Skipping corrupted cache entry, will regenerate',
              tag: 'AI_PROVIDERS',
            );
            // Continue to provider generation instead of returning null
          }
        }
      }

      // Start performance monitoring
      final startTime = DateTime.now();

      try {
        // Use intelligent model selection based on capability and user preferences
        String? modelToUse;
        try {
          modelToUse = await _getSavedModelForProviderIfSupported(
              capability, providerId);
        } on Exception catch (_) {}

        modelToUse ??= await _getModelForCapability(capability, providerId);

        // Get voice if this is audio generation
        String? voiceToUse;
        if (capability == AICapability.audioGeneration) {
          voiceToUse = await getVoiceForRequest(providerId, capability);
          AILogger.d('[AIProviderManager] Voice for request: $voiceToUse');
        }

        AILogger.d(
            'Attempting request with provider: $providerId, model: $modelToUse (intelligent selection)');

        // Build a guarded operation so retries will re-execute both the provider
        // call and the image-presence check. This ensures the centralized retry
        // service can detect and retry an empty-image result.
        final requestedImage = capability == AICapability.imageGeneration;

        Future<AIResponse> guardedCallOperation() async {
          // Manager expects callers/providers to provide base64 via `imageBase64`.
          // Legacy callers that passed `additionalParams['imageFileName']` must
          // now convert that file to base64 before calling; manager will not
          // load files from disk here anymore.
          final String? effectiveImageBase64 = imageBase64;

          // Call provider using the typed contract: providers MUST return ProviderResponse.
          // If a provider returns a different type (legacy AIResponse or other), fail fast
          // so the provider implementation can be updated during migration.
          final ProviderResponse providerResp = await provider.sendMessage(
            systemPrompt: systemPrompt,
            capability: capability,
            model: modelToUse,
            imageBase64: effectiveImageBase64,
            imageMimeType: imageMimeType,
            additionalParams: additionalParams,
            voice: voiceToUse,
          );

          // If the capability requested an image, ensure the provider returned something
          if (requestedImage &&
              (providerResp.imageBase64 == null ||
                  providerResp.imageBase64!.isEmpty)) {
            AILogger.w(
              '[AIProviderManager] Provider $providerId returned no image despite imageGeneration requested. Forcing retry fallback.',
            );
            throw HttpException('520 Empty image result from $providerId');
          }
          // Persist any binary payloads returned by the provider and construct final AIResponse
          String? imageFileName;
          String? audioFileName;
          String? convertedAudioBase64;

          // Only save image to cache if explicitly requested
          if (saveToCache &&
              providerResp.imageBase64 != null &&
              providerResp.imageBase64!.isNotEmpty) {
            try {
              final saved = await MediaPersistenceService.instance
                  .saveBase64Image(providerResp.imageBase64!);
              if (saved != null && saved.isNotEmpty) {
                imageFileName = saved;
                AILogger.d('[AIProviderManager] Image saved to cache: $saved');
              }
            } on Exception catch (e) {
              AILogger.w(
                  '[AIProviderManager] Failed to persist provider image: $e');
            }
          }

          if (providerResp.audioBase64 != null &&
              providerResp.audioBase64!.isNotEmpty) {
            try {
              AILogger.i(
                  '[AIProviderManager] ✅ Audio received from provider $providerId: ${providerResp.audioBase64!.length} chars');
              final preview = providerResp.audioBase64!.length > 50
                  ? providerResp.audioBase64!.substring(0, 50)
                  : providerResp.audioBase64!;
              AILogger.d(
                  '[AIProviderManager] Audio base64 preview: $preview...');

              // Extraer formato de audio deseado desde additionalParams
              String outputFormat = 'm4a'; // Default
              if (additionalParams?.audioParams != null) {
                outputFormat = additionalParams!.audioParams!.audioFormat;
              }

              AILogger.d(
                  '[AIProviderManager] 🎵 Target audio format: $outputFormat');

              // ✅ Generar hash para cache coherente (mismo que se usa en getCachedAudioFile)
              // Recalcular userMessage y audioParams del contexto local
              final audioParams =
                  additionalParams?.audioParams ?? const AiAudioParams();
              final userMessage = systemPrompt.history?.isNotEmpty == true
                  ? systemPrompt.history!.last['content'] as String? ?? ''
                  : '';

              final ttsHash = _cacheService?.generateTtsHash(
                text: userMessage,
                voice: voiceToUse ?? 'default',
                languageCode: audioParams.language ?? 'es',
                provider: providerId,
                speakingRate: audioParams.speed,
                pitch: audioParams.temperature ?? 0.0,
                audioFormat: outputFormat,
              );

              AILogger.i(
                '[AIProviderManager] 💾 Saving audio to cache with hash: $ttsHash',
                tag: 'AI_PROVIDERS',
              );

              final result = await MediaPersistenceService.instance
                  .saveBase64AudioComplete(
                providerResp.audioBase64!,
                outputFormat: outputFormat,
                hash: ttsHash, // ✅ Pasar hash para filename coherente
              );

              if (result != null) {
                audioFileName = result.filePath;
                convertedAudioBase64 =
                    result.base64; // Base64 del M4A convertido
                AILogger.i(
                  '[AIProviderManager] ✅ Audio saved to cache: $audioFileName',
                  tag: 'AI_PROVIDERS',
                );
                AILogger.d(
                    '[AIProviderManager] 🎵 Converted audio base64: ${convertedAudioBase64.length} chars');
              } else {
                AILogger.w(
                    '[AIProviderManager] ❌ Audio conversion returned null result');
              }
            } on Exception catch (e) {
              AILogger.w(
                  '[AIProviderManager] Failed to persist provider audio: $e');
            }
          } else {
            AILogger.w(
                '[AIProviderManager] ⚠️ NO AUDIO from provider $providerId - audioBase64 is ${providerResp.audioBase64 == null ? "null" : "empty"}');
            AILogger.d(
                '[AIProviderManager] Full ProviderResponse: text="${providerResp.text}", imageBase64=${providerResp.imageBase64 != null}, audioBase64=${providerResp.audioBase64}');
          }

          // Build final AIResponse combining provider metadata and persisted filenames
          final finalResp = AIResponse(
            text: providerResp.text,
            provider: providerId,
            image: providerResp.prompt.isNotEmpty ||
                    imageFileName != null ||
                    providerResp.imageBase64 != null
                ? AiImage(
                    prompt: providerResp.prompt.isNotEmpty
                        ? providerResp.prompt
                        : null,
                    url: imageFileName,
                    base64: providerResp.imageBase64,
                    createdAtMs: DateTime.now().millisecondsSinceEpoch,
                  )
                : null,
            audio: audioFileName != null || convertedAudioBase64 != null
                ? AiAudio(
                    url: audioFileName,
                    base64: convertedAudioBase64, // Base64 del M4A convertido
                    createdAtMs: DateTime.now().millisecondsSinceEpoch,
                  )
                : null,
          );

          return finalResp;
        }

        final AIResponse response = _retryService != null
            ? await _retryService!
                .executeWithRetry<AIResponse>(guardedCallOperation, providerId)
            : await guardedCallOperation();

        // Invariant: providers return semantic fields and MAY return raw binary
        // payloads as base64 (`imageBase64`/`audioBase64`). The AIProviderManager
        // is responsible for persisting any returned base64 payloads and will
        // expose final filenames in the returned `AIResponse`.

        // Record successful performance metrics
        _monitoringService?.recordPerformance(
          providerId: providerId,
          responseTimeMs: DateTime.now().difference(startTime).inMilliseconds,
          success: true,
        );

        // Cache the response if caching is available (ONLY for audio generation/TTS)
        if (_cacheService?.memoryCache != null &&
            cacheKey != null &&
            capability == AICapability.audioGeneration) {
          await _cacheService!.memoryCache!.set(cacheKey, response);
        }

        AILogger.i(
            'Successfully received response from provider: $providerId (intelligent selection)');
        return response;
      } on Object catch (e, stackTrace) {
        AILogger.e(
            '[AIProviderManager] Provider $providerId failed with error: $e');
        AILogger.e('[AIProviderManager] Error type: ${e.runtimeType}');
        AILogger.e('[AIProviderManager] Stack trace: $stackTrace');
        lastException = e;

        // Record failed performance metrics
        _monitoringService?.recordPerformance(
          providerId: providerId,
          responseTimeMs: DateTime.now().difference(startTime).inMilliseconds,
          success: false,
          errorType: e.runtimeType.toString(),
        );

        // Continue to next provider in fallback chain
        continue;
      }
    }

    // All providers failed
    throw NoProviderAvailableException(
      'All providers failed for capability ${capability.name}. Last error: $lastException',
    );
  }

  /// Get available models from a specific provider
  Future<List<String>> getAvailableModels(final String providerId) async {
    // Wait for initialization if needed
    if (!_initialized) {
      await _ensureInitialized();
    }

    if (!_initialized || _config == null) {
      throw StateError('AIProviderManager failed to initialize');
    }

    final provider = _providers[providerId];
    if (provider != null) {
      return await provider.fetchModelsFromAPI() ?? [];
    }

    return [];
  }

  /// Get all available providers
  Map<String, dynamic> get providers => Map.unmodifiable(_providers);

  /// Get configuration
  AIProvidersConfig? get config => _config;

  /// Check if manager is initialized
  bool get isInitialized => _initialized;

  /// Get providers that support a specific capability
  List<String> getProvidersByCapability(final AICapability capability) {
    if (!_initialized) return [];

    return _providers.entries
        .where((final entry) => entry.value.supportsCapability(capability))
        .map((final entry) => entry.key)
        .toList();
  }

  /// Get the primary provider for a capability based on fallback chains
  String? getPrimaryProvider(final AICapability capability) {
    if (!_initialized) return null;

    // Use the same logic as _getProvidersForCapability but return only the primary
    final providers = _getProvidersForCapability(capability, null);
    return providers.isNotEmpty ? providers.first : null;
  }

  /// Get providers for a capability in fallback order (public version)
  List<String> getProvidersForCapabilityInOrder(final AICapability capability) {
    if (!_initialized) return [];
    return _getProvidersForCapability(capability, null);
  }

  /// Get the appropriate provider for a specific model
  Future<dynamic> getProviderForModel(final String modelId) async {
    if (!_initialized) return null;

    final modelLower = modelId.toLowerCase().trim();

    // Model-based provider selection
    for (final entry in _providers.entries) {
      final provider = entry.value;
      final providerId = entry.key;

      // Check if this provider supports this model
      final availableModels = await provider.fetchModelsFromAPI() ?? [];
      final supportsModel = availableModels.any(
          (final String model) => model.toLowerCase().trim() == modelLower);

      if (supportsModel && await provider.isHealthy()) {
        AILogger.i('Selected provider $providerId for model: $modelId');
        return provider;
      }

      // Provider-specific model pattern matching as fallback
      if (await provider.isHealthy()) {
        // 🚀 DINÁMICO: Solo usar como fallback si ningún proveedor soportó exactamente el modelo
        // No hardcodear patrones específicos de modelos por proveedor
        AILogger.i(
            'Using $providerId as fallback provider for model: $modelId');
      }
    }

    AILogger.w('No provider found for model: $modelId.');
    return null;
  }

  /// Get the first available provider for a specific capability
  Future<dynamic> getProviderForCapability(
      final AICapability capability) async {
    if (!_initialized) return null;

    final providersForCapability = _getProvidersForCapability(capability, null);

    for (final providerId in providersForCapability) {
      final provider = _providers[providerId];
      if (provider != null && await provider.isHealthy()) {
        return provider;
      }
    }

    return null;
  }

  /// Health check for all providers
  Future<Map<String, bool>> healthCheck() async {
    if (!_initialized) return {};

    final results = <String, bool>{};

    for (final entry in _providers.entries) {
      try {
        results[entry.key] = await entry.value.isHealthy();
      } on Exception catch (e) {
        AILogger.w('Health check failed for provider ${entry.key}: $e');
        results[entry.key] = false;
      }
    }

    return results;
  }

  /// Dispose resources
  Future<void> dispose() async {
    AILogger.i('Disposing AI Provider Manager');

    for (final provider in _providers.values) {
      try {
        await provider.dispose();
      } on Exception catch (e) {
        AILogger.w('Error disposing provider: $e');
      }
    }

    // Dispose optimization services
    _cacheService?.dispose();

    _monitoringService?.dispose();

    // Shutdown HTTP connection pool to cancel timers
    if (_connectionPool is HttpConnectionPool) {
      await (_connectionPool as HttpConnectionPool).shutdown();
    }

    _providers.clear();
    _config = null;
    _initialized = false;
    ProviderRegistry.instance.clearProviderCache();
  }

  /// Get comprehensive system statistics including performance metrics
  Map<String, dynamic> getSystemStats() {
    final baseStats = {
      'initialized': _initialized,
      'total_providers': _providers.length,
      'available_providers': _providers.keys.toList(),
      'has_cache': _cacheService != null,
      'has_monitoring': _monitoringService != null,
    };

    // Add cache statistics if available
    if (_cacheService != null) {
      try {
        baseStats['cache_size'] = _cacheService!.memoryCache?.size ?? 0;
      } on Exception catch (e) {
        baseStats['cache_stats_error'] = e.toString();
      }
    }

    // Add performance statistics if available
    if (_monitoringService != null) {
      try {
        final perfStats = _monitoringService!.getGlobalStats();
        baseStats['performance_stats'] = perfStats;
      } on Exception catch (e) {
        baseStats['performance_stats_error'] = e.toString();
      }
    }

    // Deduplication is now included in global stats
    // (removed separate deduplication stats)

    return baseStats;
  }

  Future<int> clearTextCache() async {
    if (_cacheService?.memoryCache == null) {
      return 0;
    }

    final count = _cacheService!.memoryCache!.size;
    _cacheService!.memoryCache!.clear();
    AILogger.i(
        '[AIProviderManager] Cleared in-memory text cache: $count entries removed');
    return count;
  }

  Future<int> clearAudioCache() async {
    try {
      // Limpiar archivos físicos de audio
      final deleted = await MediaPersistenceService.instance.clearAudioCache();

      // También limpiar caché en memoria para evitar cache hits inválidos
      if (_cacheService?.memoryCache != null) {
        final memoryCacheSize = _cacheService!.memoryCache!.size;
        _cacheService!.memoryCache!.clear();
        AILogger.d(
            '[AIProviderManager] Cleared memory cache: $memoryCacheSize entries removed');
      }

      AILogger.i(
          '[AIProviderManager] Cleared audio cache: $deleted files removed');
      return deleted;
    } on Exception catch (e) {
      AILogger.w('[AIProviderManager] Failed to clear audio cache: $e');
      return 0;
    }
  }

  Future<int> clearImageCache() async {
    try {
      final deleted = await MediaPersistenceService.instance.clearImageCache();
      AILogger.i(
          '[AIProviderManager] Cleared image cache: $deleted files removed');
      return deleted;
    } on Exception catch (e) {
      AILogger.w('[AIProviderManager] Failed to clear image cache: $e');
      return 0;
    }
  }

  Future<int> clearModelsCache() async {
    if (_cacheService == null) {
      return 0;
    }

    final deleted = await _cacheService!.clearAllModelsCache();
    ProviderRegistry.instance.clearProviderCache();
    AILogger.i(
        '[AIProviderManager] Cleared models cache: $deleted files removed');
    return deleted;
  }

  /// Get performance metrics for a specific provider
  ProviderMetrics? getProviderPerformanceMetrics(final String providerId) {
    return _monitoringService?.getMetrics(providerId);
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // Public Configuration Methods (for AI.* API)
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Public method to get saved model for capability
  Future<String?> getSavedModelForCapabilityIfSupported(
      final AICapability capability) async {
    return await _getSavedModelForCapability(capability);
  }

  /// Public method to get available voices for a provider
  /// Currently not implemented as voices are handled automatically by providers
  Future<List<Map<String, dynamic>>> getAvailableVoices(
      final String providerId) async {
    try {
      final provider = _providers[providerId];
      if (provider == null) return [];

      // Get voices from the provider directly
      final voices = await provider.getAvailableVoices();

      AILogger.d(
          'Raw voices from provider $providerId: ${voices.runtimeType} - $voices');

      // Convert VoiceInfo objects to Map format for API compatibility
      final List<Map<String, dynamic>> result = [];
      for (final voice in voices) {
        if (voice != null) {
          try {
            result.add({
              'id': voice.id ?? '',
              'name': voice.name ?? '',
              'language': voice.language ?? '',
              'gender': voice.gender?.toString().split('.').last ?? 'neutral',
              'description': voice.description ?? '',
            });
          } on Exception catch (e) {
            AILogger.w('Error processing voice $voice: $e');
          }
        }
      }

      AILogger.d('Converted voices result: $result');
      return result;
    } on Exception catch (e) {
      AILogger.w('Error getting available voices for $providerId: $e');
      return [];
    }
  }

  /// Get ordered list of providers to try for a capability
  List<String> _getProvidersForCapability(
      final AICapability capability, final String? preferredProviderId) {
    final providers = <String>[];

    // Add preferred provider first if specified and available
    if (preferredProviderId != null &&
        _providers.containsKey(preferredProviderId) &&
        _providers[preferredProviderId]!.supportsCapability(capability)) {
      providers.add(preferredProviderId);
    }

    // Add providers from capability preferences
    if (_config!.capabilityPreferences.containsKey(capability)) {
      final preference = _config!.capabilityPreferences[capability]!;

      // Add primary provider if not already added
      if (!providers.contains(preference.primary) &&
          _providers.containsKey(preference.primary) &&
          _providers[preference.primary]!.supportsCapability(capability)) {
        providers.add(preference.primary);
      }

      // Add fallback providers
      for (final fallbackId in preference.fallbacks) {
        if (!providers.contains(fallbackId) &&
            _providers.containsKey(fallbackId) &&
            _providers[fallbackId]!.supportsCapability(capability)) {
          providers.add(fallbackId);
        }
      }
    } else {
      // No capability preference defined, add all available providers
      final availableProviders = _providers.entries
          .where((final entry) =>
              !providers.contains(entry.key) &&
              entry.value.supportsCapability(capability))
          .map((final entry) => entry.key);

      providers.addAll(availableProviders);
    }

    return providers;
  }

  /// Read the saved selected model from preferences (single place) - Internal implementation
  Future<String?> _getSavedModelForCapability(
      final AICapability capability) async {
    try {
      final config = await AIUserPreferences.getConfigForCapability(capability);
      return config?.model;
    } on Exception catch (e) {
      AILogger.w(
          '[AIProviderManager] _getSavedModelForCapability: failed to read prefs: $e');
      return null;
    }
  }

  /// Saves the selected model for a capability to SharedPreferences
  Future<void> setSelectedModel(
      final String modelId, final AICapability capability) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_model', modelId);
      AILogger.i(
          '[AIProviderManager] setSelectedModel: saved model $modelId for capability $capability');
    } on Exception catch (e) {
      AILogger.w(
          '[AIProviderManager] setSelectedModel: failed to save prefs: $e');
    }
  }

  /// Saves the selected audio provider to SharedPreferences
  Future<void> setSelectedAudioProvider(final String audioProviderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_audio_provider', audioProviderId);
      AILogger.i(
          '[AIProviderManager] setSelectedAudioProvider: saved audio provider $audioProviderId');
    } on Exception catch (e) {
      AILogger.w(
          '[AIProviderManager] setSelectedAudioProvider: failed to save prefs: $e');
    }
  }

  /// Saves the selected provider and model for a capability to SharedPreferences
  Future<void> setModel(final String providerId, final String modelId,
      final AICapability capability) async {
    try {
      await AIUserPreferences.setConfigForCapability(
        capability,
        providerId,
        modelId,
      );

      AILogger.i(
          '[AIProviderManager] setModel: saved provider $providerId and model $modelId for capability ${capability.identifier}');
    } on Exception catch (e) {
      AILogger.w('[AIProviderManager] setModel: failed to save prefs: $e');
    }
  }

  /// Saves the selected voice for a provider to SharedPreferences
  Future<void> setSelectedVoiceForProvider(
      final String audioProviderId, final String voiceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_voice_$audioProviderId', voiceId);
      AILogger.i(
          '[AIProviderManager] setSelectedVoiceForProvider: saved voice $voiceId for provider $audioProviderId');
    } on Exception catch (e) {
      AILogger.w(
          '[AIProviderManager] setSelectedVoiceForProvider: failed to save prefs: $e');
    }
  }

  /// Gets the saved voice for a provider from SharedPreferences
  Future<String?> getSavedVoiceForProvider(final String audioProviderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVoice = prefs.getString('selected_voice_$audioProviderId');
      AILogger.i(
          '[AIProviderManager] getSavedVoiceForProvider: loaded voice $savedVoice for provider $audioProviderId');
      return savedVoice;
    } on Exception catch (e) {
      AILogger.w(
          '[AIProviderManager] getSavedVoiceForProvider: failed to read prefs: $e');
      return null;
    }
  }

  /// If user has a saved model and the given provider supports it for the capability,
  /// return that saved model, otherwise null.
  Future<String?> _getSavedModelForProviderIfSupported(
      final AICapability capability, final String providerId) async {
    final savedModel = await _getSavedModelForCapability(capability);
    if (savedModel == null) return null;

    final providerConfig = _config!.aiProviders[providerId];
    final availableModels = providerConfig?.models[capability] ?? [];
    if (availableModels.contains(savedModel)) {
      return savedModel;
    }

    return null;
  }

  /// Select voice for audio generation (similar to _selectModel)
  String? _selectVoice(final String providerId) {
    try {
      final providerConfig = _config!.aiProviders[providerId];
      if (providerConfig == null) return null;

      // Return first voice from default list
      final defaultVoices = providerConfig.voices['default'] ??
          providerConfig.voices['tts_default'];
      if (defaultVoices != null && defaultVoices.isNotEmpty) {
        return defaultVoices.first;
      }
      return null;
    } on Exception catch (e) {
      AILogger.w('[AIProviderManager] Error selecting voice: $e');
      return null;
    }
  }

  /// Get voice for the current request (saved or default)
  Future<String?> getVoiceForRequest(
    final String providerId,
    final AICapability capability,
  ) async {
    // Only for audioGeneration
    if (capability != AICapability.audioGeneration) {
      return null;
    }

    try {
      // 1. Try to get saved voice
      final savedVoice = await getSavedVoiceForProvider(providerId);
      if (savedVoice != null && savedVoice.isNotEmpty) {
        AILogger.d('[AIProviderManager] Using saved voice: $savedVoice');
        return savedVoice;
      }

      // 2. Use default voice
      final defaultVoice = _selectVoice(providerId);
      AILogger.d('[AIProviderManager] Using default voice: $defaultVoice');
      return defaultVoice;
    } on Exception catch (e) {
      AILogger.w('[AIProviderManager] Error getting voice: $e');
      return _selectVoice(providerId);
    }
  }

  /// Select the best model for a provider and capability
  String? _selectModel(final String providerId, final AICapability capability,
      final String? preferredModel) {
    final providerConfig = _config!.aiProviders[providerId];
    if (providerConfig == null) return null;

    // Use preferred model if specified and available
    if (preferredModel != null) {
      final availableModels = providerConfig.models[capability] ?? [];
      if (availableModels.contains(preferredModel)) {
        return preferredModel;
      }
    }

    // Use default model for the capability
    if (providerConfig.defaults.containsKey(capability)) {
      return providerConfig.defaults[capability];
    }

    // Use first available model as fallback
    final availableModels = providerConfig.models[capability];
    if (availableModels != null && availableModels.isNotEmpty) {
      return availableModels.first;
    }

    return null;
  }

  /// Get default model for a capability from the best available provider (DYNAMIC)
  /// Reemplaza Config.getDefaultTextModel() y métodos similares hardcodeados
  Future<String?> getDefaultModelForCapability(
      final AICapability capability) async {
    try {
      final provider = await getProviderForCapability(capability);
      if (provider == null) {
        AILogger.w(
            '[AIProviderManager] No provider available for capability: ${capability.identifier}');
        return null;
      }

      final model = _selectModel(provider.providerId, capability, null);
      if (model != null) {
        AILogger.d(
          '[AIProviderManager] ✅ Default model for ${capability.identifier}: $model (provider: ${provider.providerId})',
        );
        return model;
      }

      AILogger.w(
          '[AIProviderManager] No default model found for capability: ${capability.identifier}');
      return null;
    } on Exception catch (e) {
      AILogger.e(
          '[AIProviderManager] Error getting default model for ${capability.identifier}: $e');
      return null;
    }
  }

  /// Get the default model for a specific provider and capability
  Future<String?> getDefaultModelForProvider(
      final String providerId, final AICapability capability) async {
    try {
      if (_config == null) {
        AILogger.w('[AIProviderManager] Configuration not loaded');
        return null;
      }

      final model = _selectModel(providerId, capability, null);
      if (model != null) {
        AILogger.d(
          '[AIProviderManager] ✅ Default model for provider $providerId and ${capability.identifier}: $model',
        );
        return model;
      }

      AILogger.w(
          '[AIProviderManager] No default model found for provider $providerId and capability: ${capability.identifier}');
      return null;
    } on Exception catch (e) {
      AILogger.e(
          '[AIProviderManager] Error getting default model for provider $providerId and ${capability.identifier}: $e');
      return null;
    }
  }

  /// Get default text generation model (replacement for Config.getDefaultTextModel)
  Future<String?> getDefaultTextModel() async {
    return getDefaultModelForCapability(AICapability.textGeneration);
  }

  /// Get default image generation model (replacement for Config.getDefaultImageModel)
  Future<String?> getDefaultImageModel() async {
    return getDefaultModelForCapability(AICapability.imageGeneration);
  }

  /// Get the appropriate model based on capability and user preferences
  /// Handles manual selection for text/audio and auto-selection for other capabilities
  Future<String?> _getModelForCapability(
      final AICapability capability, final String providerId) async {
    switch (capability) {
      case AICapability.textGeneration:
        // For text: use manual selection from SharedPreferences or fallback to auto
        try {
          final savedModel = await _getSavedModelForCapability(capability);
          if (savedModel != null && savedModel.trim().isNotEmpty) {
            // Verify the saved model is available for this provider
            final providerConfig = _config!.aiProviders[providerId];
            final availableModels = providerConfig?.models[capability] ?? [];
            if (availableModels.contains(savedModel)) {
              return savedModel;
            }
          }
        } on Exception catch (e) {
          AILogger.w('Failed to get saved text model: $e');
        }
        // Fallback to auto-selection
        return _selectModel(providerId, capability, null);

      case AICapability.audioGeneration:
      case AICapability.realtimeConversation:
        // For audio/voice: could implement voice preference logic here
        // For now, use auto-selection but this could be extended
        return _selectModel(providerId, capability, null);

      default:
        // For images and other capabilities: always auto-selection
        return _selectModel(providerId, capability, null);
    }
  }
}
