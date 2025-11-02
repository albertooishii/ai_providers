/// Configuration models for the AI Providers YAML configuration system.
/// These models represent the structure of the ai_providers_config.yaml file.
library;

import '../utils/logger.dart';
import './ai_capability.dart';

/// Root configuration model that represents the entire YAML file
class AIProvidersConfig {
  factory AIProvidersConfig.fromMap(final Map<String, dynamic> map) {
    return AIProvidersConfig(
      version: map['version'] as String,
      metadata:
          ConfigMetadata.fromMap(Map<String, dynamic>.from(map['metadata'])),
      globalSettings: GlobalSettings.fromMap(
          Map<String, dynamic>.from(map['global_settings'])),
      aiProviders: Map<String, dynamic>.from(
        map['ai_providers'],
      ).map((final key, final value) => MapEntry(
          key, ProviderConfig.fromMap(Map<String, dynamic>.from(value)))),
      capabilityPreferences:
          Map<String, dynamic>.from(map['capability_preferences']).map(
        (final key, final value) => MapEntry(
          AICapabilityExtension.fromIdentifier(key)!,
          CapabilityPreference.fromMap(Map<String, dynamic>.from(value)),
        ),
      ),
      environments: map['environments'] != null
          ? Map<String, dynamic>.from(map['environments']).map(
              (final key, final value) => MapEntry(key,
                  EnvironmentConfig.fromMap(Map<String, dynamic>.from(value))),
            )
          : {},
      routingRules: map['routing_rules'] != null
          ? RoutingRules.fromMap(
              Map<String, dynamic>.from(map['routing_rules']))
          : null,
      healthChecks: map['health_checks'] != null
          ? HealthCheckConfig.fromMap(
              Map<String, dynamic>.from(map['health_checks']))
          : null,
    );
  }
  const AIProvidersConfig({
    required this.version,
    required this.metadata,
    required this.globalSettings,
    required this.aiProviders,
    required this.capabilityPreferences,
    this.environments = const {},
    this.routingRules,
    this.healthChecks,
  });

  final String version;
  final ConfigMetadata metadata;
  final GlobalSettings globalSettings;
  final Map<String, ProviderConfig> aiProviders;
  final Map<AICapability, CapabilityPreference> capabilityPreferences;
  final Map<String, EnvironmentConfig> environments;
  final RoutingRules? routingRules;
  final HealthCheckConfig? healthChecks;

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'metadata': metadata.toMap(),
      'global_settings': globalSettings.toMap(),
      'ai_providers': aiProviders
          .map((final key, final value) => MapEntry(key, value.toMap())),
      'capability_preferences': capabilityPreferences.map(
          (final key, final value) => MapEntry(key.identifier, value.toMap())),
      if (environments.isNotEmpty)
        'environments': environments
            .map((final key, final value) => MapEntry(key, value.toMap())),
      if (routingRules != null) 'routing_rules': routingRules!.toMap(),
      if (healthChecks != null) 'health_checks': healthChecks!.toMap(),
    };
  }
}

/// Metadata about the configuration file
class ConfigMetadata {
  factory ConfigMetadata.fromMap(final Map<String, dynamic> map) {
    return ConfigMetadata(
      description: map['description'] as String,
      created: map['created'] as String,
      lastUpdated: map['last_updated'] as String,
    );
  }
  const ConfigMetadata(
      {required this.description,
      required this.created,
      required this.lastUpdated});

  final String description;
  final String created;
  final String lastUpdated;

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'created': created,
      'last_updated': lastUpdated
    };
  }
}

/// Global configuration settings
class GlobalSettings {
  factory GlobalSettings.fromMap(final Map<String, dynamic> map) {
    return GlobalSettings(
      maxRetries: map['max_retries'] as int? ?? 3,
      retryDelaySeconds: map['retry_delay_seconds'] as int? ?? 1,
      ttsCacheEnabled: map['tts_cache_enabled'] as bool? ?? true,
      ttsCacheDurationHours: map['tts_cache_duration_hours'] as int? ?? 24,
      logLevel: map['log_level'] as String? ?? 'warn',
    );
  }
  const GlobalSettings({
    required this.maxRetries,
    required this.retryDelaySeconds,
    required this.ttsCacheEnabled,
    required this.ttsCacheDurationHours,
    required this.logLevel,
  });

  final int maxRetries;
  final int retryDelaySeconds;
  final bool ttsCacheEnabled;
  final int ttsCacheDurationHours;
  final String logLevel; // off, error, warn, info, debug

  Map<String, dynamic> toMap() {
    return {
      'max_retries': maxRetries,
      'retry_delay_seconds': retryDelaySeconds,
      'tts_cache_enabled': ttsCacheEnabled,
      'tts_cache_duration_hours': ttsCacheDurationHours,
      'log_level': logLevel,
    };
  }
}

/// Configuration for a specific AI provider
class ProviderConfig {
  factory ProviderConfig.fromMap(final Map<String, dynamic> map) {
    // Debug temporal para ver qué está pasando
    AILogger.d('[ProviderConfig] fromMap - map keys: ${map.keys.toList()}');
    AILogger.d('[ProviderConfig] fromMap - voices: ${map['voices']}');

    return ProviderConfig(
      enabled: map['enabled'] as bool,
      displayName: map['display_name'] as String,
      description: map['description'] as String,
      capabilities: (map['capabilities'] as List)
          .map((final cap) => AICapabilityExtension.fromIdentifier(cap)!)
          .toList(),
      apiSettings: map['api_settings'] != null
          ? ApiSettings.fromMap(Map<String, dynamic>.from(map['api_settings']))
          : ApiSettings.fromMap({}), // Fallback para api_settings null
      models: Map<String, dynamic>.from(map['models'] ?? {}).map(
        (final key, final value) => MapEntry(
            AICapabilityExtension.fromIdentifier(key)!,
            (value as List).cast<String>()),
      ),
      defaults: Map<String, dynamic>.from(
        map['defaults'] ?? {},
      ).map((final key, final value) => MapEntry(
          AICapabilityExtension.fromIdentifier(key)!, value as String)),
      voices: (map['voices'] as List<dynamic>? ?? []).cast<String>(),
      rateLimits: map['rate_limits'] != null
          ? RateLimits.fromMap(Map<String, dynamic>.from(map['rate_limits']))
          : RateLimits.fromMap({}), // Fallback para rate_limits null
      configuration: map['configuration'] != null
          ? ProviderConfiguration.fromMap(
              Map<String, dynamic>.from(map['configuration']))
          : ProviderConfiguration.fromMap(
              {}), // Fallback para configuration null
      // New fields for model_prefixes and endpoints
      modelPrefixes:
          (map['model_prefixes'] as List<dynamic>? ?? []).cast<String>(),
      endpoints: Map<String, dynamic>.from(
        map['endpoints'] ?? {},
      ).map((final key, final value) => MapEntry(key, value as String)),
    );
  }
  const ProviderConfig({
    required this.enabled,
    required this.displayName,
    required this.description,
    required this.capabilities,
    required this.apiSettings,
    required this.models,
    required this.defaults,
    required this.voices,
    required this.rateLimits,
    required this.configuration,
    this.modelPrefixes = const [],
    this.endpoints = const {},
  });

  final bool enabled;
  final String displayName;
  final String description;
  final List<AICapability> capabilities;
  final ApiSettings apiSettings;
  final Map<AICapability, List<String>> models;
  final Map<AICapability, String> defaults;
  final List<String> voices;
  final RateLimits rateLimits;
  final ProviderConfiguration configuration;
  final List<String> modelPrefixes;
  final Map<String, String> endpoints;

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'display_name': displayName,
      'description': description,
      'capabilities': capabilities.map((final cap) => cap.identifier).toList(),
      'api_settings': apiSettings.toMap(),
      'models': models
          .map((final key, final value) => MapEntry(key.identifier, value)),
      'defaults': defaults
          .map((final key, final value) => MapEntry(key.identifier, value)),
      'voices': voices,
      'rate_limits': rateLimits.toMap(),
      'configuration': configuration.toMap(),
      if (modelPrefixes.isNotEmpty) 'model_prefixes': modelPrefixes,
      if (endpoints.isNotEmpty) 'endpoints': endpoints,
    };
  }
}

/// API settings for a provider
class ApiSettings {
  factory ApiSettings.fromMap(final Map<String, dynamic> map) {
    return ApiSettings(
      baseUrl: map['base_url'] as String? ?? '',
      version: map['version'] as String? ?? 'v1',
      authenticationType:
          map['authentication_type'] as String? ?? 'bearer_token',
      requiredEnvKeys:
          (map['required_env_keys'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
  const ApiSettings({
    required this.baseUrl,
    required this.version,
    required this.authenticationType,
    required this.requiredEnvKeys,
  });

  final String baseUrl;
  final String version;
  final String authenticationType;
  final List<String> requiredEnvKeys;

  Map<String, dynamic> toMap() {
    return {
      'base_url': baseUrl,
      'version': version,
      'authentication_type': authenticationType,
      'required_env_keys': requiredEnvKeys,
    };
  }
}

/// Rate limits configuration
class RateLimits {
  factory RateLimits.fromMap(final Map<String, dynamic> map) {
    return RateLimits(
      requestsPerMinute: map['requests_per_minute'] as int? ?? 1000,
      tokensPerMinute: map['tokens_per_minute'] as int? ?? 100000,
    );
  }
  const RateLimits(
      {required this.requestsPerMinute, required this.tokensPerMinute});

  final int requestsPerMinute;
  final int tokensPerMinute;

  Map<String, dynamic> toMap() {
    return {
      'requests_per_minute': requestsPerMinute,
      'tokens_per_minute': tokensPerMinute
    };
  }
}

/// Provider-specific configuration
class ProviderConfiguration {
  factory ProviderConfiguration.fromMap(final Map<String, dynamic> map) {
    return ProviderConfiguration(
      maxContextTokens: map['max_context_tokens'] as int? ?? 4096,
      maxOutputTokens: map['max_output_tokens'] as int? ?? 1024,
      supportsStreaming: map['supports_streaming'] as bool? ?? false,
      supportsFunctionCalling:
          map['supports_function_calling'] as bool? ?? false,
      supportsTools: map['supports_tools'] as bool? ?? false,
      // Store all additional fields for custom provider configurations
      additionalSettings: Map<String, dynamic>.from(map)
        ..removeWhere((final key, final value) {
          // Remove known fields to keep only custom ones
          return [
            'max_context_tokens',
            'max_output_tokens',
            'supports_streaming',
            'supports_function_calling',
            'supports_tools'
          ].contains(key);
        }),
    );
  }
  const ProviderConfiguration({
    required this.maxContextTokens,
    required this.maxOutputTokens,
    required this.supportsStreaming,
    required this.supportsFunctionCalling,
    required this.supportsTools,
    this.additionalSettings = const {},
  });

  final int maxContextTokens;
  final int maxOutputTokens;
  final bool supportsStreaming;
  final bool supportsFunctionCalling;
  final bool supportsTools;
  final Map<String, dynamic> additionalSettings;

  Map<String, dynamic> toMap() {
    return {
      'max_context_tokens': maxContextTokens,
      'max_output_tokens': maxOutputTokens,
      'supports_streaming': supportsStreaming,
      'supports_function_calling': supportsFunctionCalling,
      'supports_tools': supportsTools,
      ...additionalSettings, // Include additional custom settings
    };
  }
}

/// Capability-specific provider preference configuration
class CapabilityPreference {
  factory CapabilityPreference.fromMap(final Map<String, dynamic> map) {
    return CapabilityPreference(
        primary: map['primary'] as String,
        fallbacks: (map['fallbacks'] as List).cast<String>());
  }
  const CapabilityPreference({required this.primary, required this.fallbacks});

  final String primary;
  final List<String> fallbacks;

  Map<String, dynamic> toMap() {
    return {'primary': primary, 'fallbacks': fallbacks};
  }
}

/// Environment-specific configuration overrides
class EnvironmentConfig {
  factory EnvironmentConfig.fromMap(final Map<String, dynamic> map) {
    return EnvironmentConfig(
      globalSettings: map['global_settings'] != null
          ? GlobalSettings.fromMap(
              map['global_settings'] as Map<String, dynamic>)
          : null,
      aiProviders: map['ai_providers'] != null
          ? (map['ai_providers'] as Map<String, dynamic>).map(
              (final key, final value) => MapEntry(
                  key, ProviderConfig.fromMap(value as Map<String, dynamic>)),
            )
          : {},
    );
  }
  const EnvironmentConfig({this.globalSettings, this.aiProviders = const {}});

  final GlobalSettings? globalSettings;
  final Map<String, ProviderConfig> aiProviders;

  Map<String, dynamic> toMap() {
    return {
      if (globalSettings != null) 'global_settings': globalSettings!.toMap(),
      if (aiProviders.isNotEmpty)
        'ai_providers': aiProviders
            .map((final key, final value) => MapEntry(key, value.toMap())),
    };
  }
}

/// Advanced routing rules configuration
class RoutingRules {
  factory RoutingRules.fromMap(final Map<String, dynamic> map) {
    return RoutingRules(
      imageGeneration: map['image_generation'] != null
          ? ImageGenerationRouting.fromMap(
              map['image_generation'] as Map<String, dynamic>)
          : null,
      textGeneration: map['text_generation'] != null
          ? TextGenerationRouting.fromMap(
              map['text_generation'] as Map<String, dynamic>)
          : null,
    );
  }
  const RoutingRules({this.imageGeneration, this.textGeneration});

  final ImageGenerationRouting? imageGeneration;
  final TextGenerationRouting? textGeneration;

  Map<String, dynamic> toMap() {
    return {
      if (imageGeneration != null) 'image_generation': imageGeneration!.toMap(),
      if (textGeneration != null) 'text_generation': textGeneration!.toMap(),
    };
  }
}

/// Image generation routing rules
class ImageGenerationRouting {
  factory ImageGenerationRouting.fromMap(final Map<String, dynamic> map) {
    return ImageGenerationRouting(
      avatarRequests: map['avatar_requests'] != null
          ? RoutingRule.fromMap(map['avatar_requests'] as Map<String, dynamic>)
          : null,
      creativeRequests: map['creative_requests'] != null
          ? RoutingRule.fromMap(
              map['creative_requests'] as Map<String, dynamic>)
          : null,
    );
  }
  const ImageGenerationRouting({this.avatarRequests, this.creativeRequests});

  final RoutingRule? avatarRequests;
  final RoutingRule? creativeRequests;

  Map<String, dynamic> toMap() {
    return {
      if (avatarRequests != null) 'avatar_requests': avatarRequests!.toMap(),
      if (creativeRequests != null)
        'creative_requests': creativeRequests!.toMap(),
    };
  }
}

/// Text generation routing rules
class TextGenerationRouting {
  factory TextGenerationRouting.fromMap(final Map<String, dynamic> map) {
    return TextGenerationRouting(
      longContext: map['long_context'] != null
          ? ContextRoutingRule.fromMap(
              map['long_context'] as Map<String, dynamic>)
          : null,
      shortContext: map['short_context'] != null
          ? ContextRoutingRule.fromMap(
              map['short_context'] as Map<String, dynamic>)
          : null,
    );
  }
  const TextGenerationRouting({this.longContext, this.shortContext});

  final ContextRoutingRule? longContext;
  final ContextRoutingRule? shortContext;

  Map<String, dynamic> toMap() {
    return {
      if (longContext != null) 'long_context': longContext!.toMap(),
      if (shortContext != null) 'short_context': shortContext!.toMap(),
    };
  }
}

/// Basic routing rule
class RoutingRule {
  factory RoutingRule.fromMap(final Map<String, dynamic> map) {
    return RoutingRule(
      preferredProvider: map['preferred_provider'] as String,
      fallbackProviders: (map['fallback_providers'] as List).cast<String>(),
    );
  }
  const RoutingRule(
      {required this.preferredProvider, required this.fallbackProviders});

  final String preferredProvider;
  final List<String> fallbackProviders;

  Map<String, dynamic> toMap() {
    return {
      'preferred_provider': preferredProvider,
      'fallback_providers': fallbackProviders
    };
  }
}

/// Context-based routing rule with threshold
class ContextRoutingRule extends RoutingRule {
  factory ContextRoutingRule.fromMap(final Map<String, dynamic> map) {
    return ContextRoutingRule(
      thresholdTokens: map['threshold_tokens'] as int,
      preferredProvider: map['preferred_provider'] as String,
      fallbackProviders: (map['fallback_providers'] as List).cast<String>(),
    );
  }
  const ContextRoutingRule({
    required this.thresholdTokens,
    required super.preferredProvider,
    required super.fallbackProviders,
  });

  final int thresholdTokens;

  @override
  Map<String, dynamic> toMap() {
    return {...super.toMap(), 'threshold_tokens': thresholdTokens};
  }
}

/// Health check configuration
class HealthCheckConfig {
  factory HealthCheckConfig.fromMap(final Map<String, dynamic> map) {
    return HealthCheckConfig(
      enabled: map['enabled'] as bool,
      intervalMinutes: map['interval_minutes'] as int,
      timeoutSeconds: map['timeout_seconds'] as int,
      failureThreshold: map['failure_threshold'] as int,
      successThreshold: map['success_threshold'] as int,
    );
  }
  const HealthCheckConfig({
    required this.enabled,
    required this.intervalMinutes,
    required this.timeoutSeconds,
    required this.failureThreshold,
    required this.successThreshold,
  });

  final bool enabled;
  final int intervalMinutes;
  final int timeoutSeconds;
  final int failureThreshold;
  final int successThreshold;

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'interval_minutes': intervalMinutes,
      'timeout_seconds': timeoutSeconds,
      'failure_threshold': failureThreshold,
      'success_threshold': successThreshold,
    };
  }
}
