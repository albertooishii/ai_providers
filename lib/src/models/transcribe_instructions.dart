/// 🎤 **TranscribeInstructions**
///
/// Instrucciones para la transcripción de audio (Speech-to-Text).
/// Incluye reglas anti-alucinación y configuraciones específicas.
///
/// **Uso:**
/// ```dart
/// // Con valores por defecto (incluye reglas anti-alucinación)
/// await AI.listen();
///
/// // Con instrucciones personalizadas
/// await AI.listen(TranscribeInstructions(
///   language: 'en-US',
///   format: 'detailed',
///   includePunctuation: false
/// ));
/// ```
class TranscribeInstructions {
  const TranscribeInstructions({
    this.language = 'auto',
    this.format = 'simple',
    this.includePunctuation = true,
    this.includeTimestamps = false,
    this.preventHallucinations = true,
    this.context = 'general',
    this.customRules,
  });

  /// Idioma esperado del audio (ej: 'es-ES', 'en-US', 'ja-JP', 'auto' para detección automática)
  final String language;

  /// Formato de transcripción ('simple', 'detailed', 'timestamps')
  final String format;

  /// Incluir puntuación en la transcripción
  final bool includePunctuation;

  /// Incluir marcas de tiempo en la transcripción
  final bool includeTimestamps;

  /// Prevenir alucinaciones (texto inventado) - habilitado por defecto
  final bool preventHallucinations;

  /// Contexto específico ('general', 'medical', 'technical', 'legal')
  final String context;

  /// Reglas personalizadas adicionales para la transcripción
  final List<String>? customRules;

  /// Reglas por defecto para prevenir alucinaciones
  static const List<String> defaultAntiHallucinationRules = [
    'ONLY transcribe the actual audio content provided',
    'Do NOT generate example text, sample conversations, or placeholder content',
    'If the audio is unclear or empty, respond with an empty string',
    'Do NOT add fictional dialogue about insurance, sales calls, or marketing',
    'Be precise and accurate - transcribe exactly what you hear',
    'Do NOT invent words or phrases that are not clearly audible',
  ];

  /// Convierte las instrucciones a Map para uso interno
  Map<String, dynamic> toMap() {
    final rules = <String>[];

    // Agregar reglas anti-alucinación por defecto si están habilitadas
    if (preventHallucinations) {
      rules.addAll(defaultAntiHallucinationRules);
    }

    // Agregar reglas personalizadas si las hay
    if (customRules != null) {
      rules.addAll(customRules!);
    }

    return {
      'language': language,
      'format': format,
      'include_punctuation': includePunctuation,
      'include_timestamps': includeTimestamps,
      'prevent_hallucinations': preventHallucinations,
      'context': context,
      'transcription_rules': rules,
    };
  }

  /// Crea una copia con valores modificados
  TranscribeInstructions copyWith({
    final String? language,
    final String? format,
    final bool? includePunctuation,
    final bool? includeTimestamps,
    final bool? preventHallucinations,
    final String? context,
    final List<String>? customRules,
  }) {
    return TranscribeInstructions(
      language: language ?? this.language,
      format: format ?? this.format,
      includePunctuation: includePunctuation ?? this.includePunctuation,
      includeTimestamps: includeTimestamps ?? this.includeTimestamps,
      preventHallucinations:
          preventHallucinations ?? this.preventHallucinations,
      context: context ?? this.context,
      customRules: customRules ?? this.customRules,
    );
  }

  @override
  String toString() {
    return 'TranscribeInstructions(language: $language, format: $format, includePunctuation: $includePunctuation, includeTimestamps: $includeTimestamps, preventHallucinations: $preventHallucinations, context: $context, customRules: $customRules)';
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    return other is TranscribeInstructions &&
        other.language == language &&
        other.format == format &&
        other.includePunctuation == includePunctuation &&
        other.includeTimestamps == includeTimestamps &&
        other.preventHallucinations == preventHallucinations &&
        other.context == context &&
        other.customRules == customRules;
  }

  @override
  int get hashCode {
    return language.hashCode ^
        format.hashCode ^
        includePunctuation.hashCode ^
        includeTimestamps.hashCode ^
        preventHallucinations.hashCode ^
        context.hashCode ^
        customRules.hashCode;
  }
}
