/// Basic tests for the YAML Configuration System models and parsing
/// Tests only the basic functionality without complex dependencies
library;

import 'package:ai_providers/ai_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_setup.dart';

void main() {
  setUpAll(() async {
    await initializeTestEnvironment();
  });
  group('AI Provider Configuration Models Tests', () {
    group('ConfigMetadata Tests', () {
      test('should create from map correctly', () {
        final map = {
          'description': 'Test configuration',
          'created': '2024-01-01',
          'last_updated': '2024-01-02'
        };

        final metadata = ConfigMetadata.fromMap(map);

        expect(metadata.description, 'Test configuration');
        expect(metadata.created, '2024-01-01');
        expect(metadata.lastUpdated, '2024-01-02');
      });

      test('should convert to map correctly', () {
        const metadata = ConfigMetadata(
          description: 'Test configuration',
          created: '2024-01-01',
          lastUpdated: '2024-01-02',
        );

        final map = metadata.toMap();

        expect(map['description'], 'Test configuration');
        expect(map['created'], '2024-01-01');
        expect(map['last_updated'], '2024-01-02');
      });
    });

    group('GlobalSettings Tests', () {
      test('should create from map correctly', () {
        final map = {
          'default_timeout_seconds': 30,
          'max_retries': 3,
          'retry_delay_seconds': 2,
          'enable_fallback': true,
          'log_provider_usage': false,
          'debug_mode': true,
        };

        final settings = GlobalSettings.fromMap(map);

        expect(settings.maxRetries, 3);
        expect(settings.retryDelaySeconds, 2);
        expect(settings.ttsCacheEnabled, true);
        expect(settings.ttsCacheDurationHours, 24);
      });

      test('should convert to map correctly', () {
        const settings = GlobalSettings(
          maxRetries: 3,
          retryDelaySeconds: 2,
          ttsCacheEnabled: true,
          ttsCacheDurationHours: 24,
          logLevel: 'warn',
        );

        final map = settings.toMap();

        expect(map['max_retries'], 3);
        expect(map['retry_delay_seconds'], 2);
        expect(map['tts_cache_enabled'], true);
        expect(map['tts_cache_duration_hours'], 24);
      });
    });

    group('ApiSettings Tests', () {
      test('should create from map correctly', () {
        final map = {
          'base_url': 'https://api.example.com',
          'version': 'v1',
          'authentication_type': 'api_key',
          'required_env_keys': ['API_KEY', 'SECRET_KEY'],
        };

        final apiSettings = ApiSettings.fromMap(map);

        expect(apiSettings.baseUrl, 'https://api.example.com');
        expect(apiSettings.version, 'v1');
        expect(apiSettings.authenticationType, 'api_key');
        expect(apiSettings.requiredEnvKeys, ['API_KEY', 'SECRET_KEY']);
      });
    });

    group('ProviderConfig Tests', () {
      test('should create from map correctly', () {
        final map = {
          'enabled': true,
          'display_name': 'Test Provider',
          'description': 'A test provider',
          'capabilities': ['text_generation', 'image_generation'],
          'api_settings': {
            'base_url': 'https://api.example.com',
            'version': 'v1',
            'authentication_type': 'api_key',
            'required_env_keys': ['API_KEY'],
          },
          'models': {
            'text_generation': ['model-1', 'model-2'],
            'image_generation': ['image-model-1'],
          },
          'defaults': {
            'text_generation': 'model-1',
            'image_generation': 'image-model-1'
          },
          'rate_limits': {
            'requests_per_minute': 60,
            'tokens_per_minute': 10000
          },
          'configuration': {
            'max_context_tokens': 4096,
            'max_output_tokens': 2048,
            'supports_streaming': true,
            'supports_function_calling': false,
            'supports_tools': false,
          },
        };

        final provider = ProviderConfig.fromMap(map);

        expect(provider.enabled, true);
        expect(provider.displayName, 'Test Provider');
        expect(provider.description, 'A test provider');
        expect(provider.capabilities,
            [AICapability.textGeneration, AICapability.imageGeneration]);
        expect(provider.apiSettings.baseUrl, 'https://api.example.com');
        expect(provider.models[AICapability.textGeneration],
            ['model-1', 'model-2']);
        expect(provider.defaults[AICapability.textGeneration], 'model-1');
        expect(provider.rateLimits.requestsPerMinute, 60);
        expect(provider.configuration.maxContextTokens, 4096);
      });
    });

    group('FallbackChain Tests', () {
      test('should create from map correctly', () {
        final map = {
          'primary': 'openai',
          'fallbacks': ['google', 'xai'],
        };

        final chain = CapabilityPreference.fromMap(map);

        expect(chain.primary, 'openai');
        expect(chain.fallbacks, ['google', 'xai']);
      });

      test('should convert to map correctly', () {
        const chain = CapabilityPreference(
            primary: 'openai', fallbacks: ['google', 'xai']);

        final map = chain.toMap();

        expect(map['primary'], 'openai');
        expect(map['fallbacks'], ['google', 'xai']);
      });
    });

    group('AIProvidersConfig Tests', () {
      test('should create complete configuration from map', () {
        final configMap = {
          'version': '1.0',
          'metadata': {
            'description': 'Test AI Providers Configuration',
            'created': '2024-01-01',
            'last_updated': '2024-01-02',
          },
          'global_settings': {
            'default_timeout_seconds': 30,
            'max_retries': 3,
            'retry_delay_seconds': 2,
            'enable_fallback': true,
            'log_provider_usage': true,
            'debug_mode': false,
          },
          'ai_providers': {
            'openai': {
              'enabled': true,
              'display_name': 'OpenAI',
              'description': 'OpenAI GPT models',
              'capabilities': ['text_generation'],
              'api_settings': {
                'base_url': 'https://api.openai.com/v1',
                'version': 'v1',
                'authentication_type': 'bearer_token',
                'required_env_keys': ['OPENAI_API_KEY'],
              },
              'models': {
                'text_generation': ['gpt-4', 'gpt-3.5-turbo'],
              },
              'defaults': {'text_generation': 'gpt-4'},
              'rate_limits': {
                'requests_per_minute': 60,
                'tokens_per_minute': 10000
              },
              'configuration': {
                'max_context_tokens': 8192,
                'max_output_tokens': 4096,
                'supports_streaming': true,
                'supports_function_calling': true,
                'supports_tools': true,
              },
            },
          },
          'capability_preferences': {
            'text_generation': {
              'primary': 'openai',
              'fallbacks': ['google'],
            },
          },
        };

        final config = AIProvidersConfig.fromMap(configMap);

        expect(config.version, '1.0');
        expect(config.metadata.description, 'Test AI Providers Configuration');
        expect(config.globalSettings.maxRetries, 3);
        expect(config.aiProviders.length, 1);
        expect(config.aiProviders['openai']?.displayName, 'OpenAI');
        expect(config.capabilityPreferences.length, 1);
        expect(
            config.capabilityPreferences[AICapability.textGeneration]?.primary,
            'openai');
      });

      test('should convert complete configuration to map', () {
        const config = AIProvidersConfig(
          version: '1.0',
          metadata: ConfigMetadata(
              description: 'Test configuration',
              created: '2024-01-01',
              lastUpdated: '2024-01-02'),
          globalSettings: GlobalSettings(
            maxRetries: 3,
            retryDelaySeconds: 2,
            ttsCacheEnabled: true,
            ttsCacheDurationHours: 24,
            logLevel: 'warn',
          ),
          aiProviders: {
            'openai': ProviderConfig(
              enabled: true,
              displayName: 'OpenAI',
              description: 'OpenAI GPT models',
              capabilities: [AICapability.textGeneration],
              apiSettings: ApiSettings(
                baseUrl: 'https://api.openai.com/v1',
                version: 'v1',
                authenticationType: 'bearer_token',
                requiredEnvKeys: ['OPENAI_API_KEY'],
              ),
              models: {
                AICapability.textGeneration: ['gpt-4', 'gpt-3.5-turbo'],
              },
              defaults: {AICapability.textGeneration: 'gpt-4'},
              voices: {},
              rateLimits:
                  RateLimits(requestsPerMinute: 60, tokensPerMinute: 10000),
              configuration: ProviderConfiguration(
                maxContextTokens: 8192,
                maxOutputTokens: 4096,
                supportsStreaming: true,
                supportsFunctionCalling: true,
                supportsTools: true,
              ),
            ),
          },
          capabilityPreferences: {
            AICapability.textGeneration:
                CapabilityPreference(primary: 'openai', fallbacks: ['google']),
          },
        );

        final map = config.toMap();

        expect(map['version'], '1.0');
        expect(map['metadata']['description'], 'Test configuration');
        expect(map['global_settings']['max_retries'], 3);
        expect(map['ai_providers']['openai']['display_name'], 'OpenAI');
        expect(map['capability_preferences']['text_generation']['primary'],
            'openai');
      });
    });

    group('Routing Rules Tests', () {
      test('should create routing rules from map', () {
        final map = {
          'image_generation': {
            'avatar_requests': {
              'preferred_provider': 'openai',
              'fallback_providers': ['google'],
            },
          },
          'text_generation': {
            'long_context': {
              'threshold_tokens': 8000,
              'preferred_provider': 'google',
              'fallback_providers': ['openai'],
            },
          },
        };

        final rules = RoutingRules.fromMap(map);

        expect(
            rules.imageGeneration?.avatarRequests?.preferredProvider, 'openai');
        expect(rules.textGeneration?.longContext?.thresholdTokens, 8000);
      });
    });

    group('Health Check Config Tests', () {
      test('should create health check config from map', () {
        final map = {
          'enabled': true,
          'interval_minutes': 5,
          'timeout_seconds': 10,
          'failure_threshold': 3,
          'success_threshold': 2,
        };

        final healthCheck = HealthCheckConfig.fromMap(map);

        expect(healthCheck.enabled, true);
        expect(healthCheck.intervalMinutes, 5);
        expect(healthCheck.timeoutSeconds, 10);
        expect(healthCheck.failureThreshold, 3);
        expect(healthCheck.successThreshold, 2);
      });
    });
  });
}
