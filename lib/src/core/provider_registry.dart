/// Unified AI Provider Registry - Combines constructor registration with instance management.
library;

import '../utils/logger.dart';
// provider_interface.dart removed - no more abstract interfaces!
import '../models/ai_provider_config.dart';
import '../models/ai_capability.dart';

// Import providers for auto-registration (triggers static initialization)
import '../providers/openai_provider.dart';
import '../providers/google_provider.dart';
import '../providers/xai_provider.dart';
import '../providers/android_native_provider.dart';

/// Initialize the AI Provider system with direct registration
///
/// This function ensures all provider classes are registered with their constructors.
/// Simple and direct - no magic, just clarity.
///
/// To add a new provider:
/// 1. Create the provider class with static register() method
/// 2. Import it at the top of this file
/// 3. Add one line to call YourProvider.register() here
/// 4. Done! The provider is registered when this function runs
void registerAllProviders() {
  AILogger.i(
      '[ProviderRegistry] 🚀 Initializing AI providers with direct registration...');

  // Simple and direct registration - no magic, just clarity
  OpenAIProvider.register();
  GoogleProvider.register();
  XAIProvider.register();
  AndroidNativeProvider.register();

  final stats = ProviderRegistry.instance.getStats();
  AILogger.i(
      '[ProviderRegistry] ✅ Registration complete: ${stats['registered_constructors']} providers');
  AILogger.d('[ProviderRegistry] Registered: ${stats['constructor_ids']}');
}

/// Signature for provider constructor functions
/// Constructor signature for providers
typedef ProviderConstructor = dynamic Function(ProviderConfig config);

/// Exception for provider registration/creation failures
class ProviderException implements Exception {
  const ProviderException(this.message, [this.cause]);
  final String message;
  final dynamic cause;
  @override
  String toString() =>
      'ProviderException: $message${cause != null ? ' (Caused by: $cause)' : ''}';
}

/// Unified Provider Registry - handles both constructors and instances
class ProviderRegistry {
  ProviderRegistry._();
  static final ProviderRegistry _instance = ProviderRegistry._();
  static ProviderRegistry get instance => _instance;

  // Constructor registry
  final Map<String, ProviderConstructor> _constructors = {};
  final Map<String, List<String>> _modelPrefixes = {};

  // Instance registry
  final Map<String, dynamic> _instances = {};
  final Map<String, bool> _health = {};

  bool _initialized = false;

  /// Register a provider constructor
  void registerConstructor(
    String providerId,
    final ProviderConstructor constructor, {
    final List<String>? modelPrefixes,
  }) {
    providerId = providerId.toLowerCase().trim();
    _constructors[providerId] = constructor;
    if (modelPrefixes != null) _modelPrefixes[providerId] = modelPrefixes;
    AILogger.i('[ProviderRegistry] ✅ Registered constructor: $providerId');
  }

  /// Create provider instance from constructor
  dynamic createProvider(String providerId, final ProviderConfig config) {
    providerId = providerId.toLowerCase().trim();
    final constructor = _constructors[providerId];
    if (constructor == null) {
      AILogger.w('[ProviderRegistry] ❌ No constructor for: $providerId');
      return null;
    }
    try {
      final provider = constructor(config);
      AILogger.i('[ProviderRegistry] ✅ Created provider: $providerId');
      return provider;
    } catch (e) {
      AILogger.e('[ProviderRegistry] ❌ Failed to create $providerId: $e');
      throw ProviderException('Failed to create provider: $providerId', e);
    }
  }

  /// Register and initialize a provider instance
  Future<bool> registerInstance(final dynamic provider) async {
    try {
      final success = await provider.initialize(<String, dynamic>{});
      _instances[provider.providerId] = provider;
      _health[provider.providerId] = success;
      AILogger.i(
          '[ProviderRegistry] Registered instance: ${provider.providerId} (healthy: $success)');
      return success;
    } on Exception catch (e) {
      AILogger.e(
          '[ProviderRegistry] Failed to register ${provider.providerId}: $e');
      return false;
    }
  }

  /// Get provider instance
  dynamic getProvider(final String providerId) => _instances[providerId];

  /// Get all provider instances (healthy and unhealthy)
  List<dynamic> getAllProviders() => _instances.values.toList();

  /// Get all healthy provider instances
  List<dynamic> getHealthyProviders() {
    return _instances.entries
        .where((final e) => _health[e.key] == true)
        .map((final e) => e.value)
        .toList();
  }

  /// Get providers supporting a capability
  List<dynamic> getProvidersForCapability(final AICapability capability) {
    return getHealthyProviders()
        .where((final p) => p.supportsCapability(capability))
        .toList();
  }

  /// Get best provider for capability
  dynamic getBestProviderForCapability(final AICapability capability) {
    final providers = getProvidersForCapability(capability);
    return providers.isNotEmpty ? providers.first : null;
  }

  /// Get provider for model (using prefixes)
  String? getProviderForModel(final String modelId,
      {final Map<String, ProviderConfig>? configs}) {
    final normalized = modelId.trim().toLowerCase();

    // Try dynamic config prefixes first
    if (configs != null) {
      for (final entry in configs.entries) {
        for (final prefix in entry.value.modelPrefixes) {
          if (normalized.startsWith(prefix.toLowerCase())) return entry.key;
        }
      }
    }

    // Try static prefixes
    for (final entry in _modelPrefixes.entries) {
      for (final prefix in entry.value) {
        if (normalized.startsWith(prefix.toLowerCase())) return entry.key;
      }
    }

    return null;
  }

  /// Check if constructor is registered
  bool isProviderRegistered(final String providerId) =>
      _constructors.containsKey(providerId.toLowerCase().trim());

  /// Get all registered constructor IDs
  List<String> getRegisteredProviders() => _constructors.keys.toList();

  /// Get model prefixes for provider
  List<String>? getModelPrefixes(final String providerId) =>
      _modelPrefixes[providerId.toLowerCase().trim()];

  /// Initialize all providers (call after registerAllProviders)
  void initializeKnownProviders() {
    if (_initialized) {
      AILogger.w('[ProviderRegistry] Already initialized');
      return;
    }
    registerAllProviders();
    _initialized = true;
    AILogger.i(
        '[ProviderRegistry] ✅ Initialization complete: ${_constructors.length} providers');
  }

  /// Clear all registrations
  void clear() {
    _constructors.clear();
    _modelPrefixes.clear();
    _instances.clear();
    _health.clear();
    _initialized = false;
    AILogger.i('[ProviderRegistry] Registry cleared');
  }

  /// Dispose all instances
  Future<void> dispose() async {
    for (final provider in _instances.values) {
      try {
        await provider.dispose();
      } on Exception catch (e) {
        AILogger.w(
            '[ProviderRegistry] Failed to dispose ${provider.providerId}: $e');
      }
    }
    _instances.clear();
    _health.clear();
  }

  /// Get registry statistics
  Map<String, dynamic> getStats() {
    final healthy = _health.values.where((final h) => h).length;
    return {
      'registered_constructors': _constructors.length,
      'constructor_ids': _constructors.keys.toList(),
      'total_instances': _instances.length,
      'healthy_instances': healthy,
      'instance_ids': _instances.keys.toList(),
      'health_status': Map.from(_health),
      'model_prefixes': Map.from(_modelPrefixes),
      'initialized': _initialized,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🏭 Factory Methods (integrados desde ai_provider_factory.dart)
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Create a provider instance with automatic caching (integrado desde factory)
  dynamic createCachedProvider(String providerId, final ProviderConfig config) {
    providerId = providerId.toLowerCase().trim();

    // Check cache first (usar el instance registry existente)
    final cached = _instances[providerId];
    if (cached != null) {
      AILogger.d('[ProviderRegistry] 🎯 Using cached provider: $providerId');
      return cached;
    }

    AILogger.i('[ProviderRegistry] 🏭 Creating provider: $providerId');

    // Create provider using constructor
    final provider = createProvider(providerId, config);
    if (provider == null) {
      throw ProviderException(
        'No registered constructor found for provider type: $providerId. '
        'Make sure the provider is registered in provider_registry.dart',
      );
    }

    // Cache in instances (reusing existing cache system)
    _instances[providerId] = provider;
    AILogger.i('[ProviderRegistry] ✅ Provider created and cached: $providerId');
    return provider;
  }

  /// Create multiple providers with automatic initialization
  Future<Map<String, dynamic>> createMultipleProviders(
      final Map<String, ProviderConfig> configs) async {
    final providers = <String, dynamic>{};

    for (final entry in configs.entries) {
      final providerId = entry.key;
      final config = entry.value;

      if (!config.enabled) {
        AILogger.d(
            '[ProviderRegistry] ⏭️ Skipping disabled provider: $providerId');
        continue;
      }

      try {
        final provider = createCachedProvider(providerId, config);

        // Initialize the provider after creation
        AILogger.d('[ProviderRegistry] 🔄 Initializing provider: $providerId');
        final initialized = await provider.initialize(<String, dynamic>{});

        if (initialized) {
          providers[providerId] = provider;
          _health[providerId] = true;
          AILogger.d(
              '[ProviderRegistry] ✅ Provider $providerId initialized successfully');
        } else {
          _health[providerId] = false;
          AILogger.w(
              '[ProviderRegistry] ⚠️ Provider $providerId failed to initialize, skipping');
        }
      } on Exception catch (e) {
        AILogger.e(
            '[ProviderRegistry] ❌ Failed to create/initialize provider $providerId, skipping: $e');
        _health[providerId] = false;
        // Continue with other providers even if one fails
      }
    }

    AILogger.i(
      '[ProviderRegistry] ✅ Created and initialized ${providers.length} providers: ${providers.keys.join(', ')}',
    );
    return providers;
  }

  /// Clear provider cache (integrated method)
  void clearProviderCache() {
    _instances.clear();
    _health.clear();
    AILogger.d('[ProviderRegistry] 🗑️ Provider cache cleared');
  }
}
