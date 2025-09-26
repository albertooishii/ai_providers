/// Internal configuration model for AI Providers initialization.
/// This model defines the clean interface for external configuration injection.
library;

/// Configuration model for initializing AI Providers system from external sources.
/// This model is designed to be simple and focused only on what ai_providers needs.
class AIInitConfig {
  const AIInitConfig({
    this.apiKeys,
    this.appDirectoryName = 'ai_providers_app',
  });

  /// Create empty configuration (useful for testing)
  const AIInitConfig.empty()
      : apiKeys = const {},
        appDirectoryName = 'ai_providers_app';

  /// Create configuration with specific providers
  AIInitConfig.withProviders(
    final Map<String, List<String>> providers, {
    final String? appDirectoryName,
  })  : apiKeys = Map.unmodifiable(providers),
        appDirectoryName = appDirectoryName ?? 'ai_providers_app';

  /// API keys organized by provider ID.
  /// Format: {"openai": ["key1", "key2"], "google": ["key1"]}
  /// If null, the system will try to load API keys from environment variables (.env)
  final Map<String, List<String>>? apiKeys;

  /// Directory name for storing media files (images, audio).
  /// This allows the ai_providers package to be app-agnostic.
  /// Files will be stored in: {documents}/{appDirectoryName}/images/ and {documents}/{appDirectoryName}/audio/
  final String appDirectoryName;

  /// Get API keys for a specific provider
  List<String> getApiKeysForProvider(final String providerId) {
    return apiKeys?[providerId] ?? [];
  }

  /// Check if provider has any configured API keys
  bool hasApiKeysForProvider(final String providerId) {
    final keys = apiKeys?[providerId];
    return keys != null && keys.isNotEmpty;
  }

  /// Get all configured provider IDs
  Set<String> get configuredProviders => apiKeys?.keys.toSet() ?? {};

  @override
  String toString() {
    final providerCounts = apiKeys?.map(
          (final key, final value) => MapEntry(key, value.length),
        ) ??
        {};
    return 'AIInitConfig(providers: $providerCounts, appDirectory: $appDirectoryName)';
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    return other is AIInitConfig &&
        _mapEquals(other.apiKeys, apiKeys) &&
        other.appDirectoryName == appDirectoryName;
  }

  @override
  int get hashCode => Object.hash(_mapHashCode(apiKeys), appDirectoryName);

  // Helper methods for deep map comparison
  static bool _mapEquals<K, V>(final Map<K, V>? a, final Map<K, V>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;

    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final aValue = a[key];
      final bValue = b[key];

      if (aValue is List && bValue is List) {
        if (aValue.length != bValue.length) return false;
        for (int i = 0; i < aValue.length; i++) {
          if (aValue[i] != bValue[i]) return false;
        }
      } else if (aValue != bValue) {
        return false;
      }
    }
    return true;
  }

  static int _mapHashCode<K, V>(final Map<K, V>? map) {
    if (map == null) return 0;
    var hash = 0;
    for (final entry in map.entries) {
      final keyHash = entry.key.hashCode;
      final valueHash = entry.value is List
          ? Object.hashAll(entry.value as List)
          : entry.value.hashCode;
      hash ^= Object.hash(keyHash, valueHash);
    }
    return hash;
  }
}
