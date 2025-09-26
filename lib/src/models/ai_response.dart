class AIResponse {
  AIResponse({
    required this.text,
    this.seed = '',
    this.prompt = '',
    this.imageFileName = '',
    this.audioFileName = '',
    this.imageBase64,
    this.audioBase64,
  });

  factory AIResponse.fromJson(final Map<String, dynamic> json) {
    final image = json['image'] ?? {};
    return AIResponse(
      text: json['text'] ?? '',
      seed: image['seed'] ?? '',
      prompt: image['prompt'] ?? '',
      imageFileName: image['file_name'] ?? '',
      audioFileName: json['audio'] is Map
          ? (json['audio']['file_name'] ?? '')
          : (json['audio_file_name'] ?? ''),
      imageBase64: image['base64'],
      audioBase64:
          json['audio'] is Map ? json['audio']['base64'] : json['audio_base64'],
    );
  }
  final String text;
  final String seed;
  final String prompt;
  final String imageFileName;
  final String audioFileName;

  /// Raw image data as base64 string (preferred for direct use)
  final String? imageBase64;

  /// Raw audio data as base64 string (preferred for direct use)
  final String? audioBase64;

  Map<String, dynamic> toJson() => {
        'text': text,
        'image': {
          'seed': seed,
          'prompt': prompt,
          'file_name': imageFileName,
          'base64': imageBase64,
        },
        'audio': {
          'file_name': audioFileName,
          'base64': audioBase64,
        },
      };
}
