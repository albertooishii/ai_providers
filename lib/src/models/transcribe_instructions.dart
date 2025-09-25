/// 🎤 **TranscribeInstructions**
///
/// Instrucciones opcionales para la transcripción de audio (Speech-to-Text).
/// Contiene configuraciones por defecto sensatas que pueden ser
/// sobreescritas según las necesidades específicas.
///
/// **Uso:**
/// ```dart
/// // Con valores por defecto
/// await AI.transcribe(audioBase64);
///
/// // Con instrucciones personalizadas
/// await AI.transcribe(audioBase64, TranscribeInstructions(
///   language: 'en-US',
///   format: 'detailed',
///   includePunctuation: false
/// ));
/// ```
class TranscribeInstructions {
  const TranscribeInstructions({
    this.language = 'auto',
    this.format = 'simple',
    this.accuracy = 'high',
    this.includePunctuation = true,
    this.includeTimestamps = false,
    this.filterProfanity = false,
    this.context = 'casual',
  });

  /// Idioma esperado del audio (ej: 'es-ES', 'en-US', 'ja-JP', 'auto' para detección automática)
  final String language;

  /// Formato de transcripción ('simple', 'detailed', 'timestamps')
  final String format;

  /// Nivel de precisión esperado ('high', 'medium', 'fast')
  final String accuracy;

  /// Incluir puntuación en la transcripción
  final bool includePunctuation;

  /// Incluir marcas de tiempo en la transcripción
  final bool includeTimestamps;

  /// Filtrar palabras ofensivas
  final bool filterProfanity;

  /// Contexto o dominio específico (ej: 'medical', 'technical', 'casual')
  final String context;

  /// Convierte las instrucciones a Map para uso interno
  Map<String, dynamic> toMap() {
    return {
      'language': language,
      'format': format,
      'accuracy': accuracy,
      'include_punctuation': includePunctuation,
      'include_timestamps': includeTimestamps,
      'filter_profanity': filterProfanity,
      'context': context,
    };
  }

  /// Crea una copia con valores modificados
  TranscribeInstructions copyWith({
    final String? language,
    final String? format,
    final String? accuracy,
    final bool? includePunctuation,
    final bool? includeTimestamps,
    final bool? filterProfanity,
    final String? context,
  }) {
    return TranscribeInstructions(
      language: language ?? this.language,
      format: format ?? this.format,
      accuracy: accuracy ?? this.accuracy,
      includePunctuation: includePunctuation ?? this.includePunctuation,
      includeTimestamps: includeTimestamps ?? this.includeTimestamps,
      filterProfanity: filterProfanity ?? this.filterProfanity,
      context: context ?? this.context,
    );
  }

  @override
  String toString() {
    return 'TranscribeInstructions(language: $language, format: $format, accuracy: $accuracy, includePunctuation: $includePunctuation, includeTimestamps: $includeTimestamps, filterProfanity: $filterProfanity, context: $context)';
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    return other is TranscribeInstructions &&
        other.language == language &&
        other.format == format &&
        other.accuracy == accuracy &&
        other.includePunctuation == includePunctuation &&
        other.includeTimestamps == includeTimestamps &&
        other.filterProfanity == filterProfanity &&
        other.context == context;
  }

  @override
  int get hashCode {
    return language.hashCode ^
        format.hashCode ^
        accuracy.hashCode ^
        includePunctuation.hashCode ^
        includeTimestamps.hashCode ^
        filterProfanity.hashCode ^
        context.hashCode;
  }
}
