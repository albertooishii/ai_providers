/// Parámetros específicos para síntesis de voz (TTS - Text-to-Speech).
///
/// Esta clase proporciona una interfaz estructurada para configurar la generación
/// de audio desde texto usando `AI.speak()`, evitando strings mágicos y ofreciendo
/// constantes tipadas para voice synthesis.
///
/// **Nota:** Para transcripción de audio (STT), usar `AI.listen()` con `AISystemPrompt`.
///
/// **Compatibilidad con proveedores TTS:**
/// - **OpenAI**: Soporte completo (speed, response_format, language, accent+emotion en instructions)
/// - **Google**: Configuración nativa (language, accent, emotion, temperature) + solo formato PCM
/// - **Android Native**: Solo speed y language son soportados para TTS
/// - **Otros**: Comportamiento definido por cada proveedor
///
/// **Tabla de parámetros TTS:**
///
/// | Campo | Tipo | Valores | Descripción |
/// |-------|------|---------|-------------|
/// | `speed` | `double` | `0.25` - `4.0` | Velocidad de síntesis de voz. `1.0` es velocidad normal. |
/// | `audioFormat` | `String?` | `m4a`, `mp3` | Formato de salida final opcional. M4A por defecto si null (75% menos espacio). |
/// | `language` | `String?` | `es`, `en`, `es-ES`, `en-US` | Idioma ISO estándar para filtrado de voces y síntesis. |
/// | `accent` | `String?` | Texto libre | Acento o estilo de pronunciación personalizado (ej: "español con acento japonés"). |
/// | `temperature` | `double?` | `0.0` - `1.0` | Creatividad en la expresión vocal (Google principalmente). |
/// | `emotion` | `String?` | Texto libre o constantes | Emoción a transmitir en la síntesis (ej: "susurrando pero asustada"). |
///
/// **Proceso interno:** Los providers usan PCM internamente, `audioFormat` solo afecta la conversión final.
///
/// **Ejemplo de uso:**
/// ```dart
/// // M4A por defecto (recomendado)
/// const params1 = AiAudioParams(
///   speed: 1.2,
///   language: 'es',
///   accent: 'español con acento japonés',
/// );
///
/// // MP3 si se prefiere compatibilidad universal
/// const params2 = AiAudioParams(
///   speed: 1.0,
///   audioFormat: 'mp3',
///   emotion: AiAudioEmotion.whisper,
/// );
///
/// final audio = await AI.speak('Hola mundo', params1);
/// // Retorna M4A por defecto o formato elegido
/// ```
///
/// Compatible con el sistema de additionalParams existente pero con estructura tipada.
class AiAudioParams {
  const AiAudioParams({
    this.speed = 1.0,
    final String? audioFormat, // Opcional: m4a por defecto, mp3 alternativa
    this.language,
    this.accent,
    this.temperature,
    this.emotion,
  }) : _audioFormat = audioFormat;

  /// Factory constructor desde `Map<String, dynamic>` para compatibilidad
  factory AiAudioParams.fromMap(final Map<String, dynamic>? params) {
    if (params == null) return const AiAudioParams();

    final format = params['audioFormat'] as String? ??
        params['response_format'] as String?;

    return AiAudioParams(
      speed: (params['speed'] as num?)?.toDouble() ?? 1.0,
      audioFormat: (format == 'mp3' || format == 'm4a') ? format : null,
      language: params['language'] as String?,
      temperature: (params['temperature'] as num?)?.toDouble(),
      emotion: params['emotion'] as String?,
    );
  }

  /// Velocidad de síntesis de voz para TTS.
  ///
  /// Rango válido: `0.25` (muy lento) a `4.0` (muy rápido).
  /// Valor por defecto: `1.0` (velocidad normal).
  ///
  /// **Soporte por proveedor:**
  /// - OpenAI: ✅ Soportado completamente (0.25 - 4.0)
  /// - Android Native: ✅ Soportado (se mapea a setSpeechRate)
  /// - Google: ❌ No soportado directamente
  final double speed;

  /// Formato de salida final del audio generado (opcional, M4A por defecto).
  ///
  /// **Opciones disponibles:**
  /// - `null` o `'m4a'`: M4A/AAC comprimido (por defecto, 75% menos espacio)
  /// - `'mp3'`: MP3 comprimido (compatible universalmente)
  ///
  /// **Nota:** Los providers usan PCM internamente para máxima compatibilidad.
  /// Este parámetro solo afecta la conversión final.
  final String? _audioFormat;

  /// Getter que devuelve el formato efectivo (m4a por defecto)
  String get audioFormat {
    if (_audioFormat == null) return 'm4a';
    if (_audioFormat == 'mp3' || _audioFormat == 'm4a') return _audioFormat;
    return 'm4a'; // Fallback si valor inválido
  }

  /// Idioma ISO estándar para compatibilidad y filtrado de voces.
  ///
  /// **Uso por proveedor:**
  /// - Android Native: ✅ Filtra voces disponibles por idioma ISO
  /// - OpenAI STT: ✅ Se pasa directamente (`es`, `en`, `fr`, etc.)
  /// - Google: ✅ Base para instrucciones (se combina con accent)
  ///
  /// **Valores:** Solo códigos ISO (`es`, `en`, `ja`, `es-ES`, `en-US`)
  /// **Para acentos personalizados:** Usar el campo `accent`
  final String? language;

  /// Acento o estilo de pronunciación personalizado (texto libre).
  ///
  /// **Ejemplos avanzados:**
  /// - `"español con acento japonés"`
  /// - `"inglés británico formal"`
  /// - `"acento argentino suave"`
  /// - `"pronunciación robotica"`
  ///
  /// **Uso por proveedor:**
  /// - Google: ✅ Se incluye en instrucciones TTS nativas
  /// - OpenAI: ✅ Se combina con emotion en campo "instructions"
  /// - Android Native: ❌ No soportado (solo language ISO)
  final String? accent;

  /// Creatividad en la expresión vocal durante síntesis TTS.
  ///
  /// Rango válido: `0.0` (determinista) a `1.0` (muy creativo).
  ///
  /// **Uso por proveedor:**
  /// - Google: Se aplica a la configuración de síntesis vocal
  /// - OpenAI: No soportado directamente en TTS APIs
  /// - Android Native: No soportado
  final double? temperature;

  /// Emoción a transmitir en la síntesis de voz (TTS).
  ///
  /// **Ejemplos de texto libre:**
  /// - `"susurrando pero asustada como si acabaras de despertar"`
  /// - `"emocionada como un niño en navidad"`
  /// - `"formal pero con calidez maternal"`
  ///
  /// **Valores constantes básicos:**
  /// - `neutral`: Tono neutro y profesional
  /// - `happy`: Alegre y entusiasta
  /// - `calm`: Tranquilo y relajado
  ///
  /// **Soporte por proveedor:**
  /// - Google: ✅ Soporta texto libre y constantes
  /// - OpenAI: ✅ Se combina con accent en campo "instructions"
  /// - Android Native: ❌ Limitado por voces predefinidas
  ///
  /// Valores básicos disponibles en [AiAudioEmotion] para conveniencia.
  final String? emotion;

  /// Convierte a `Map<String, dynamic>` para compatibilidad con additionalParams
  ///
  /// **Importante:** Solo incluye parámetros que los providers necesitan internamente.
  /// El audioFormat final se maneja por MediaPersistenceService, no por providers.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map['speed'] = speed;
    if (language != null) map['language'] = language;
    if (accent != null) map['accent'] = accent;
    if (temperature != null) map['temperature'] = temperature;
    if (emotion != null) map['emotion'] = emotion;

    return map;
  }

  /// Copy with para modificaciones inmutables
  AiAudioParams copyWith({
    final double? speed,
    final String? audioFormat,
    final String? language,
    final String? accent,
    final double? temperature,
    final String? emotion,
  }) {
    return AiAudioParams(
      speed: speed ?? this.speed,
      audioFormat: audioFormat ?? _audioFormat,
      language: language ?? this.language,
      accent: accent ?? this.accent,
      temperature: temperature ?? this.temperature,
      emotion: emotion ?? this.emotion,
    );
  }

  @override
  String toString() {
    return 'AiAudioParams(speed: $speed, audioFormat: $audioFormat, '
        'language: $language, temperature: $temperature, emotion: $emotion)';
  }
}

/// Constantes para formatos de audio de salida final.
///
/// Define solo los formatos comprimidos disponibles para el usuario.
class AiAudioFormat {
  /// M4A - Formato comprimido AAC (recomendado, 75% menos espacio)
  static const String m4a = 'm4a';

  /// MP3 - Formato comprimido universal (máxima compatibilidad)
  static const String mp3 = 'mp3';
}

/// Constantes para emociones comunes en síntesis de voz.
///
/// Define emociones estándar para expresión vocal en TTS.
/// Para emociones personalizadas, usar texto libre directamente.
class AiAudioEmotion {
  /// Neutral - Tono profesional y equilibrado
  static const String neutral = 'neutral';

  /// Happy - Alegre y entusiasta
  static const String happy = 'happy';

  /// Calm - Tranquilo y relajado
  static const String calm = 'calm';

  /// Excited - Emocionado y energético
  static const String excited = 'excited';

  /// Sad - Melancólico y reflexivo
  static const String sad = 'sad';

  /// Warm - Cálido y acogedor
  static const String warm = 'warm';

  /// Professional - Formal y autoritativo
  static const String professional = 'professional';

  /// Whisper - Susurrando
  static const String whisper = 'whisper';

  /// Scared - Asustado o nervioso
  static const String scared = 'scared';
}
