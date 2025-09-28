/// Parámetros específicos para generación de imágenes
/// Compatible con additionalParams existentes pero con estructura tipada
class AiImageParams {
  const AiImageParams({
    this.enableImageGeneration,
    this.aspectRatio,
    this.format,
    this.background,
    this.fidelity,
    this.quality,
    this.seed,
  });

  /// Factory constructor desde Map&lt;String, dynamic&gt; para compatibilidad
  factory AiImageParams.fromMap(final Map<String, dynamic>? params) {
    if (params == null) return const AiImageParams();

    return AiImageParams(
      enableImageGeneration: params['enableImageGeneration'] as bool?,
      aspectRatio: params['aspectRatio'] as String?,
      format: params['format'] as String?,
      background: params['background'] as String?,
      fidelity: params['fidelity'] as String?,
      quality: params['quality'] as String?,
      seed: params['seed'] as String?,
    );
  }

  /// Si debe generar imagen (true/false)
  final bool? enableImageGeneration;

  /// Relación de aspecto: auto, portrait, landscape, square
  final String? aspectRatio;

  /// Formato de salida: png, webp, jpeg
  final String? format;

  /// Fondo: opaque, transparent
  final String? background;

  /// Calidad/fidelidad para edición: low, medium, high
  final String? fidelity;

  /// Calidad de imagen: standard, high, ultra
  final String? quality;

  /// Seed para consistencia visual
  final String? seed;

  /// Convierte a Map&lt;String, dynamic&gt; para compatibilidad con additionalParams
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if (enableImageGeneration != null) {
      map['enableImageGeneration'] = enableImageGeneration;
    }
    if (aspectRatio != null) map['aspectRatio'] = aspectRatio;
    if (format != null) map['format'] = format;
    if (background != null) map['background'] = background;
    if (fidelity != null) map['fidelity'] = fidelity;
    if (quality != null) map['quality'] = quality;
    if (seed != null) map['seed'] = seed;

    return map;
  }

  /// Merge con otros parámetros manteniendo compatibilidad
  Map<String, dynamic> mergeWithAdditionalParams(
      final Map<String, dynamic>? additionalParams) {
    final imageParams = toMap();
    final combined = <String, dynamic>{};

    // Primero añadir parámetros adicionales existentes
    if (additionalParams != null) {
      combined.addAll(additionalParams);
    }

    // Luego sobrescribir con parámetros de imagen específicos (mayor prioridad)
    combined.addAll(imageParams);

    return combined;
  }

  /// Copy with para modificaciones inmutables
  AiImageParams copyWith({
    final bool? enableImageGeneration,
    final String? aspectRatio,
    final String? format,
    final String? background,
    final String? fidelity,
    final String? quality,
    final String? seed,
  }) {
    return AiImageParams(
      enableImageGeneration:
          enableImageGeneration ?? this.enableImageGeneration,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      format: format ?? this.format,
      background: background ?? this.background,
      fidelity: fidelity ?? this.fidelity,
      quality: quality ?? this.quality,
      seed: seed ?? this.seed,
    );
  }

  @override
  String toString() {
    return 'AiImageParams(enableImageGeneration: $enableImageGeneration, aspectRatio: $aspectRatio, '
        'format: $format, background: $background, fidelity: $fidelity, quality: $quality, seed: $seed)';
  }
}

/// Constantes para valores válidos
class AiImageAspectRatio {
  static const String auto = 'auto';
  static const String portrait = 'portrait';
  static const String landscape = 'landscape';
  static const String square = 'square';
}

class AiImageFormat {
  static const String png = 'png';
  static const String webp = 'webp';
  static const String jpeg = 'jpeg';
}

class AiImageBackground {
  static const String opaque = 'opaque';
  static const String transparent = 'transparent';
}

class AiImageFidelity {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';
}

class AiImageQuality {
  static const String standard = 'standard';
  static const String high = 'high';
  static const String ultra = 'ultra';
}
