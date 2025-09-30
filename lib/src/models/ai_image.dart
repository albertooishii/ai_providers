/// Modelo de imagen generado por proveedores de IA.
///
/// Representa una imagen generada con información completa sobre su creación,
/// incluyendo metadatos del proveedor y datos de la imagen.
///
/// **Campos principales:**
/// - `url`: Ruta del archivo guardado localmente
/// - `prompt`: Prompt usado para generar la imagen
/// - `base64`: Datos raw en base64 (disponible temporalmente durante el proceso)
/// - `createdAtMs`: Timestamp de creación en milisegundos
///
/// **Uso típico:**
/// ```dart
/// final response = await AI.image('Un gato espacial');
/// final image = response.image;
/// if (image != null) {
///   print('Imagen guardada en: ${image.url}');
///   print('Prompt usado: ${image.prompt}');
/// }
/// ```
class AiImage {
  AiImage({this.url, this.prompt, this.base64, this.createdAtMs});

  factory AiImage.fromJson(final Map<String, dynamic> json) {
    return AiImage(
      url: json['url'] as String?,
      prompt: json['prompt'] as String?,
      base64: json['base64'] as String?,
      createdAtMs: json['createdAtMs'] is int
          ? json['createdAtMs'] as int
          : (json['createdAtMs'] is String
              ? int.tryParse(json['createdAtMs'])
              : null),
    );
  }

  final String? url;
  final String? prompt;
  final String? base64;

  /// Unix timestamp in milliseconds when this image/avatar was created.
  final int? createdAtMs;

  Map<String, dynamic> toJson() => {
        if (url != null) 'url': url,
        if (prompt != null) 'prompt': prompt,
        if (base64 != null) 'base64': base64,
        if (createdAtMs != null) 'createdAtMs': createdAtMs,
      };

  AiImage copyWith({
    final String? url,
    final String? prompt,
    final String? base64,
    final int? createdAtMs,
  }) {
    return AiImage(
      url: url ?? this.url,
      prompt: prompt ?? this.prompt,
      base64: base64 ?? this.base64,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }
}
