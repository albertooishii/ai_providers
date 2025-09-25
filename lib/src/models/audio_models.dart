// =============================================================================
// 🎵 MODELOS DE AUDIO CONSOLIDADOS
// =============================================================================
// Consolidación de todos los modelos relacionados con audio en AI providers
// - AudioMode y AudioModeExtension
// - AudioPlaybackState, AudioPlaybackConfig, AudioPlaybackResult
// - AudioExceptions (VoiceSynthesisException, AudioPlaybackException, etc.)
// - VoiceInfo, VoiceSettings, SynthesisResult
// =============================================================================

// === AUDIO MODES ===

/// Enumeración para los diferentes modos de audio soportados
enum AudioMode {
  /// Modo híbrido: TTS + STT + modelo de texto
  /// Recomendado para: onboarding, chat, interacciones simples
  hybrid,

  /// Modo realtime: Conexión directa con provider realtime
  /// Recomendado para: llamadas de voz, conversaciones en tiempo real
  realtime,
}

/// Extensión para AudioMode con funcionalidades útiles
extension AudioModeExtension on AudioMode {
  /// Nombre legible del modo
  String get displayName {
    switch (this) {
      case AudioMode.hybrid:
        return 'Híbrido (TTS+STT)';
      case AudioMode.realtime:
        return 'Tiempo Real';
    }
  }

  /// Identificador para configuración YAML
  String get identifier {
    switch (this) {
      case AudioMode.hybrid:
        return 'hybrid';
      case AudioMode.realtime:
        return 'realtime';
    }
  }

  /// Descripción del modo
  String get description {
    switch (this) {
      case AudioMode.hybrid:
        return 'Combina TTS + STT + modelo de texto para simular conversación en tiempo real';
      case AudioMode.realtime:
        return 'Conexión directa con provider realtime para conversación nativa';
    }
  }

  /// Crear desde identificador
  static AudioMode? fromIdentifier(final String identifier) {
    switch (identifier.toLowerCase()) {
      case 'hybrid':
        return AudioMode.hybrid;
      case 'realtime':
        return AudioMode.realtime;
      default:
        return null;
    }
  }
}

// === AUDIO PLAYBACK ===

/// Estados posibles para la reproducción de audio
enum AudioPlaybackState {
  /// Estado inicial - no hay reproducción activa
  idle,

  /// Cargando archivo de audio
  loading,

  /// Reproduciendo activamente
  playing,

  /// Pausado temporalmente
  paused,

  /// Detenido manualmente
  stopped,

  /// Reproducción completada
  completed,

  /// Error durante la reproducción
  error,
}

/// Configuración para la reproducción de audio
class AudioPlaybackConfig {
  const AudioPlaybackConfig({
    this.volume = 1.0,
    this.speed = 1.0,
    this.autoPlay = true,
    this.notifyOnCompletion = true,
    this.cleanupTempFiles = true,
  });

  final double volume; // 0.0 - 1.0
  final double speed; // 0.1 - 3.0
  final bool autoPlay;
  final bool notifyOnCompletion;
  final bool cleanupTempFiles;

  static const AudioPlaybackConfig defaultConfig = AudioPlaybackConfig();

  AudioPlaybackConfig copyWith({
    final double? volume,
    final double? speed,
    final bool? autoPlay,
    final bool? notifyOnCompletion,
    final bool? cleanupTempFiles,
  }) {
    return AudioPlaybackConfig(
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      autoPlay: autoPlay ?? this.autoPlay,
      notifyOnCompletion: notifyOnCompletion ?? this.notifyOnCompletion,
      cleanupTempFiles: cleanupTempFiles ?? this.cleanupTempFiles,
    );
  }

  @override
  String toString() {
    return 'AudioPlaybackConfig(volume: $volume, speed: $speed, autoPlay: $autoPlay, '
        'notifyOnCompletion: $notifyOnCompletion, cleanupTempFiles: $cleanupTempFiles)';
  }
}

/// Resultado de una operación de reproducción de audio
class AudioPlaybackResult {
  factory AudioPlaybackResult.success({
    final Duration? duration,
    final String? filePath,
    final Map<String, dynamic> metadata = const {},
  }) {
    return AudioPlaybackResult._(
      success: true,
      duration: duration,
      filePath: filePath,
      metadata: metadata,
    );
  }

  factory AudioPlaybackResult.failure({
    required final String error,
    final Map<String, dynamic> metadata = const {},
  }) {
    return AudioPlaybackResult._(
      success: false,
      error: error,
      metadata: metadata,
    );
  }
  const AudioPlaybackResult._({
    required this.success,
    this.duration,
    this.filePath,
    this.metadata = const {},
    this.error,
  });

  final bool success;
  final Duration? duration;
  final String? filePath;
  final Map<String, dynamic> metadata;
  final String? error;

  @override
  String toString() {
    if (success) {
      return 'AudioPlaybackResult.success(duration: $duration, filePath: $filePath)';
    } else {
      return 'AudioPlaybackResult.failure(error: $error)';
    }
  }
}

// === VOICE MODELS ===

/// Representa una voz disponible en un provider de AI
class VoiceInfo {
  factory VoiceInfo.fromMap(final Map<String, dynamic> map) {
    return VoiceInfo(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      gender: VoiceGender.values.firstWhere(
        (final g) => g.name == map['gender'],
        orElse: () => VoiceGender.neutral,
      ),
      language: map['language'] ?? 'es-ES',
      age: map['age'] != null
          ? VoiceAge.values.firstWhere(
              (final a) => a.name == map['age'],
              orElse: () => VoiceAge.adult,
            )
          : null,
      description: map['description'],
      previewUrl: map['preview_url'],
      isDefault: map['is_default'] ?? false,
      isPremium: map['is_premium'] ?? false,
      emotionalRange: (map['emotional_range'] as List<dynamic>?)
              ?.map(
                (final e) => VoiceEmotion.values.firstWhere(
                  (final emotion) => emotion.name == e,
                  orElse: () => VoiceEmotion.neutral,
                ),
              )
              .toList() ??
          [],
    );
  }
  const VoiceInfo({
    required this.id,
    required this.name,
    required this.gender,
    this.language = 'es-ES',
    this.age,
    this.description,
    this.previewUrl,
    this.isDefault = false,
    this.isPremium = false,
    this.emotionalRange = const [],
  });

  final String id;
  final String name;
  final VoiceGender gender;
  final String language;
  final VoiceAge? age;
  final String? description;
  final String? previewUrl;
  final bool isDefault;
  final bool isPremium;
  final List<VoiceEmotion> emotionalRange;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'gender': gender.name,
      'language': language,
      'age': age?.name,
      'description': description,
      'preview_url': previewUrl,
      'is_default': isDefault,
      'is_premium': isPremium,
      'emotional_range': emotionalRange.map((final e) => e.name).toList(),
    };
  }

  @override
  String toString() {
    return 'VoiceInfo(id: $id, name: $name, gender: $gender, language: $language)';
  }
}

/// Géneros de voz disponibles
enum VoiceGender { male, female, neutral }

/// Edades de voz disponibles
enum VoiceAge { child, teen, adult, elderly }

/// Emociones que puede expresar una voz
enum VoiceEmotion {
  neutral,
  happy,
  sad,
  excited,
  calm,
  angry,
  warm,
  professional,
}

/// Configuración específica para síntesis de voz
class VoiceSettings {
  factory VoiceSettings.fromMap(final Map<String, dynamic> map) {
    return VoiceSettings(
      voiceId: map['voice_id'],
      speed: (map['speed'] ?? 1.0).toDouble(),
      pitch: (map['pitch'] ?? 1.0).toDouble(),
      stability: (map['stability'] ?? 0.5).toDouble(),
      similarityBoost: (map['similarity_boost'] ?? 0.5).toDouble(),
      emotion: VoiceEmotion.values.firstWhere(
        (final e) => e.name == map['emotion'],
        orElse: () => VoiceEmotion.neutral,
      ),
      outputFormat: map['output_format'] ?? 'mp3',
    );
  }
  const VoiceSettings({
    this.voiceId,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.stability = 0.5,
    this.similarityBoost = 0.5,
    this.emotion = VoiceEmotion.neutral,
    this.outputFormat = 'mp3',
  });

  final String? voiceId;
  final double speed; // 0.25 - 4.0
  final double pitch; // 0.5 - 2.0
  final double stability; // 0.0 - 1.0
  final double similarityBoost; // 0.0 - 1.0
  final VoiceEmotion emotion;
  final String outputFormat;

  static const VoiceSettings defaultSettings = VoiceSettings();

  /// Método de conveniencia para crear VoiceSettings
  static VoiceSettings create({
    final String? voiceId,
    final String? language,
    final double speed = 1.0,
    final double pitch = 1.0,
    final double stability = 0.5,
    final double similarityBoost = 0.5,
    final VoiceEmotion emotion = VoiceEmotion.neutral,
    final String outputFormat = 'mp3',
  }) {
    return VoiceSettings(
      voiceId: voiceId,
      speed: speed,
      pitch: pitch,
      stability: stability,
      similarityBoost: similarityBoost,
      emotion: emotion,
      outputFormat: outputFormat,
    );
  }

  VoiceSettings copyWith({
    final String? voiceId,
    final double? speed,
    final double? pitch,
    final double? stability,
    final double? similarityBoost,
    final VoiceEmotion? emotion,
    final String? outputFormat,
  }) {
    return VoiceSettings(
      voiceId: voiceId ?? this.voiceId,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      stability: stability ?? this.stability,
      similarityBoost: similarityBoost ?? this.similarityBoost,
      emotion: emotion ?? this.emotion,
      outputFormat: outputFormat ?? this.outputFormat,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'voice_id': voiceId,
      'speed': speed,
      'pitch': pitch,
      'stability': stability,
      'similarity_boost': similarityBoost,
      'emotion': emotion.name,
      'output_format': outputFormat,
    };
  }

  @override
  String toString() {
    return 'VoiceSettings(voiceId: $voiceId, speed: $speed, pitch: $pitch, '
        'stability: $stability, emotion: $emotion)';
  }
}

/// Resultado de una operación de síntesis de voz
class SynthesisResult {
  factory SynthesisResult.success({
    final List<int>? audioData,
    final String? audioBase64,
    final String? filePath,
    final Duration? duration,
    final String? format,
    final VoiceInfo? voiceUsed,
    final Map<String, dynamic> metadata = const {},
  }) {
    return SynthesisResult(
      success: true,
      audioData: audioData,
      audioBase64: audioBase64,
      filePath: filePath,
      duration: duration,
      format: format,
      voiceUsed: voiceUsed,
      metadata: metadata,
    );
  }

  factory SynthesisResult.failure({
    required final String error,
    final Map<String, dynamic> metadata = const {},
  }) {
    return SynthesisResult(success: false, error: error, metadata: metadata);
  }
  const SynthesisResult({
    required this.success,
    this.audioData,
    this.audioBase64,
    this.filePath,
    this.duration,
    this.format,
    this.voiceUsed,
    this.error,
    this.metadata = const {},
  });

  final bool success;
  final List<int>? audioData;
  final String? audioBase64;
  final String? filePath;
  final Duration? duration;
  final String? format;
  final VoiceInfo? voiceUsed;
  final String? error;
  final Map<String, dynamic> metadata;

  @override
  String toString() {
    if (success) {
      return 'SynthesisResult.success(duration: $duration, format: $format, voice: ${voiceUsed?.name})';
    } else {
      return 'SynthesisResult.failure(error: $error)';
    }
  }
}

// === AUDIO RECORDING ===

/// Resultado de una operación de grabación de audio
class AudioRecordingResult {
  const AudioRecordingResult({
    required this.filePath,
    required this.duration,
    required this.fileSize,
    this.sampleRate,
    this.format,
  });

  final String filePath;
  final Duration duration;
  final int fileSize; // in bytes
  final String? sampleRate;
  final String? format;

  @override
  String toString() {
    return 'AudioRecordingResult(filePath: $filePath, duration: ${duration.inSeconds}s, '
        'fileSize: ${fileSize}b, sampleRate: $sampleRate, format: $format)';
  }
}

// === AUDIO EXCEPTIONS ===

/// Excepción base para operaciones de audio
class AudioException implements Exception {
  const AudioException(this.message, {this.originalError});

  final String message;
  final dynamic originalError;

  @override
  String toString() {
    if (originalError != null) {
      return 'AudioException: $message (Original: $originalError)';
    }
    return 'AudioException: $message';
  }
}

/// Excepción específica para archivos de audio
class AudioFileException extends AudioException {
  const AudioFileException(super.message, {super.originalError});

  @override
  String toString() {
    if (originalError != null) {
      return 'AudioFileException: $message (Original: $originalError)';
    }
    return 'AudioFileException: $message';
  }
}

/// Excepción para problemas de reproducción de audio
class AudioPlaybackException extends AudioException {
  const AudioPlaybackException(super.message, {super.originalError});

  @override
  String toString() {
    if (originalError != null) {
      return 'AudioPlaybackException: $message (Original: $originalError)';
    }
    return 'AudioPlaybackException: $message';
  }
}

/// Excepción para problemas de grabación de audio
class AudioRecorderException extends AudioException {
  const AudioRecorderException(super.message, {super.originalError});

  @override
  String toString() {
    if (originalError != null) {
      return 'AudioRecorderException: $message (Original: $originalError)';
    }
    return 'AudioRecorderException: $message';
  }
}

/// Excepción para problemas de permisos de audio
class AudioPermissionException extends AudioException {
  const AudioPermissionException(super.message, {super.originalError});

  @override
  String toString() {
    if (originalError != null) {
      return 'AudioPermissionException: $message (Original: $originalError)';
    }
    return 'AudioPermissionException: $message';
  }
}

/// Excepción para problemas de síntesis de voz
class VoiceSynthesisException extends AudioException {
  const VoiceSynthesisException(super.message, {super.originalError});

  @override
  String toString() {
    if (originalError != null) {
      return 'VoiceSynthesisException: $message (Original: $originalError)';
    }
    return 'VoiceSynthesisException: $message';
  }
}
