/// Dynamic API Key Management System with automatic fallback.
/// Supports multiple API keys per provider with automatic rotation on failure.
library;

import '../models/ai_init_config.dart';
import '../utils/logger.dart';

/// Represents the status of an API key
enum ApiKeyStatus {
  active, // Key is working normally
  failed, // Key failed recently, should not be used
  exhausted, // Key hit rate limits
  invalid, // Key is invalid/revoked
}

/// Information about an API key and its current status
class ApiKeyInfo {
  ApiKeyInfo({
    required this.key,
    required this.index,
    this.status = ApiKeyStatus.active,
    this.lastUsed,
    this.lastError,
    this.failureCount = 0,
  });

  final String key;
  final int index;
  ApiKeyStatus status;
  DateTime? lastUsed;
  String? lastError;
  int failureCount;

  /// Check if key is available for use
  bool get isAvailable => status == ApiKeyStatus.active;

  /// Mark key as failed with error details
  void markFailed(final String error) {
    status = ApiKeyStatus.failed;
    lastError = error;
    failureCount++;
    AILogger.w('[ApiKeyManager] Key #$index marked as failed: $error');
  }

  /// Mark key as exhausted (rate limited)
  void markExhausted() {
    status = ApiKeyStatus.exhausted;
    lastError = 'Rate limit exceeded';
    failureCount++;
    AILogger.w(
      '[ApiKeyManager] Key #$index marked as exhausted (rate limited)',
    );
  }

  /// Reset key to active status (session restart)
  void reset() {
    status = ApiKeyStatus.active;
    lastError = null;
    failureCount = 0;
    AILogger.i('[ApiKeyManager] Key #$index reset to active status');
  }

  /// Update last used timestamp
  void markUsed() {
    lastUsed = DateTime.now();
  }

  @override
  String toString() =>
      'ApiKeyInfo(index: $index, status: $status, failures: $failureCount)';
}

/// Dynamic API Key Manager for multiple providers
class ApiKeyManager {
  static final Map<String, List<ApiKeyInfo>> _providerKeys = {};
  static final Map<String, int> _currentKeyIndex = {};
  static AIInitConfig? _config;

  /// Initialize API Key Manager with configuration
  static void initialize(final AIInitConfig config) {
    _config = config;
    // Clear cached keys when configuration changes
    _providerKeys.clear();
    _currentKeyIndex.clear();
  }

  /// Load API keys for a provider from injected configuration
  static List<ApiKeyInfo> loadKeysForProvider(final String providerId) {
    final cacheKey = providerId.toLowerCase();

    // Return cached keys if available
    if (_providerKeys.containsKey(cacheKey)) {
      return _providerKeys[cacheKey]!;
    }

    final keys = <ApiKeyInfo>[];

    try {
      // Check if configuration is available
      if (_config == null) {
        AILogger.w(
          '[ApiKeyManager] No configuration available, call initialize() first',
        );
        return keys;
      }

      // Get API keys from injected configuration
      final configKeys = _config!.getApiKeysForProvider(providerId);

      // Convert to ApiKeyInfo objects
      for (int i = 0; i < configKeys.length; i++) {
        final key = configKeys[i].trim();
        if (key.isNotEmpty) {
          keys.add(ApiKeyInfo(key: key, index: i));
        }
      }

      if (keys.isNotEmpty) {
        AILogger.i(
          '[ApiKeyManager] Loaded ${keys.length} keys for $providerId from injected config',
        );
      } else {
        AILogger.w(
          '[ApiKeyManager] No API keys found for provider: $providerId',
        );
      }

      // Cache the keys
      _providerKeys[cacheKey] = keys;

      if (keys.isNotEmpty) {
        _currentKeyIndex[cacheKey] = 0;
      }
    } on Exception catch (e) {
      AILogger.e('[ApiKeyManager] Error loading keys for $providerId: $e');
    }

    return keys;
  }

  /// Get the next available API key for a provider
  static String? getNextAvailableKey(final String providerId) {
    final keys = loadKeysForProvider(providerId);
    if (keys.isEmpty) return null;

    final cacheKey = providerId.toLowerCase();
    final currentIndex = _currentKeyIndex[cacheKey] ?? 0;

    // Try to find an available key starting from current index
    for (int i = 0; i < keys.length; i++) {
      final index = (currentIndex + i) % keys.length;
      final keyInfo = keys[index];

      if (keyInfo.isAvailable) {
        _currentKeyIndex[cacheKey] = index;
        keyInfo.markUsed();

        AILogger.d('[ApiKeyManager] Using key #$index for $providerId');
        return keyInfo.key;
      }
    }

    AILogger.w('[ApiKeyManager] No available keys for provider: $providerId');
    return null;
  }

  /// Mark current key as failed and rotate to next
  static void markCurrentKeyFailed(
    final String providerId,
    final String error,
  ) {
    final keys = loadKeysForProvider(providerId);
    if (keys.isEmpty) return;

    final cacheKey = providerId.toLowerCase();
    final currentIndex = _currentKeyIndex[cacheKey] ?? 0;

    if (currentIndex < keys.length) {
      keys[currentIndex].markFailed(error);

      // Move to next key for next request
      _currentKeyIndex[cacheKey] = (currentIndex + 1) % keys.length;

      AILogger.i(
        '[ApiKeyManager] Rotated $providerId to next key after failure',
      );
    }
  }

  /// Mark current key as rate limited
  static void markCurrentKeyExhausted(final String providerId) {
    final keys = loadKeysForProvider(providerId);
    if (keys.isEmpty) return;

    final cacheKey = providerId.toLowerCase();
    final currentIndex = _currentKeyIndex[cacheKey] ?? 0;

    if (currentIndex < keys.length) {
      keys[currentIndex].markExhausted();

      // Move to next key for next request
      _currentKeyIndex[cacheKey] = (currentIndex + 1) % keys.length;

      AILogger.i(
        '[ApiKeyManager] Rotated $providerId to next key after rate limit',
      );
    }
  }

  /// Get statistics for a provider
  static Map<String, dynamic> getProviderStats(final String providerId) {
    final keys = loadKeysForProvider(providerId);
    final stats = <String, dynamic>{
      'total_keys': keys.length,
      'active_keys':
          keys.where((final k) => k.status == ApiKeyStatus.active).length,
      'failed_keys':
          keys.where((final k) => k.status == ApiKeyStatus.failed).length,
      'exhausted_keys':
          keys.where((final k) => k.status == ApiKeyStatus.exhausted).length,
      'invalid_keys':
          keys.where((final k) => k.status == ApiKeyStatus.invalid).length,
      'current_index': _currentKeyIndex[providerId.toLowerCase()] ?? 0,
    };

    return stats;
  }

  /// Get current key info for debugging
  static ApiKeyInfo? getCurrentKeyInfo(final String providerId) {
    final keys = loadKeysForProvider(providerId);
    if (keys.isEmpty) return null;

    final cacheKey = providerId.toLowerCase();
    final currentIndex = _currentKeyIndex[cacheKey] ?? 0;

    if (currentIndex < keys.length) {
      return keys[currentIndex];
    }

    return null;
  }
}
