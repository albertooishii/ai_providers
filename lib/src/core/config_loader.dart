/// Service for loading and validating AI Providers configuration from YAML files.
/// This service handles loading the ai_providers_config.yaml file and converting it
/// to strongly-typed configuration models.
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';
import '../core/ai_provider_manager.dart';
import '../models/ai_provider_config.dart';
import '../models/ai_init_config.dart';
import 'provider_registry.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// Exception thrown when configuration loading fails
class ConfigurationLoadException implements Exception {
  const ConfigurationLoadException(this.message, [this.innerException]);

  final String message;
  final dynamic innerException;

  @override
  String toString() => 'ConfigurationLoadException: $message'
      '${innerException != null ? ' (${innerException.toString()})' : ''}';
}

/// Service for loading AI provider configuration from YAML
class AIProviderConfigLoader {
  /// Configuration file path in assets
  static const String _defaultConfigPath = 'assets/ai_providers_config.yaml';

  /// Flag to skip environment validation during tests
  static bool skipEnvironmentValidation = false;

  /// Cached configuration for synchronous access
  static Map<String, dynamic>? _cachedConfig;

  /// Internal method to get environment variable value
  /// This replaces dependency on external Config service
  static String _getEnvVar(final String key, [final String defaultValue = '']) {
    // First try Platform.environment (system env vars)
    String? value = Platform.environment[key];

    // If not found, try dotenv (from .env file)
    if (value == null || value.isEmpty) {
      try {
        value = dotenv.env[key];
        if (value != null && value.isNotEmpty) {
          AILogger.i('🎉 Found $key in dotenv: ${value.length} chars');
        } else {
          AILogger.w('❌ $key not found in dotenv');
        }
      } catch (e) {
        // If dotenv is not initialized, continue with system env only
        AILogger.w('DotEnv not accessible for $key: $e');
      }
    } else {
      AILogger.i('🎯 Found $key in Platform.environment');
    }

    return value ?? defaultValue;
  }

  /// Ensure configuration is loaded and return cached config
  static Map<String, dynamic> _ensureConfigLoaded() {
    if (_cachedConfig != null) {
      return _cachedConfig!;
    }

    // If not cached, load from hardcoded fallback (minimal config)
    AILogger.w('Configuration not cached, using minimal fallback values');
    return {
      'ai_providers': {
        'default_provider': {
          'voices': {
            'default': 'default-voice', // Valor genérico en lugar de hardcodear
          },
        },
      },
      'audio': {'default_provider': 'default_provider'}, // Valor genérico
    };
  }

  /// Load default configuration from assets
  static Future<AIProvidersConfig> loadDefault() async {
    final config = await loadFromAssets();
    // Cache the configuration for synchronous access
    _cachedConfig = config.toMap();
    return config;
  }

  /// Load configuration with automatic .env loading and optional overrides
  /// This is the main method that should be used for initialization
  static Future<AIProvidersConfig> loadConfig({
    final AIInitConfig? initConfig,
    final String configPath = _defaultConfigPath,
  }) async {
    try {
      AILogger.i(
          'Loading AI providers configuration with automatic .env support');

      // 1. Load base configuration from assets
      final String yamlString = await rootBundle.loadString(configPath);
      final dynamic yamlDoc = loadYaml(yamlString);

      if (yamlDoc is! YamlMap) {
        throw const ConfigurationLoadException(
            'Configuration must be a YAML map/object');
      }

      // 2. Convert to Map<String, dynamic>
      final Map<String, dynamic> configMap = _yamlToMap(yamlDoc);

      // 3. Validate basic structure
      _validateBasicStructure(configMap);

      // 4. Apply environment variables from .env (automático)
      final processedConfig = _applyEnvironmentOverrides(configMap);

      // 5. Apply manual overrides from initConfig if provided
      final finalConfig = initConfig != null
          ? _applyInitConfigOverrides(processedConfig, initConfig)
          : processedConfig;

      // 6. Create configuration object (no environment validation needed)
      final config = AIProvidersConfig.fromMap(finalConfig);

      // Cache the configuration
      _cachedConfig = finalConfig;

      return config;
    } on Exception catch (e) {
      AILogger.e('Failed to load configuration', error: e);
      if (e is ConfigurationLoadException) rethrow;
      throw ConfigurationLoadException('Failed to load configuration', e);
    }
  }

  /// Load configuration from external init config (for portability)
  static Future<AIProvidersConfig> loadFromInitConfig(
      final AIInitConfig initConfig) async {
    try {
      AILogger.i('Loading AI providers configuration from init config');

      // Start with default configuration from assets (without env validation)
      final defaultConfig = await _loadFromAssetsNoValidation();

      // Convert to map for modification
      final Map<String, dynamic> configMap = defaultConfig.toMap();

      // Update API keys for each configured provider (only if apiKeys is provided)
      final aiProviders =
          configMap['ai_providers'] as Map<String, dynamic>? ?? {};

      if (initConfig.apiKeys != null) {
        for (final entry in initConfig.apiKeys!.entries) {
          final providerId = entry.key;
          final apiKeys = entry.value;

          if (aiProviders.containsKey(providerId) && apiKeys.isNotEmpty) {
            final providerConfig =
                aiProviders[providerId] as Map<String, dynamic>;
            // Use first API key as primary, store others for fallback
            providerConfig['api_key'] = apiKeys.first;
            if (apiKeys.length > 1) {
              providerConfig['fallback_api_keys'] = apiKeys.skip(1).toList();
            }
          }
        }
      }

      configMap['ai_providers'] = aiProviders;

      // Cache the configuration for synchronous access
      _cachedConfig = configMap;

      return AIProvidersConfig.fromMap(configMap);
    } on Exception catch (e) {
      AILogger.e('Failed to load configuration from init config', error: e);
      throw ConfigurationLoadException(
          'Failed to load configuration from init config', e);
    }
  }

  /// Load configuration from assets
  static Future<AIProvidersConfig> loadFromAssets(
      {final String configPath = _defaultConfigPath}) async {
    try {
      AILogger.i('Loading AI providers configuration from assets: $configPath');

      final String yamlString = await rootBundle.loadString(configPath);
      return _parseConfiguration(yamlString);
    } on Exception catch (e) {
      AILogger.e('Failed to load configuration from assets', error: e);
      throw ConfigurationLoadException(
          'Failed to load configuration from assets at $configPath', e);
    }
  }

  /// Load configuration from assets without environment validation
  /// Used internally by loadFromInitConfig since API keys are provided directly
  static Future<AIProvidersConfig> _loadFromAssetsNoValidation(
      {final String configPath = _defaultConfigPath}) async {
    try {
      AILogger.i(
          'Loading AI providers configuration from assets (no env validation): $configPath');

      final String yamlString = await rootBundle.loadString(configPath);
      return _parseConfigurationNoValidation(yamlString);
    } on Exception catch (e) {
      AILogger.e('Failed to load configuration from assets', error: e);
      throw ConfigurationLoadException(
          'Failed to load configuration from assets at $configPath', e);
    }
  }

  /// Parse YAML string into configuration model
  static AIProvidersConfig _parseConfiguration(final String yamlString) {
    try {
      // Parse YAML
      final dynamic yamlDoc = loadYaml(yamlString);

      if (yamlDoc is! YamlMap) {
        throw const ConfigurationLoadException(
            'Configuration must be a YAML map/object');
      }

      // Convert to Map<String, dynamic>
      final Map<String, dynamic> configMap = _yamlToMap(yamlDoc);

      // Validate basic structure
      _validateBasicStructure(configMap);

      // Apply environment overrides
      final processedConfig = _applyEnvironmentOverrides(configMap);

      // Validate environment variables
      _validateEnvironmentVariables(processedConfig);

      // Create configuration object
      return AIProvidersConfig.fromMap(processedConfig);
    } on Exception catch (e) {
      AILogger.e('Failed to parse YAML configuration', error: e);
      if (e is ConfigurationLoadException) rethrow;
      throw ConfigurationLoadException('Failed to parse YAML configuration', e);
    }
  }

  /// Parse configuration without environment variable validation
  /// Used when API keys are provided directly via AIInitConfig
  static AIProvidersConfig _parseConfigurationNoValidation(
      final String yamlString) {
    try {
      // Parse YAML
      final dynamic yamlDoc = loadYaml(yamlString);

      if (yamlDoc is! YamlMap) {
        throw const ConfigurationLoadException(
            'Configuration must be a YAML map/object');
      }

      // Convert to Map<String, dynamic>
      final Map<String, dynamic> configMap = _yamlToMap(yamlDoc);

      // Validate basic structure
      _validateBasicStructure(configMap);

      // Apply environment overrides (still needed for other settings)
      final processedConfig = _applyEnvironmentOverrides(configMap);

      // Skip environment validation - API keys provided directly via AIInitConfig

      // Create configuration object
      return AIProvidersConfig.fromMap(processedConfig);
    } on Exception catch (e) {
      AILogger.e('Failed to parse YAML configuration', error: e);
      if (e is ConfigurationLoadException) rethrow;
      throw ConfigurationLoadException('Failed to parse YAML configuration', e);
    }
  }

  /// Apply manual API key overrides from AIInitConfig
  static Map<String, dynamic> _applyInitConfigOverrides(
      Map<String, dynamic> configMap, AIInitConfig initConfig) {
    final Map<String, dynamic> updatedConfig = Map.from(configMap);

    // Update API keys for each configured provider (only if apiKeys is provided)
    final aiProviders =
        updatedConfig['ai_providers'] as Map<String, dynamic>? ?? {};

    if (initConfig.apiKeys != null) {
      for (final entry in initConfig.apiKeys!.entries) {
        final providerId = entry.key;
        final apiKeys = entry.value;

        if (aiProviders.containsKey(providerId) && apiKeys.isNotEmpty) {
          final providerConfig = Map<String, dynamic>.from(
              aiProviders[providerId] as Map<String, dynamic>);

          // Use first API key as primary, store others for fallback
          providerConfig['api_key'] = apiKeys.first;
          if (apiKeys.length > 1) {
            providerConfig['fallback_api_keys'] = apiKeys.skip(1).toList();
          }

          aiProviders[providerId] = providerConfig;
        }
      }
    }

    updatedConfig['ai_providers'] = aiProviders;
    return updatedConfig;
  }

  /// Convert YAML nodes to dynamic (preserving structure)
  static dynamic _yamlToMap(final dynamic yamlNode) {
    if (yamlNode is YamlMap) {
      final map = <String, dynamic>{};
      for (final entry in yamlNode.entries) {
        map[entry.key.toString()] = _yamlToMap(entry.value);
      }
      return map;
    } else if (yamlNode is YamlList) {
      return yamlNode.map(_yamlToMap).toList();
    } else {
      return yamlNode;
    }
  }

  /// Validate basic YAML structure
  static void _validateBasicStructure(final Map<String, dynamic> configMap) {
    final errors = <String>[];

    // Check required top-level keys
    final requiredKeys = [
      'version',
      'metadata',
      'global_settings',
      'ai_providers',
      'capability_preferences'
    ];
    for (final key in requiredKeys) {
      if (!configMap.containsKey(key)) {
        errors.add('Missing required key: $key');
      }
    }

    // Validate version format
    if (configMap.containsKey('version')) {
      final version = configMap['version'];
      if (version is! String || !RegExp(r'^\d+\.\d+$').hasMatch(version)) {
        errors
            .add('Invalid version format. Expected format: X.Y (e.g., "1.0")');
      }
    }

    // Validate ai_providers structure
    if (configMap.containsKey('ai_providers')) {
      final providers = configMap['ai_providers'];
      if (providers is! Map) {
        errors.add('ai_providers must be a map/object');
      } else {
        final providerMap = providers as Map<String, dynamic>;
        if (providerMap.isEmpty) {
          errors.add('ai_providers cannot be empty');
        }

        // Validate each provider
        for (final entry in providerMap.entries) {
          final providerKey = entry.key;
          final providerConfig = entry.value;

          if (providerConfig is! Map) {
            errors.add(
                'Provider "$providerKey" configuration must be a map/object');
            continue;
          }

          final provider = providerConfig as Map<String, dynamic>;
          final requiredProviderKeys = [
            'enabled',
            'display_name',
            'capabilities'
          ];
          for (final key in requiredProviderKeys) {
            if (!provider.containsKey(key)) {
              errors.add('Provider "$providerKey" missing required key: $key');
            }
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      throw ConfigurationLoadException(
          'Configuration validation failed:\n${errors.join('\n')}');
    }
  }

  /// Apply environment-specific overrides
  static Map<String, dynamic> _applyEnvironmentOverrides(
      final Map<String, dynamic> configMap) {
    // Use development environment by default
    return _applyEnvironmentOverridesMap(configMap, 'development');
  }

  /// Apply environment-specific overrides with specified environment
  static Map<String, dynamic> _applyEnvironmentOverridesMap(
    final Map<String, dynamic> configMap,
    final String environment,
  ) {
    final result = Map<String, dynamic>.from(configMap);

    // Check for environment-specific configurations
    final environments = configMap['environments'] as Map<String, dynamic>?;
    if (environments == null) return result;

    // Use specified environment
    final currentEnv = environment;
    AILogger.i('Applying environment overrides for: $currentEnv');
    final envConfig = environments[currentEnv] as Map<String, dynamic>?;
    if (envConfig == null) {
      AILogger.w('No configuration found for environment: $currentEnv');
      return result;
    }

    // Apply global settings overrides
    if (envConfig.containsKey('global_settings')) {
      final globalOverrides =
          envConfig['global_settings'] as Map<String, dynamic>;
      final existingGlobal = result['global_settings'] as Map<String, dynamic>;
      result['global_settings'] = {...existingGlobal, ...globalOverrides};
      AILogger.d('Applied global settings overrides: ${globalOverrides.keys}');
    }

    // Apply provider-specific overrides
    if (envConfig.containsKey('ai_providers')) {
      final providerOverrides =
          envConfig['ai_providers'] as Map<String, dynamic>;
      final existingProviders = result['ai_providers'] as Map<String, dynamic>;

      for (final entry in providerOverrides.entries) {
        final providerKey = entry.key;
        final overrides = entry.value as Map<String, dynamic>;

        if (existingProviders.containsKey(providerKey)) {
          final existingProvider =
              existingProviders[providerKey] as Map<String, dynamic>;
          final mergedProvider = Map<String, dynamic>.from(existingProvider);

          // Hacer merge profundo para campos específicos
          for (final overrideEntry in overrides.entries) {
            final overrideKey = overrideEntry.key;
            final overrideValue = overrideEntry.value;

            if (overrideKey == 'defaults' &&
                overrideValue is Map<String, dynamic> &&
                mergedProvider.containsKey('defaults') &&
                mergedProvider['defaults'] is Map<String, dynamic>) {
              // Merge profundo para defaults
              final existingDefaults =
                  mergedProvider['defaults'] as Map<String, dynamic>;
              mergedProvider['defaults'] = {
                ...existingDefaults,
                ...overrideValue
              };
            } else {
              // Merge normal para otros campos
              mergedProvider[overrideKey] = overrideValue;
            }
          }

          existingProviders[providerKey] = mergedProvider;
          AILogger.d(
              'Applied overrides for provider "$providerKey": ${overrides.keys}');
        } else {
          AILogger.w(
              'Environment override specified for unknown provider: $providerKey');
        }
      }
    }

    return result;
  }

  /// Validate environment variables and return missing ones
  /// Validate that required environment variables are available
  static void _validateEnvironmentVariables(
      final Map<String, dynamic> configMap) {
    // Skip validation during tests
    if (skipEnvironmentValidation) {
      return;
    }

    final errors = <String>[];
    final providers = configMap['ai_providers'] as Map<String, dynamic>;

    for (final entry in providers.entries) {
      final providerKey = entry.key;
      final providerConfig = entry.value as Map<String, dynamic>;

      // Skip disabled providers
      if (providerConfig['enabled'] != true) continue;

      // Check required environment variables
      final apiSettings =
          providerConfig['api_settings'] as Map<String, dynamic>?;
      if (apiSettings != null) {
        final requiredEnvKeys = apiSettings['required_env_keys'] as List?;
        if (requiredEnvKeys != null) {
          for (final envKey in requiredEnvKeys) {
            final envValue = _getEnvVar(envKey.toString());
            if (envValue.isEmpty) {
              errors.add(
                  'Provider "$providerKey" requires environment variable: $envKey');
            }
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      throw ConfigurationLoadException(
        'Environment validation failed:\n${errors.join('\n')}\n\n'
        'Please ensure all required environment variables are set.',
      );
    }
  }

  /// Validate provider health (basic checks)
  static Future<Map<String, bool>> validateProviderHealth(
      final AIProvidersConfig config) async {
    final results = <String, bool>{};

    for (final entry in config.aiProviders.entries) {
      final providerKey = entry.key;
      final provider = entry.value;

      if (!provider.enabled) {
        results[providerKey] = false;
        continue;
      }

      try {
        // Basic validation - check if required environment variables exist
        bool isHealthy = true;
        for (final envKey in provider.apiSettings.requiredEnvKeys) {
          final envValue = _getEnvVar(envKey);
          if (envValue.isEmpty) {
            isHealthy = false;
            break;
          }
        }

        results[providerKey] = isHealthy;
        AILogger.d(
            'Provider "$providerKey" health check: ${isHealthy ? 'PASS' : 'FAIL'}');
      } on Exception catch (e) {
        AILogger.e('Health check failed for provider "$providerKey"', error: e);
        results[providerKey] = false;
      }
    }

    return results;
  }

  /// Get provider ID for a model using prefix mapping
  static String? getProviderIdForModel(final String modelId) {
    final normalized = modelId.trim().toLowerCase();

    // Use auto-registry for model mapping if available
    try {
      final providerId =
          ProviderRegistry.instance.getProviderForModel(normalized);
      if (providerId != null) {
        return providerId;
      }
    } on Exception catch (e) {
      AILogger.w('Failed to get provider from auto-registry: $e');
    }

    // 🚀 DINÁMICO: Fallback dinámico sin hardcodear nombres específicos de modelos
    // Intentar encontrar el proveedor mediante los proveedores disponibles
    try {
      final config = _ensureConfigLoaded();
      final providers = config['ai_providers'] as Map<String, dynamic>?;
      if (providers != null) {
        // Buscar en todos los proveedores disponibles
        for (final entry in providers.entries) {
          final providerId = entry.key;
          if (providerId.isNotEmpty &&
              normalized.contains(providerId.toLowerCase())) {
            return providerId;
          }
        }
      }
    } on Exception catch (e) {
      AILogger.w('Error en fallback dinámico: $e');
    }

    return null;
  }

  /// Get all model prefixes from configuration
  static Map<String, List<String>> getAllModelPrefixes() {
    final result = <String, List<String>>{};

    try {
      for (final providerId
          in ProviderRegistry.instance.getRegisteredProviders()) {
        final prefixes = ProviderRegistry.instance.getModelPrefixes(providerId);
        if (prefixes != null && prefixes.isNotEmpty) {
          result[providerId] = prefixes;
        }
      }
    } on Exception catch (e) {
      AILogger.w('Failed to get model prefixes from auto-registry: $e');
    }

    return result;
  }

  // --- Audio and Voice Configuration ---

  /// Get default audio provider based on capability
  static String getDefaultAudioProvider() {
    try {
      AILogger.d('[DEBUG] getDefaultAudioProvider() called');
      final config = _ensureConfigLoaded();
      final providers = config['ai_providers'] as Map<String, dynamic>? ?? {};
      AILogger.d('[DEBUG] Found ${providers.length} providers in config');

      // Find providers with audio generation capability
      final audioProviders = <String>[];

      for (final entry in providers.entries) {
        final providerId = entry.key;
        final providerConfig = entry.value as Map<String, dynamic>? ?? {};
        final capabilities = (providerConfig['capabilities'] as List<dynamic>?)
                ?.cast<String>() ??
            [];
        final enabled = providerConfig['enabled'] as bool? ?? false;

        AILogger.d(
            '[DEBUG] Provider $providerId: enabled=$enabled, capabilities=$capabilities');

        if (enabled && capabilities.contains('audio_generation')) {
          audioProviders.add(providerId);
          AILogger.d('[DEBUG] Added $providerId to audio providers list');
        }
      }

      AILogger.d('[DEBUG] Audio providers found: $audioProviders');

      // Return first available provider (capability_preferences will handle order)
      final result = audioProviders.isNotEmpty ? audioProviders.first : '';
      AILogger.d('[DEBUG] getDefaultAudioProvider() returning: "$result"');
      return result;
    } on Exception catch (e) {
      AILogger.w('Failed to get default audio provider: $e');
      return ''; // No fallback hardcodeado - dejar que el caller maneje provider vacío
    }
  }

  /// Get available voices for a provider (DEPRECATED - use provider.getAvailableVoices() instead)
  /// This method now returns empty list - voices should be obtained from provider directly
  static List<String> getVoicesForProvider(final String providerId) {
    AILogger.w(
        'getVoicesForProvider is deprecated. Use provider.getAvailableVoices() instead.');
    return []; // Las voces ahora se obtienen dinámicamente del provider
  }

  /// Get default voice from the currently selected/default audio provider
  /// Método dinámico que evita hardcoding de providers
  static String? getDefaultVoiceFromCurrentProvider() {
    try {
      // Primero intentar usar la configuración del AIProviderManager si está inicializado
      final manager = AIProviderManager.instance;
      if (manager.isInitialized && manager.config != null) {
        final config = manager.config!;
        final currentProvider = getDefaultAudioProvider();
        if (currentProvider.isNotEmpty) {
          final providerConfig = config.aiProviders[currentProvider];
          final voices = providerConfig?.voices ?? {};
          return voices['default'];
        }
      }

      // Fallback: usar configuración cacheada localmente
      final config = _ensureConfigLoaded();
      final currentProvider = getDefaultAudioProvider();
      if (currentProvider.isNotEmpty) {
        final providers = config['ai_providers'] as Map<String, dynamic>? ?? {};
        final providerConfig =
            providers[currentProvider] as Map<String, dynamic>? ?? {};
        final voices = providerConfig['voices'] as Map<String, dynamic>? ?? {};
        return voices['default'] as String?;
      }

      AILogger.w('No default audio provider configured');
      return null;
    } on Exception catch (e) {
      AILogger.w('Failed to get default voice from current provider: $e');
      return null;
    }
  }

  /// Get default voice for a specific provider
  static String? getDefaultVoiceForProvider(final String providerId) {
    try {
      // Primero intentar usar la configuración del AIProviderManager si está inicializado
      final manager = AIProviderManager.instance;
      if (manager.isInitialized && manager.config != null) {
        final config = manager.config!;
        final providerConfig = config.aiProviders[providerId];
        final voices = providerConfig?.voices ?? {};
        return voices['default'];
      }

      // Fallback: usar configuración cacheada localmente
      final config = _ensureConfigLoaded();
      final providers = config['ai_providers'] as Map<String, dynamic>? ?? {};
      final providerConfig =
          providers[providerId] as Map<String, dynamic>? ?? {};
      final voices = providerConfig['voices'] as Map<String, dynamic>? ?? {};
      return voices['default'] as String?;
    } on Exception catch (e) {
      AILogger.w('Failed to get default voice for provider $providerId: $e');
      return null;
    }
  }

  // --- TTS Display Configuration Methods ---

  /// Get TTS display name for provider from YAML configuration
  static String getTtsProviderDisplayName(final String providerId) {
    try {
      final config = _ensureConfigLoaded();

      // android_native is now in ai_providers section - no special case needed

      // Regular providers
      final providers = config['ai_providers'] as Map<String, dynamic>? ?? {};
      final providerConfig =
          providers[providerId] as Map<String, dynamic>? ?? {};
      final ttsDisplay =
          providerConfig['tts_display'] as Map<String, dynamic>? ?? {};

      return ttsDisplay['name'] as String? ??
          _createFallbackDisplayName(providerId);
    } on Exception catch (e) {
      AILogger.w('Failed to get TTS display name for provider $providerId: $e');
      return _createFallbackDisplayName(providerId);
    }
  }

  /// Create a safe fallback display name for TTS providers
  static String _createFallbackDisplayName(final String providerId) {
    if (providerId.isEmpty) {
      return 'TTS Provider';
    }
    return '${providerId[0].toUpperCase()}${providerId.substring(1)} TTS';
  }

  /// Get TTS provider description from YAML configuration
  static String getTtsProviderDescription(final String providerId) {
    try {
      final config = _ensureConfigLoaded();

      // android_native is now in ai_providers section - no special case needed

      // Regular providers
      final providers = config['ai_providers'] as Map<String, dynamic>? ?? {};
      final providerConfig =
          providers[providerId] as Map<String, dynamic>? ?? {};
      final ttsDisplay =
          providerConfig['tts_display'] as Map<String, dynamic>? ?? {};

      return ttsDisplay['description'] as String? ??
          'Proveedor de síntesis de voz dinámico';
    } on Exception catch (e) {
      AILogger.w('Failed to get TTS description for provider $providerId: $e');
      return 'Proveedor de síntesis de voz dinámico';
    }
  }

  /// Get TTS subtitle template from YAML configuration
  static String getTtsProviderSubtitleTemplate(final String providerId) {
    try {
      final config = _ensureConfigLoaded();

      // android_native is now in ai_providers section - no special case needed

      // Regular providers
      final providers = config['ai_providers'] as Map<String, dynamic>? ?? {};
      final providerConfig =
          providers[providerId] as Map<String, dynamic>? ?? {};
      final ttsDisplay =
          providerConfig['tts_display'] as Map<String, dynamic>? ?? {};

      return ttsDisplay['subtitle_template'] as String? ??
          '{voice_count} voces disponibles';
    } on Exception catch (e) {
      AILogger.w(
          'Failed to get TTS subtitle template for provider $providerId: $e');
      return '{voice_count} voces disponibles';
    }
  }

  /// Get TTS not configured subtitle from YAML configuration (for Google primarily)
  static String getTtsProviderNotConfiguredSubtitle(final String providerId) {
    try {
      final config = _ensureConfigLoaded();
      final providers = config['ai_providers'] as Map<String, dynamic>? ?? {};
      final providerConfig =
          providers[providerId] as Map<String, dynamic>? ?? {};
      final ttsDisplay =
          providerConfig['tts_display'] as Map<String, dynamic>? ?? {};

      return ttsDisplay['subtitle_not_configured'] as String? ??
          'No configurado';
    } on Exception catch (e) {
      AILogger.w(
          'Failed to get TTS not configured subtitle for provider $providerId: $e');
      return 'No configurado';
    }
  }

  /// Create AIInitConfig automatically from environment variables (.env)
  /// This method extracts API keys from .env and creates a proper AIInitConfig
  static AIInitConfig createInitConfigFromEnv() {
    try {
      AILogger.i(
          'Creating AIInitConfig automatically from environment variables');

      final Map<String, List<String>> apiKeys = {};

      // Get configuration from cached config to read required_env_keys dynamically
      final yamlConfig = _ensureConfigLoaded();
      final providers =
          yamlConfig['ai_providers'] as Map<String, dynamic>? ?? {};

      // Iterate through all providers and extract their required environment keys
      for (final entry in providers.entries) {
        final providerId = entry.key;
        final providerConfig = entry.value as Map<String, dynamic>? ?? {};

        // Skip disabled providers
        if (providerConfig['enabled'] != true) continue;

        final apiSettings =
            providerConfig['api_settings'] as Map<String, dynamic>? ?? {};
        final requiredEnvKeys =
            apiSettings['required_env_keys'] as List<dynamic>? ?? [];

        // Extract API keys for this provider
        for (final envKey in requiredEnvKeys) {
          final envKeyStr = envKey.toString();
          final envValue = _getEnvVar(envKeyStr);

          if (envValue.isNotEmpty) {
            final keys = _parseApiKeysFromEnv(envValue);
            if (keys.isNotEmpty) {
              apiKeys[providerId] = keys;
              AILogger.i(
                  '✅ Found ${keys.length} API key(s) for $providerId from $envKeyStr');
            }
          } else {
            AILogger.d(
                '⚠️ No value found for $envKeyStr (provider: $providerId)');
          }
        }
      }

      final initConfig = AIInitConfig(
        apiKeys: apiKeys.isNotEmpty ? apiKeys : null,
      );

      AILogger.i(
          '🎉 Created AIInitConfig from .env: ${apiKeys.length} providers configured');
      return initConfig;
    } catch (e) {
      AILogger.w('Failed to create AIInitConfig from .env: $e');
      // Return minimal config on error
      return const AIInitConfig();
    }
  }

  /// Parse API keys from environment variable (supports JSON array format)
  /// Format: ["key1", "key2"] or just "key1"
  static List<String> _parseApiKeysFromEnv(String envValue) {
    try {
      envValue = envValue.trim();

      // If it looks like a JSON array, parse it
      if (envValue.startsWith('[') && envValue.endsWith(']')) {
        final dynamic parsed = json.decode(envValue);
        if (parsed is List) {
          return parsed
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }

      // Otherwise, treat as single key
      if (envValue.isNotEmpty) {
        return [envValue];
      }

      return [];
    } catch (e) {
      AILogger.w('Failed to parse API keys from env value "$envValue": $e');
      // Try to return as single key if JSON parsing fails
      return envValue.trim().isNotEmpty ? [envValue.trim()] : [];
    }
  }
}
