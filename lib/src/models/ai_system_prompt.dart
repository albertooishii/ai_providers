/// Generic internal system prompt model for AI providers.
/// Designed to be completely portable and work with any AI application.
library;

import 'dart:convert';

/// Generic system prompt that works with any AI application.
/// No external dependencies - completely self-contained.
class AISystemPrompt {
  const AISystemPrompt({
    required this.context,
    required this.dateTime,
    this.history,
    required this.instructions,
  });

  /// Factory constructor from JSON
  factory AISystemPrompt.fromJson(final Map<String, dynamic> json) {
    return AISystemPrompt(
      context: json['context'] ?? <String, dynamic>{},
      dateTime: DateTime.parse(
        json['dateTime'] ?? DateTime.now().toIso8601String(),
      ),
      history: json['history'] != null
          ? (json['history'] as List<dynamic>)
              .map((final e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : null,
      instructions: json['instructions'] is Map
          ? Map<String, dynamic>.from(json['instructions'] as Map)
          : <String, dynamic>{},
    );
  }

  /// Flexible context - can be user profile, session data, app state, etc.
  /// Examples:
  /// - {"user": "John", "mood": "happy"}
  /// - {"sessionId": "123", "theme": "dark"}
  /// - {"userName": "Alice", "aiName": "Assistant", "preferences": {...}}
  /// - Any profile or configuration object
  final dynamic context;

  /// Timestamp for the system prompt
  final DateTime dateTime;

  /// Conversation history for context
  final List<Map<String, dynamic>>? history;

  /// System instructions as structured data
  final Map<String, dynamic> instructions;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'context': context is Map<String, dynamic>
            ? context
            : (context?.toJson?.call() ?? context.toString()),
        'dateTime': dateTime.toIso8601String(),
        if (history != null && history!.isNotEmpty) 'history': history,
        'instructions': instructions,
      };

  /// String representation
  @override
  String toString() => jsonEncode(toJson());

  /// Check if prompt has history
  bool get hasHistory => history != null && history!.isNotEmpty;

  /// Get history count
  int get historyCount => history?.length ?? 0;

  /// Check if context has a specific key
  bool hasContextKey(final String key) {
    if (context is Map<String, dynamic>) {
      return (context as Map<String, dynamic>).containsKey(key);
    }
    return false;
  }

  /// Get context value safely
  T? getContextValue<T>(final String key) {
    if (context is Map<String, dynamic>) {
      final value = (context as Map<String, dynamic>)[key];
      return value is T ? value : null;
    }
    return null;
  }

  /// Create a copy with updated fields
  AISystemPrompt copyWith({
    final dynamic context,
    final DateTime? dateTime,
    final List<Map<String, dynamic>>? history,
    final Map<String, dynamic>? instructions,
  }) {
    return AISystemPrompt(
      context: context ?? this.context,
      dateTime: dateTime ?? this.dateTime,
      history: history ?? this.history,
      instructions: instructions ?? this.instructions,
    );
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    return other is AISystemPrompt &&
        other.context == context &&
        other.dateTime == dateTime &&
        _listEquals(other.history, history) &&
        _mapEquals(other.instructions, instructions);
  }

  @override
  int get hashCode => Object.hash(
        context,
        dateTime,
        history != null ? Object.hashAll(history!) : null,
        Object.hashAll(
          instructions.entries.map((final e) => Object.hash(e.key, e.value)),
        ),
      );

  // Helper methods for deep comparison
  static bool _mapEquals<K, V>(final Map<K, V>? a, final Map<K, V>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  static bool _listEquals<T>(final List<T>? a, final List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
