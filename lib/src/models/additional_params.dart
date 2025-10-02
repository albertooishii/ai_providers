/// Wrapper for type-safe additional parameters
/// Internal use only - not exported in public API
library;

import 'ai_image_params.dart';
import 'ai_audio_params.dart';

/// Sealed class wrapper for additional parameters
/// Allows pattern matching and type-safe parameter handling internally
/// AiImageParams and AiAudioParams remain independent - this wraps them for internal use
sealed class AdditionalParams {
  const AdditionalParams();

  /// Create from AiImageParams
  factory AdditionalParams.image(final AiImageParams params) = _ImageWrapper;

  /// Create from AiAudioParams
  factory AdditionalParams.audio(final AiAudioParams params) = _AudioWrapper;

  /// Create from Map (for backward compatibility)
  /// Detects type and returns appropriate wrapper
  factory AdditionalParams.fromMap(final Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const _EmptyParams();
    }

    // Try to parse as AiImageParams first
    try {
      final imageParams = AiImageParams.fromMap(map);
      if (imageParams.aspectRatio != null ||
          imageParams.format != null ||
          imageParams.quality != null ||
          imageParams.fidelity != null) {
        return _ImageWrapper(imageParams);
      }
    } on Exception catch (_) {
      // Not image params, continue
    }

    // Try to parse as AiAudioParams
    try {
      final audioParams = AiAudioParams.fromMap(map);
      if (audioParams.speed != 1.0 ||
          audioParams.emotion != null ||
          audioParams.accent != null ||
          audioParams.language != null ||
          audioParams.temperature != null) {
        return _AudioWrapper(audioParams);
      }
    } on Exception catch (_) {
      // Not audio params, continue
    }

    // Default to empty if we can't determine type
    return const _EmptyParams();
  }

  /// Convert to Map for provider compatibility
  Map<String, dynamic> toMap();

  /// Get image params if this wrapper contains them
  AiImageParams? get imageParams => null;

  /// Get audio params if this wrapper contains them
  AiAudioParams? get audioParams => null;
}

/// Image parameters wrapper
final class _ImageWrapper extends AdditionalParams {
  const _ImageWrapper(this.params);

  final AiImageParams params;

  @override
  Map<String, dynamic> toMap() => params.toMap();

  @override
  AiImageParams? get imageParams => params;

  @override
  String toString() => 'ImageParams(${params.toString()})';
}

/// Audio parameters wrapper
final class _AudioWrapper extends AdditionalParams {
  const _AudioWrapper(this.params);

  final AiAudioParams params;

  @override
  Map<String, dynamic> toMap() => params.toMap();

  @override
  AiAudioParams? get audioParams => params;

  @override
  String toString() => 'AudioParams(${params.toString()})';
}

/// Empty parameters (no additional params provided)
final class _EmptyParams extends AdditionalParams {
  const _EmptyParams();

  @override
  Map<String, dynamic> toMap() => {};

  @override
  String toString() => 'EmptyParams()';
}
