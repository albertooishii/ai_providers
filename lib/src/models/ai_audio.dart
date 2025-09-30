/// Modelo de audio generado por proveedores de IA.
///
/// Representa audio generado (TTS) o transcrito (STT) con información completa
/// sobre su procesamiento, incluyendo metadatos y contenido del audio.
///
/// **Campos principales:**
/// - `url`: Ruta del archivo de audio guardado localmente
/// - `transcript`: Contenido textual del audio (para STT o TTS)
/// - `base64`: Datos raw en base64 (disponible temporalmente durante el proceso)
/// - `durationMs`: Duración del audio en milisegundos
/// - `createdAtMs`: Timestamp de creación en milisegundos
/// - `isAutoTts`: Indica si fue generado automáticamente vía TTS
///
/// **Uso típico:**
/// ```dart
/// // Generación TTS
/// final response = await AI.speak('¡Hola mundo!');
/// final audio = response.audio;
/// if (audio != null) {
///   print('Audio guardado en: ${audio.url}');
///   print('Duración: ${audio.duration?.inSeconds}s');
/// }
///
/// // Transcripción STT
/// final response = await AI.listen(audioFile);
/// print('Transcripción: ${response.text}');
/// ```
class AiAudio {
  AiAudio({
    this.url,
    this.transcript,
    this.durationMs,
    this.createdAtMs,
    this.isAutoTts,
    this.base64,
  });

  factory AiAudio.fromJson(final Map<String, dynamic> json) {
    return AiAudio(
      url: json['url'] as String?,
      transcript: json['transcript'] as String?,
      durationMs: json['durationMs'] is int
          ? json['durationMs'] as int
          : (json['durationMs'] is String
              ? int.tryParse(json['durationMs'])
              : null),
      createdAtMs: json['createdAtMs'] is int
          ? json['createdAtMs'] as int
          : (json['createdAtMs'] is String
              ? int.tryParse(json['createdAtMs'])
              : null),
      isAutoTts: json['isAutoTts'] as bool?,
      base64: json['base64'] as String?,
    );
  }

  /// Path or URL to the audio file
  final String? url;

  /// Transcript/text content of the audio
  final String? transcript;

  /// Duration of the audio file in milliseconds
  final int? durationMs;

  /// Unix timestamp in milliseconds when this audio was created
  final int? createdAtMs;

  /// Whether this audio was auto-generated via TTS
  final bool? isAutoTts;

  /// Raw audio data as base64 string
  final String? base64;

  Map<String, dynamic> toJson() => {
        if (url != null) 'url': url,
        if (transcript != null) 'transcript': transcript,
        if (durationMs != null) 'durationMs': durationMs,
        if (createdAtMs != null) 'createdAtMs': createdAtMs,
        if (isAutoTts != null) 'isAutoTts': isAutoTts,
        if (base64 != null) 'base64': base64,
      };

  AiAudio copyWith({
    final String? url,
    final String? transcript,
    final int? durationMs,
    final int? createdAtMs,
    final bool? isAutoTts,
    final String? base64,
  }) {
    return AiAudio(
      url: url ?? this.url,
      transcript: transcript ?? this.transcript,
      durationMs: durationMs ?? this.durationMs,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      isAutoTts: isAutoTts ?? this.isAutoTts,
      base64: base64 ?? this.base64,
    );
  }

  /// Get duration as Duration object
  Duration? get duration =>
      durationMs != null ? Duration(milliseconds: durationMs!) : null;
}
