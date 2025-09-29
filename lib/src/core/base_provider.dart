import '../infrastructure/api_key_manager.dart';
import '../models/ai_capability.dart';
import '../models/ai_provider_config.dart';
import '../models/ai_provider_metadata.dart';
import '../models/provider_response.dart';
import '../models/ai_system_prompt.dart';
// provider_interface.dart removed - no more abstract interfaces!
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

/// Base class for all AI providers to eliminate code duplication
/// Contains common functionality and enforces YAML-only configuration
abstract class BaseProvider {
  BaseProvider(this.config) {
    _metadata = createMetadata();
  }
  final ProviderConfig config;
  late final AIProviderMetadata _metadata;
  bool _initialized = false;

  /// Each provider must implement their own metadata creation
  AIProviderMetadata createMetadata();

  /// Provider-specific constants from YAML config
  String get providerId;

  /// Default values - can be overridden by providers
  Map<String, dynamic> get defaults => {
        'image_mime_type': 'image/png',
        'audio_format': 'mp3',
        'avatar_size': '1024x1024',
        'transcription_model': config.defaults[AICapability.audioTranscription],
      };

  /// Get API endpoint URL from config (fail fast if not defined)
  String getEndpointUrl(final String endpointKey) {
    final baseUrl = config.apiSettings.baseUrl;
    final endpoint = config.endpoints[endpointKey];

    if (endpoint == null || endpoint.isEmpty) {
      throw Exception(
          'Endpoint "$endpointKey" not found in YAML configuration for $providerId provider');
    }

    // Handle full URLs (e.g., for different domains)
    if (endpoint.startsWith('http')) {
      return endpoint;
    }
    return '$baseUrl$endpoint';
  }

  /// Get API key with rotation support
  String get apiKey {
    final key = ApiKeyManager.getNextAvailableKey(providerId);
    if (key == null || key.isEmpty) {
      // Usar StateError para indicar que no se debe hacer retry
      throw StateError(
        '🔑 All $providerId API keys exhausted - switching to fallback provider',
      );
    }
    return key;
  }

  /// Common validation for model prefixes from YAML
  bool isValidModelForProvider(final String model) {
    final modelLower = model.toLowerCase();
    return config.modelPrefixes
        .any((final prefix) => modelLower.startsWith(prefix.toLowerCase()));
  }

  /// Get default voice from YAML config
  String getDefaultVoice() {
    return config.voices['default'] ??
        config.voices['tts_default'] ??
        _getProviderSpecificDefaultVoice();
  }

  /// Each provider can override this for their specific default
  String _getProviderSpecificDefaultVoice() => 'default';

  /// Create data URI for images with proper MIME type from config
  String createImageDataUri(
      final String imageBase64, final String? imageMimeType) {
    final mimeType = imageMimeType ?? defaults['image_mime_type'];
    return 'data:$mimeType;base64,$imageBase64';
  }

  /// Validate endpoint response
  bool isSuccessfulResponse(final int statusCode) => statusCode == 200;

  /// Common error handling
  /// Returns true if provider can retry, false if all keys exhausted
  bool handleApiError(
      final int statusCode, final String body, final String operation) {
    AILogger.e(
        '[$providerId] API Error - Operation: $operation, Status: $statusCode, Body: $body');

    switch (statusCode) {
      case 401:
        final hasMoreKeys = ApiKeyManager.markCurrentKeyFailed(
            providerId, 'Invalid API key (401)');
        if (!hasMoreKeys) {
          throw Exception('All API keys invalid for $providerId');
        }
        throw Exception('Invalid API key');
      case 429:
        final hasMoreKeys = ApiKeyManager.markCurrentKeyExhausted(providerId);
        if (!hasMoreKeys) {
          throw Exception('All API keys rate limited for $providerId');
        }
        throw Exception('Rate limit exceeded');
      case 402:
        final hasMoreKeys = ApiKeyManager.markCurrentKeyFailed(
            providerId, 'Payment required (402)');
        if (!hasMoreKeys) {
          throw Exception('All API keys require payment for $providerId');
        }
        throw Exception('Payment required');
      case 403:
        final hasMoreKeys = ApiKeyManager.markCurrentKeyFailed(
            providerId, 'Access forbidden (403)');
        if (!hasMoreKeys) {
          throw Exception('All API keys forbidden for $providerId');
        }
        throw Exception('Access forbidden');
      default:
        AILogger.w(
            '[$providerId] ⚠️ API error $statusCode for operation: $operation');
        return true;
    }
  }

  // Common interface implementations
  String get providerName => config.displayName;

  String get version => '1.0.0';

  AIProviderMetadata get metadata => _metadata;

  List<AICapability> get supportedCapabilities =>
      _metadata.supportedCapabilities;

  Map<AICapability, List<String>> get availableModels =>
      _metadata.availableModels;

  String? getDefaultModel(final AICapability capability) =>
      _metadata.getDefaultModel(capability);

  bool supportsCapability(final AICapability capability) =>
      supportedCapabilities.contains(capability);

  bool supportsModel(final AICapability capability, final String model) {
    final models = _metadata.getAvailableModels(capability);
    return models.contains(model);
  }

  Map<String, int> getRateLimits() => _metadata.rateLimits;

  Future<bool> initialize(final Map<String, dynamic> config) async {
    if (_initialized) return true;

    try {
      _initialized = await isHealthy();
      return _initialized;
    } on Exception catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    _initialized = false;
  }

  /// Health check using models endpoint - common pattern
  Future<bool> isHealthy() async {
    try {
      if (apiKey.trim().isEmpty) return false;

      final url = Uri.parse(getEndpointUrl('models'));
      final headers = buildAuthHeaders();
      final response = await http.Client().get(url, headers: headers);

      return isSuccessfulResponse(response.statusCode);
    } on Exception catch (_) {
      return false;
    }
  }

  /// Build authentication headers - provider specific
  Map<String, String> buildAuthHeaders();

  /// Fetch models from API - provider specific implementation
  Future<List<String>?> fetchModelsFromAPI();

  /// Filter models based on provider prefixes from YAML
  List<String> filterModelsForProvider(final List<String> allModels) {
    return allModels
        .where((final model) => isValidModelForProvider(model))
        .toList()
      ..sort(compareModels);
  }

  /// Model comparison - provider specific
  int compareModels(final String a, final String b);

  /// Abstract method for sending messages - each provider implements their own logic
  /// Uses typed AISystemPrompt for better type safety
  Future<ProviderResponse> sendMessage({
    required final List<Map<String, String>> history,
    required final AISystemPrompt systemPrompt,
    required final AICapability capability,
    final String? model,
    final String? imageBase64,
    final String? imageMimeType,
    final Map<String, dynamic>? additionalParams,
  });
}
