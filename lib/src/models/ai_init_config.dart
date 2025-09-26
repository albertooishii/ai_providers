/// Internal configuration model for AI Providers initialization.
/// This model defines the clean interface for external configuration injection.
library;

/// Configuration model for initializing AI Providers system from external sources.
/// This model is designed to be simple and focused only on what ai_providers needs.
class AIInitConfig {
  const AIInitConfig({
    this.apiKeys,
  });

  /// Create empty configuration (useful for testing)
  const AIInitConfig.empty() : apiKeys = const {};

  /// Create configuration with specific providers
  AIInitConfig.withProviders(
    final Map<String, List<String>> providers,
  ) : apiKeys = Map.unmodifiable(providers);

  /// API keys organized by provider ID.
  /// Format: {"openai": ["key1", "key2"], "google": ["key1"]}
  /// If null, the system will try to load API keys from environment variables (.env)
  final Map<String, List<String>>? apiKeys;

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
    return 'AIInitConfig(providers: $providerCounts)';
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    return other is AIInitConfig && _mapEquals(other.apiKeys, apiKeys);
  }

  @override
  int get hashCode => _mapHashCode(apiKeys);

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
