import 'ai_image.dart';
import 'ai_audio.dart';

/// Respuesta unificada de proveedores de IA.
///
/// Contiene el resultado de operaciones de IA (generación de texto, imágenes, audio, etc.)
/// con una estructura consistente independientemente del proveedor utilizado.
///
/// **Estructura:**
/// - `text`: Contenido textual generado (siempre presente)
/// - `provider`: Identificador del proveedor que generó la respuesta
/// - `image`: Imagen generada (opcional, solo en generación de imágenes)
/// - `audio`: Audio generado (opcional, solo en TTS/STT)
///
/// **Casos de uso:**
///
/// **Generación de texto:**
/// ```dart
/// final response = await AI.text('Explica la fotosíntesis');
/// print(response.text); // Explicación generada
/// // image y audio serán null
/// ```
///
/// **Generación de imágenes:**
/// ```dart
/// final response = await AI.image('Un paisaje futurista');
/// print(response.text);          // Descripción o prompt procesado
/// print(response.image?.url);    // Ruta del archivo de imagen guardado
/// print(response.image?.prompt); // Prompt usado para generación
/// ```
///
/// **Síntesis de voz (TTS):**
/// ```dart
/// final response = await AI.speak('¡Hola mundo!');
/// print(response.text);        // Texto sintetizado
/// print(response.audio?.url);  // Ruta del archivo de audio guardado
/// ```
///
/// **Transcripción con grabación (STT):**
/// ```dart
/// final response = await AI.listen();
/// print(response.text);               // Transcripción del audio
/// print(response.audio?.url);         // Ruta del archivo de audio grabado
/// print(response.audio?.base64);      // Audio en base64 para envío
/// print(response.audio?.transcript);  // Mismo contenido textual
/// ```
class AIResponse {
  AIResponse({
    required this.text,
    required this.provider,
    this.image,
    this.audio,
  });

  factory AIResponse.fromJson(final Map<String, dynamic> json) {
    return AIResponse(
      text: json['text'] ?? '',
      provider: json['provider'] ?? '',
      image: json['image'] != null ? AiImage.fromJson(json['image']) : null,
      audio: json['audio'] != null ? AiAudio.fromJson(json['audio']) : null,
    );
  }

  final String text;
  final String provider;
  final AiImage? image;
  final AiAudio? audio;

  Map<String, dynamic> toJson() => {
        'text': text,
        'provider': provider,
        if (image != null) 'image': image!.toJson(),
        if (audio != null) 'audio': audio!.toJson(),
      };
}
