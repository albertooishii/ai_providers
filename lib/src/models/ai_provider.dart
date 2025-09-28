/// Simple AI Provider model for public API.
library;

/// This is different from ProviderConfig which handles YAML configuration.

import './ai_capability.dart';

/// Simple AI Provider model for public API exposure.
///
/// This model represents a simplified view of an AI provider for external consumption,
/// containing only the essential information that users need when working with providers.
/// It's different from [ProviderConfig] which is used for internal YAML configuration management.
class AIProvider {
  /// Creates an AIProvider from a Map (for deserialization)
  factory AIProvider.fromMap(final Map<String, dynamic> map) {
    return AIProvider(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      description: map['description'] as String,
      capabilities: (map['capabilities'] as List)
          .map((final cap) => AICapabilityExtension.fromIdentifier(cap)!)
          .toList(),
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  /// Creates an AIProvider instance.
  const AIProvider({
    required this.id,
    required this.displayName,
    required this.description,
    required this.capabilities,
    this.enabled = true,
  });

  /// Creates an empty/fallback AIProvider with minimal information.
  ///
  /// Useful for error cases or when a provider is not found.
  factory AIProvider.empty(final String id) {
    return AIProvider(
      id: id,
      displayName: id.isNotEmpty ? id.toUpperCase() : 'Unknown',
      description: 'Provider information not available',
      capabilities: const [],
      enabled: false,
    );
  }

  /// Converts a ProviderConfig (from YAML) to a simple AIProvider (for API).
  ///
  /// This factory method bridges the internal configuration model with the public API model.
  factory AIProvider.fromConfig({
    required final String id,
    required final dynamic
        config, // ProviderConfig from ai_provider_config.dart
  }) {
    try {
      return AIProvider(
        id: id,
        displayName: config.displayName as String,
        description: config.description as String,
        capabilities: List<AICapability>.from(config.capabilities as List),
        enabled: config.enabled as bool,
      );
    } on Exception {
      // Fallback to empty provider if conversion fails
      return AIProvider.empty(id);
    }
  }

  /// Unique identifier for the provider (e.g., 'openai', 'google', 'anthropic')
  final String id;

  /// User-friendly display name (e.g., 'OpenAI', 'Google Gemini', 'Anthropic Claude')
  final String displayName;

  /// Brief description of the provider and its capabilities
  final String description;

  /// List of AI capabilities this provider supports
  final List<AICapability> capabilities;

  /// Whether the provider is currently enabled and available
  final bool enabled;

  /// Checks if this provider supports a specific capability
  bool supportsCapability(final AICapability capability) {
    return capabilities.contains(capability);
  }

  /// Returns a Map representation for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'description': description,
      'capabilities': capabilities.map((final cap) => cap.identifier).toList(),
      'enabled': enabled,
    };
  }

  @override
  String toString() {
    return 'AIProvider(id: $id, displayName: $displayName, enabled: $enabled, capabilities: ${capabilities.length})';
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    return other is AIProvider &&
        other.id == id &&
        other.displayName == displayName &&
        other.description == description &&
        other.enabled == enabled;
  }

  @override
  int get hashCode {
    return Object.hash(id, displayName, description, enabled);
  }
}
