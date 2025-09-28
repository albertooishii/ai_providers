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
/// | `audioFormat` | `String?` | `wav`, `mp3`, `opus`, `aac`, `flac`, `pcm` | Formato de audio de salida para síntesis TTS. |
/// | `language` | `String?` | `es`, `en`, `es-ES`, `en-US` | Idioma ISO estándar para filtrado de voces y síntesis. |
/// | `accent` | `String?` | Texto libre | Acento o estilo de pronunciación personalizado (ej: "español con acento japonés"). |
/// | `temperature` | `double?` | `0.0` - `1.0` | Creatividad en la expresión vocal (Google principalmente). |
/// | `emotion` | `String?` | Texto libre o constantes | Emoción a transmitir en la síntesis (ej: "susurrando pero asustada"). |
///
/// **Ejemplo de uso:**
/// ```dart
/// const params = AiAudioParams(
///   speed: 1.2,
///   audioFormat: AiAudioFormat.pcm,  // PCM recomendado
///   language: 'es',  // ISO para Android Native
///   accent: 'español con acento japonés',  // OpenAI + Google
///   emotion: AiAudioEmotion.whisper,  // O texto libre personalizado
/// );
///
/// final audio = await AI.speak('Hola mundo', params);
/// ```
///
/// Compatible con el sistema de additionalParams existente pero con estructura tipada.
class AiAudioParams {
  const AiAudioParams({
    this.speed = 1.0,
    this.audioFormat = 'pcm',
    this.language,
    this.accent,
    this.temperature,
    this.emotion,
  });

  /// Factory constructor desde `Map<String, dynamic>` para compatibilidad
  factory AiAudioParams.fromMap(final Map<String, dynamic>? params) {
    if (params == null) return const AiAudioParams();

    return AiAudioParams(
      speed: (params['speed'] as num?)?.toDouble() ?? 1.0,
      audioFormat: params['response_format'] as String? ??
          params['audioFormat'] as String? ??
          'pcm',
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

  /// Formato de archivo de audio para salida TTS (síntesis de voz).
  ///
  /// Valor por defecto: `'pcm'` (recomendado, compatible con todos los proveedores).
  ///
  /// **Formatos por proveedor:**
  /// - OpenAI: `mp3`, `opus`, `aac`, `flac`, `wav`, `pcm`
  /// - Google: Solo `pcm` (formato nativo)
  /// - Android Native: Siempre `wav` (hardcoded)
  ///
  /// Valores disponibles en [AiAudioFormat] para conveniencia.
  final String audioFormat;

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
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map['speed'] = speed;
    map['response_format'] = audioFormat;
    if (language != null) map['language'] = language;
    if (accent != null) map['accent'] = accent;
    if (temperature != null) map['temperature'] = temperature;
    if (emotion != null) map['emotion'] = emotion;

    return map;
  }

  /// Merge con otros parámetros manteniendo compatibilidad
  Map<String, dynamic> mergeWithAdditionalParams(
      final Map<String, dynamic>? additionalParams) {
    final audioParams = toMap();
    final combined = <String, dynamic>{};

    // Primero añadir parámetros adicionales existentes
    if (additionalParams != null) {
      combined.addAll(additionalParams);
    }

    // Luego sobrescribir con parámetros de audio específicos (mayor prioridad)
    combined.addAll(audioParams);

    return combined;
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
      audioFormat: audioFormat ?? this.audioFormat,
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

/// Constantes para formatos de audio de salida TTS.
///
/// Define los tipos de archivo soportados por los proveedores para síntesis de voz.
class AiAudioFormat {
  /// PCM - Audio crudo sin compresión (recomendado, único formato de Google)
  static const String pcm = 'pcm';

  /// WAV - Formato sin compresión, máxima calidad
  static const String wav = 'wav';

  /// MP3 - Formato comprimido universal, buena calidad/tamaño
  static const String mp3 = 'mp3';

  /// Opus - Formato moderno, alta eficiencia para voz
  static const String opus = 'opus';

  /// AAC - Formato avanzado, usado en dispositivos móviles
  static const String aac = 'aac';

  /// FLAC - Formato sin pérdida, máxima calidad sin compresión
  static const String flac = 'flac';
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
