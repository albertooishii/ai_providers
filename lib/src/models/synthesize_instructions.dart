/// 🔊 **SynthesizeInstructions**
///
/// Instrucciones opcionales para la síntesis de voz (Text-to-Speech).
/// Contiene configuraciones por defecto sensatas que pueden ser
/// sobreescritas según las necesidades específicas.
///
/// **Uso:**
/// ```dart
/// // Con valores por defecto
/// await AI.speak(text);
///
/// // Con instrucciones personalizadas
/// await AI.speak(text, SynthesizeInstructions(
///   voiceStyle: 'cheerful',
///   speed: 1.2,
///   language: 'es-ES'
/// ));
/// ```
class SynthesizeInstructions {
  const SynthesizeInstructions({
    this.voiceStyle = 'neutral',
    this.emotion = 'calm',
    this.speed = 1.0,
    this.language = 'es-ES',
    this.pitch = 'medium',
    this.pauseBetweenSentences = 300,
  });

  /// Estilo de voz (ej: 'neutral', 'cheerful', 'sad', 'excited')
  final String voiceStyle;

  /// Emoción a transmitir (ej: 'happy', 'calm', 'energetic')
  final String emotion;

  /// Velocidad de habla (0.5 = lento, 1.0 = normal, 2.0 = rápido)
  final double speed;

  /// Idioma de síntesis (ej: 'es-ES', 'en-US', 'ja-JP')
  final String language;

  /// Tono de voz (ej: 'high', 'medium', 'low')
  final String pitch;

  /// Pausa entre oraciones en milisegundos
  final int pauseBetweenSentences;

  /// Convierte las instrucciones a Map para uso interno
  Map<String, dynamic> toMap() {
    return {
      'voice_style': voiceStyle,
      'emotion': emotion,
      'speed': speed,
      'language': language,
      'pitch': pitch,
      'pause_between_sentences': pauseBetweenSentences,
    };
  }

  /// Crea una copia con valores modificados
  SynthesizeInstructions copyWith({
    final String? voiceStyle,
    final String? emotion,
    final double? speed,
    final String? language,
    final String? pitch,
    final int? pauseBetweenSentences,
  }) {
    return SynthesizeInstructions(
      voiceStyle: voiceStyle ?? this.voiceStyle,
      emotion: emotion ?? this.emotion,
      speed: speed ?? this.speed,
      language: language ?? this.language,
      pitch: pitch ?? this.pitch,
      pauseBetweenSentences:
          pauseBetweenSentences ?? this.pauseBetweenSentences,
    );
  }

  @override
  String toString() {
    return 'SynthesizeInstructions(voiceStyle: $voiceStyle, emotion: $emotion, speed: $speed, language: $language, pitch: $pitch, pauseBetweenSentences: $pauseBetweenSentences)';
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    return other is SynthesizeInstructions &&
        other.voiceStyle == voiceStyle &&
        other.emotion == emotion &&
        other.speed == speed &&
        other.language == language &&
        other.pitch == pitch &&
        other.pauseBetweenSentences == pauseBetweenSentences;
  }

  @override
  int get hashCode {
    return voiceStyle.hashCode ^
        emotion.hashCode ^
        speed.hashCode ^
        language.hashCode ^
        pitch.hashCode ^
        pauseBetweenSentences.hashCode;
  }
}
