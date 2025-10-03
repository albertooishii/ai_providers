/// Parámetros específicos para generación de imágenes con validación tipada.
///
/// Esta clase proporciona una interfaz estructurada para configurar la generación
/// de imágenes, evitando strings mágicos y ofreciendo constantes tipadas.
///
/// **Compatibilidad con proveedores:**
/// - **OpenAI**: Los parámetros se mapean directamente a la API (aspectRatio → size, etc.)
/// - **Gemini**: Los parámetros se convierten en instrucciones textuales automáticamente
/// - **Otros**: Comportamiento definido por cada proveedor
///
/// **Tabla de parámetros:**
///
/// | Campo | Tipo | Valores | Descripción |
/// |-------|------|---------|-------------|
/// | `aspectRatio` | `String?` | `auto`, `portrait`, `landscape`, `square` | Relación de aspecto deseada. OpenAI lo convierte a tamaños (`1024x1024`, `1024x1536`, `1536x1024`). `auto` usa formato cuadrado. |
/// | `format` | `String?` | `png`, `webp`, `jpeg` | Formato de exportación cuando el proveedor lo soporta. |
/// | `background` | `String?` | `opaque`, `transparent` | Tipo de fondo: sólido o transparente. |
/// | `fidelity` | `String?` | `low`, `medium`, `high` | Fidelidad de entrada para ediciones/iteraciones. OpenAI usa `low` por defecto. |
/// | `quality` | `String?` | `standard`, `high`, `ultra` | Calidad visual solicitada en proveedores que lo soportan. |
/// | `sourceImageBase64` | `String?` | Base64 string | Imagen base en formato Base64 para editar/iterar. Soportado tanto por OpenAI como Gemini. |
///
/// **Ejemplo de uso:**
/// ```dart
/// const params = AiImageParams(
///   aspectRatio: AiImageAspectRatio.landscape,
///   quality: AiImageQuality.high,
///   format: AiImageFormat.png,
///   background: AiImageBackground.transparent,
///   sourceImageBase64: 'data:image/png;base64,iVBORw0KGgoAAAA...',
/// );
///
/// final image = await AI.image('Logo corporativo moderno', null, params);
/// ```
///
/// Compatible con additionalParams existentes pero con estructura tipada.
class AiImageParams {
  const AiImageParams({
    this.aspectRatio,
    this.format,
    this.background,
    this.fidelity,
    this.quality,
    this.sourceImageBase64,
  });

  /// Factory constructor desde Map&lt;String, dynamic&gt; para compatibilidad
  factory AiImageParams.fromMap(final Map<String, dynamic>? params) {
    if (params == null) return const AiImageParams();

    return AiImageParams(
      aspectRatio: params['aspectRatio'] as String?,
      format: params['format'] as String?,
      background: params['background'] as String?,
      fidelity: params['fidelity'] as String?,
      quality: params['quality'] as String?,
      sourceImageBase64: params['sourceImageBase64'] as String?,
    );
  }

  /// Relación de aspecto de la imagen generada.
  ///
  /// Valores disponibles en [AiImageAspectRatio]:
  /// - `auto`: Formato automático (generalmente cuadrado)
  /// - `portrait`: Vertical (ej. 1024x1536 en OpenAI)
  /// - `landscape`: Horizontal (ej. 1536x1024 en OpenAI)
  /// - `square`: Cuadrado (ej. 1024x1024 en OpenAI)
  final String? aspectRatio;

  /// Formato de archivo de la imagen generada.
  ///
  /// Valores disponibles en [AiImageFormat]:
  /// - `png`: Formato PNG con soporte de transparencia
  /// - `webp`: Formato WebP moderno y eficiente
  /// - `jpeg`: Formato JPEG para imágenes fotográficas
  final String? format;

  /// Tipo de fondo de la imagen.
  ///
  /// Valores disponibles en [AiImageBackground]:
  /// - `opaque`: Fondo sólido (sin transparencia)
  /// - `transparent`: Fondo transparente (requiere formato PNG/WebP)
  final String? background;

  /// Nivel de fidelidad para ediciones e iteraciones.
  ///
  /// Valores disponibles en [AiImageFidelity]:
  /// - `low`: Baja fidelidad, cambios más libres (por defecto en OpenAI)
  /// - `medium`: Fidelidad media, balance entre creatividad y consistencia
  /// - `high`: Alta fidelidad, cambios mínimos y precisos
  final String? fidelity;

  /// Calidad visual de la imagen generada.
  ///
  /// Valores disponibles en [AiImageQuality]:
  /// - `standard`: Calidad estándar, más rápida
  /// - `high`: Alta calidad, mayor detalle
  /// - `ultra`: Máxima calidad disponible (si el proveedor lo soporta)
  final String? quality;

  /// Imagen base en formato Base64 para editar o iterar.
  ///
  /// - Para OpenAI: Se usa como input_image en la API de Responses
  /// - Para Gemini: Se pasa como imagen de contexto para edición
  /// - Formato: `'data:image/png;base64,iVBORw0KGgoAAAA...'` o solo el Base64
  /// - Ejemplo: Imagen previa generada que se quiere modificar
  final String? sourceImageBase64;

  /// Convierte a Map&lt;String, dynamic&gt; para compatibilidad con additionalParams
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if (aspectRatio != null) map['aspectRatio'] = aspectRatio;
    if (format != null) map['format'] = format;
    if (background != null) map['background'] = background;
    if (fidelity != null) map['fidelity'] = fidelity;
    if (quality != null) map['quality'] = quality;
    if (sourceImageBase64 != null) map['sourceImageBase64'] = sourceImageBase64;

    return map;
  }

  /// Copy with para modificaciones inmutables
  AiImageParams copyWith({
    final String? aspectRatio,
    final String? format,
    final String? background,
    final String? fidelity,
    final String? quality,
    final String? sourceImageBase64,
  }) {
    return AiImageParams(
      aspectRatio: aspectRatio ?? this.aspectRatio,
      format: format ?? this.format,
      background: background ?? this.background,
      fidelity: fidelity ?? this.fidelity,
      quality: quality ?? this.quality,
      sourceImageBase64: sourceImageBase64 ?? this.sourceImageBase64,
    );
  }

  @override
  String toString() {
    return 'AiImageParams(aspectRatio: $aspectRatio, '
        'format: $format, background: $background, fidelity: $fidelity, quality: $quality, sourceImageBase64: ${sourceImageBase64?.length ?? 0} chars)';
  }
}

/// Constantes para relaciones de aspecto válidas.
///
/// Define las proporciones de imagen soportadas por los proveedores de IA.
class AiImageAspectRatio {
  /// Aspecto automático (generalmente cuadrado 1:1)
  static const String auto = 'auto';

  /// Formato vertical/retrato (ej. 2:3 → 1024x1536 en OpenAI)
  static const String portrait = 'portrait';

  /// Formato horizontal/paisaje (ej. 3:2 → 1536x1024 en OpenAI)
  static const String landscape = 'landscape';

  /// Formato cuadrado perfecto (1:1 → 1024x1024 en OpenAI)
  static const String square = 'square';
}

/// Constantes para formatos de imagen válidos.
///
/// Define los tipos de archivo soportados por los proveedores.
class AiImageFormat {
  /// PNG con soporte de transparencia, ideal para logos y gráficos
  static const String png = 'png';

  /// WebP moderno y eficiente, balance entre calidad y tamaño
  static const String webp = 'webp';

  /// JPEG para fotografías y contenido realista sin transparencia
  static const String jpeg = 'jpeg';
}

/// Constantes para tipos de fondo de imagen.
///
/// Controla si la imagen tendrá fondo sólido o transparente.
class AiImageBackground {
  /// Fondo sólido, sin transparencia
  static const String opaque = 'opaque';

  /// Fondo transparente (requiere formato PNG o WebP)
  static const String transparent = 'transparent';
}

/// Constantes para niveles de fidelidad en ediciones.
///
/// Controla qué tan estrictamente el modelo debe seguir las entradas previas.
class AiImageFidelity {
  /// Baja fidelidad: permite cambios creativos libres (por defecto OpenAI)
  static const String low = 'low';

  /// Fidelidad media: balance entre creatividad y consistencia
  static const String medium = 'medium';

  /// Alta fidelidad: cambios mínimos, máxima consistencia con entrada
  static const String high = 'high';
}

/// Constantes para niveles de calidad de imagen.
///
/// Define la calidad visual solicitada al proveedor de IA.
class AiImageQuality {
  /// Calidad estándar: generación más rápida, menor detalle
  static const String standard = 'standard';

  /// Alta calidad: mayor detalle y tiempo de procesamiento
  static const String high = 'high';

  /// Calidad ultra: máxima calidad disponible (si el proveedor lo soporta)
  static const String ultra = 'ultra';
}
