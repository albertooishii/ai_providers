import 'dart:async';
import 'dart:convert';
import 'dart:io';
// dart:typed_data removed - no longer needed

import '../core/provider_registry.dart';
import '../models/additional_params.dart';
import '../models/provider_response.dart';
import '../models/ai_provider_metadata.dart';
import '../models/ai_system_prompt.dart';
import '../models/ai_image_params.dart';
import '../models/ai_audio_params.dart';
// RealtimeClient removed - replaced by HybridConversationService

import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import '../models/ai_capability.dart';
import '../models/audio_models.dart';
import '../core/base_provider.dart';

/// OpenAI provider - optimized and without hardcodes
class OpenAIProvider extends BaseProvider {
  OpenAIProvider(super.config);

  static void register() {
    ProviderRegistry.instance.registerConstructor(
        'openai', (final config) => OpenAIProvider(config));
  }

  @override
  String get providerId => 'openai';

  @override
  AIProviderMetadata createMetadata() {
    return AIProviderMetadata(
      providerId: providerId,
      providerName: config.displayName,
      company: 'OpenAI',
      version: '1.0.0',
      description: config.description,
      supportedCapabilities: config.capabilities,
      defaultModels: config.defaults,
      availableModels: config.models,
      rateLimits: {
        'requests_per_minute': config.rateLimits.requestsPerMinute,
        'tokens_per_minute': config.rateLimits.tokensPerMinute,
      },
      requiresAuthentication: true,
      requiredConfigKeys: config.apiSettings.requiredEnvKeys,
      maxContextTokens: config.configuration.maxContextTokens,
      maxOutputTokens: config.configuration.maxOutputTokens,
      supportsStreaming: config.configuration.supportsStreaming,
      supportsFunctionCalling: config.configuration.supportsFunctionCalling,
    );
  }

  @override
  Map<String, String> buildAuthHeaders() {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'OpenAI-Beta': 'assistants=v2'
    };
  }

  @override
  Future<List<String>?> fetchModelsFromAPI() async {
    try {
      final url = Uri.parse(getEndpointUrl('models'));
      final response =
          await http.Client().get(url, headers: buildAuthHeaders());

      if (isSuccessfulResponse(response.statusCode)) {
        final data = jsonDecode(response.body);
        final models = (data['data'] as List<dynamic>)
            .map((final model) => model['id'] as String)
            .where((final model) => isValidModelForProvider(model))
            .toList();

        // Apply priority-based sorting
        models.sort(compareModels);
        return models;
      }
      return null;
    } on Exception catch (_) {
      return null;
    }
  }

  @override
  int compareModels(final String a, final String b) {
    final priorityA = _getModelPriority(a);
    final priorityB = _getModelPriority(b);
    return priorityA != priorityB
        ? priorityA.compareTo(priorityB)
        : b.compareTo(a);
  }

  int _getModelPriority(final String model) {
    final m = model.toLowerCase();
    if (m == 'gpt-5') return 1;
    if (m.startsWith('gpt-5')) return 2;
    if (m == 'gpt-4.1') return 3;
    if (m.startsWith('gpt-4.1')) return 4;
    if (m.startsWith('gpt-4o')) return 5;
    if (m.startsWith('gpt-4')) return 6;
    if (m.startsWith('gpt-3.5')) return 7;
    if (m.contains('realtime')) return 8;
    return 99;
  }

  @override
  ({
    List<Map<String, dynamic>> history,
    AISystemPrompt systemPromptWithoutHistory
  }) processHistory(final AISystemPrompt systemPrompt) {
    // Extract history
    final history = systemPrompt.history ?? <Map<String, dynamic>>[];

    // Create new AISystemPrompt without history to avoid duplication
    final systemPromptWithoutHistory = AISystemPrompt(
      context: systemPrompt.context,
      dateTime: systemPrompt.dateTime,
      instructions: systemPrompt.instructions,
      // history defaults to null - omitted to prevent duplication
    );

    return (
      history: history,
      systemPromptWithoutHistory: systemPromptWithoutHistory,
    );
  }

  @override
  Future<ProviderResponse> sendMessage({
    required final AISystemPrompt systemPrompt,
    required final AICapability capability,
    final String? model,
    final String? imageBase64,
    final String? imageMimeType,
    final AdditionalParams? additionalParams,
    final String? voice,
  }) async {
    switch (capability) {
      case AICapability.textGeneration:
      case AICapability.imageAnalysis:
        return _sendTextRequest(
            systemPrompt, model, imageBase64, imageMimeType, additionalParams);
      case AICapability.imageGeneration:
        return _sendImageGenerationRequest(
            systemPrompt, model, additionalParams);
      case AICapability.audioGeneration:
        return _sendTTSRequest(systemPrompt, model, additionalParams, voice);
      case AICapability.audioTranscription:
        return _sendTranscriptionRequest(
          imageBase64 ?? '',
          systemPrompt,
          model,
        );
      case AICapability.realtimeConversation:
        return _handleRealtimeRequest(systemPrompt, model, additionalParams);
    }
  }

  Future<ProviderResponse> _sendTextRequest(
    final AISystemPrompt systemPrompt,
    final String? model,
    final String? imageBase64,
    final String? imageMimeType,
    final AdditionalParams? additionalParams,
  ) async {
    try {
      final selectedModel =
          model ?? getDefaultModel(AICapability.textGeneration);

      if (selectedModel == null || !isValidModelForProvider(selectedModel)) {
        AILogger.w('[OpenAIProvider] ❌ Invalid model: $selectedModel');
        return ProviderResponse(
            text: 'Error: Invalid or missing model for OpenAI provider');
      }

      // Build input text from systemPrompt (includes system prompt and history)
      final inputText = _buildInputText(systemPrompt);

      final bodyMap = <String, dynamic>{
        'model': selectedModel,
      };

      // Different formats based on content type
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        // Vision format (as per your example)
        bodyMap['input'] = [
          {
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': inputText},
              {
                'type': 'input_image',
                'image_url':
                    'data:${imageMimeType ?? 'image/jpeg'};base64,$imageBase64'
              }
            ]
          }
        ];
      } else {
        // Regular text format
        bodyMap['input'] = inputText;
      }

      final url = Uri.parse(getEndpointUrl('chat'));
      final headers = buildAuthHeaders();
      final bodyJson = jsonEncode(bodyMap);

      final response =
          await http.Client().post(url, headers: headers, body: bodyJson);

      if (isSuccessfulResponse(response.statusCode)) {
        return _processTextResponse(jsonDecode(response.body));
      } else {
        final hasMoreKeys = handleApiError(
            response.statusCode, response.body, 'text_generation');
        if (!hasMoreKeys) {
          // Lanzar excepción específica que evite retry
          throw StateError(
              'All OpenAI API keys have been exhausted - no retry needed');
        }
        throw HttpException(
            '${response.statusCode} ${response.reasonPhrase ?? ''}: ${response.body}');
      }
    } on Exception catch (e) {
      AILogger.e('[OpenAIProvider] Text request failed: $e');
      rethrow;
    }
  }

  ProviderResponse _processTextResponse(final Map<String, dynamic> data) {
    String text = '';
    String imageBase64Output = '';
    String imageId = '';
    String revisedPrompt = '';

    // Check for vision response format (output_text)
    if (data['output_text'] is String) {
      text = data['output_text'] as String;
      return ProviderResponse(text: text);
    }

    // Check for standard output array format
    final output = data['output'] ?? data['data'];
    if (output is List && output.isNotEmpty) {
      for (final item in output) {
        final type = item['type'];
        if (type == 'image_generation_call') {
          if (item['result'] != null && imageBase64Output.isEmpty) {
            imageBase64Output = item['result'] as String;
          }
          if (item['id'] != null && imageId.isEmpty) imageId = item['id'];
          if (item['revised_prompt'] != null && revisedPrompt.isEmpty) {
            revisedPrompt = item['revised_prompt'];
          }
          if (text.trim().isEmpty && item['text'] != null) {
            text = item['text'];
          }
        } else if (type == 'message') {
          if (item['content'] != null && item['content'] is List) {
            for (final c in item['content']) {
              if (text.trim().isEmpty &&
                  c is Map &&
                  c['type'] == 'output_text' &&
                  c['text'] != null) {
                text = c['text'];
              }
            }
          }
        }
      }
    }

    return ProviderResponse(
      text: text.trim().isNotEmpty ? text : '',
      prompt: revisedPrompt.trim(),
      imageBase64: imageBase64Output,
    );
  }

  Future<ProviderResponse> _sendImageGenerationRequest(
    final AISystemPrompt systemPrompt,
    final String? model,
    final AdditionalParams? additionalParams,
  ) async {
    // Get prompt from last message in systemPrompt.history
    final history = systemPrompt.history ?? [];
    final prompt =
        history.isNotEmpty ? history.last['content']?.toString() ?? '' : '';
    if (prompt.isEmpty) {
      return ProviderResponse(
          text: 'Error: No prompt provided for image generation.');
    }

    try {
      final selectedModel =
          model ?? getDefaultModel(AICapability.imageGeneration);

      if (selectedModel == null || !isValidModelForProvider(selectedModel)) {
        return ProviderResponse(
            text:
                'Error: Invalid or missing model for OpenAI image generation');
      }

      // Extract image parameters from wrapper
      final imageParams =
          additionalParams?.imageParams ?? const AiImageParams();
      final inputText = _buildInputText(systemPrompt);

      final bodyMap = <String, dynamic>{
        'model': selectedModel,
      };

      // Build image generation request directly (no duplication with text flow)
      _buildImageGenerationRequest(
          bodyMap, systemPrompt, inputText, imageParams);

      // Execute HTTP request with shared logic
      final url = Uri.parse(getEndpointUrl('chat'));
      final headers = buildAuthHeaders();
      final bodyJson = jsonEncode(bodyMap);

      final response =
          await http.Client().post(url, headers: headers, body: bodyJson);

      if (isSuccessfulResponse(response.statusCode)) {
        return _processTextResponse(jsonDecode(response.body));
      } else {
        final hasMoreKeys = handleApiError(
            response.statusCode, response.body, 'image_generation');
        if (!hasMoreKeys) {
          // Lanzar excepción específica que evite retry
          throw StateError(
              'All OpenAI API keys have been exhausted - no retry needed');
        }
        throw HttpException(
            '${response.statusCode} ${response.reasonPhrase ?? ''}: ${response.body}');
      }
    } on Exception catch (e) {
      AILogger.e('[OpenAIProvider] Image generation failed: $e');
      return ProviderResponse(text: 'Error generating image: $e');
    }
  }

  Future<ProviderResponse> _sendTTSRequest(
    final AISystemPrompt systemPrompt,
    final String? model,
    final AdditionalParams? additionalParams,
    final String? voice,
  ) async {
    // Get text from last message in systemPrompt.history
    final history = systemPrompt.history ?? [];
    final text =
        history.isNotEmpty ? history.last['content']?.toString() ?? '' : '';
    if (text.isEmpty) {
      return ProviderResponse(text: 'Error: No text provided for TTS.');
    }

    final selectedModel =
        model ?? getDefaultModel(AICapability.audioGeneration);

    // Extract audio parameters from wrapper
    final audioParams = additionalParams?.audioParams ?? const AiAudioParams();

    // Use voice parameter directly with fallback to default
    final selectedVoice = voice ?? getDefaultVoice();
    final speed = audioParams.speed; // Siempre tiene valor por defecto (1.0)
    final responseFormat =
        audioParams.audioFormat; // ✅ Siempre tiene valor por defecto 'pcm'

    final payload = <String, dynamic>{
      'model': selectedModel,
      'input': text,
      'voice': selectedVoice,
      'speed': speed,
      'response_format': responseFormat,
    };

    // ✅ Combinar accent + emotion en instructions para OpenAI
    final instructions = _buildOpenAIInstructions(audioParams);
    if (instructions.isNotEmpty) {
      payload['instructions'] = instructions;
    }

    // Añadir language si está disponible (para algunos modelos de OpenAI)
    if (audioParams.language != null) {
      payload['language'] = audioParams.language;
    }

    try {
      final url = Uri.parse(getEndpointUrl('audio_speech'));
      final response = await http.Client()
          .post(url, headers: buildAuthHeaders(), body: jsonEncode(payload));

      if (isSuccessfulResponse(response.statusCode)) {
        return ProviderResponse(
            text: 'Audio generated successfully',
            audioBase64: base64Encode(response.bodyBytes));
      } else {
        return ProviderResponse(
            text: 'Error generating audio: ${response.statusCode}');
      }
    } on Exception catch (e) {
      return ProviderResponse(text: 'Error connecting to OpenAI TTS: $e');
    }
  }

  Future<ProviderResponse> _sendTranscriptionRequest(
    final String audioBase64,
    final AISystemPrompt systemPrompt,
    final String? model,
  ) async {
    try {
      final audioBytes = base64Decode(audioBase64);
      final tempFile = File(
          '${Directory.systemTemp.path}/whisper_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(audioBytes);

      try {
        final url = Uri.parse(getEndpointUrl('audio_transcriptions'));
        final request = http.MultipartRequest('POST', url);

        request.headers['Authorization'] = 'Bearer $apiKey';
        request.fields['model'] = model ??
            getDefaultModel(AICapability.audioTranscription) ??
            defaults['transcription_model'];

        // Usar Context como prompt para OpenAI
        final promptText = _buildPromptFromContext(systemPrompt);
        if (promptText.isNotEmpty) {
          request.fields['prompt'] = promptText;
        }

        request.files
            .add(await http.MultipartFile.fromPath('file', tempFile.path));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (isSuccessfulResponse(response.statusCode)) {
          final data = jsonDecode(response.body);
          return ProviderResponse(text: data['text'] as String? ?? '');
        } else {
          return ProviderResponse(
              text: 'Error transcribing audio: ${response.statusCode}');
        }
      } finally {
        if (tempFile.existsSync()) await tempFile.delete();
      }
    } on Exception catch (e) {
      return ProviderResponse(text: 'Error connecting to OpenAI STT: $e');
    }
  }

  Future<ProviderResponse> _handleRealtimeRequest(
    final AISystemPrompt systemPrompt,
    final String? model,
    final AdditionalParams? additionalParams,
  ) async {
    if (!supportsCapability(AICapability.realtimeConversation)) {
      return ProviderResponse(
          text:
              'Realtime conversation not supported by this OpenAI provider configuration');
    }

    final realtimeModel =
        model ?? getDefaultModel(AICapability.realtimeConversation);
    return ProviderResponse(
      text:
          'Realtime conversation session configured successfully. Provider: openai, Model: $realtimeModel, History: ${systemPrompt.history?.length ?? 0} messages',
    );
  }

  /// DEPRECATED: Legacy method - use AI.speak() instead
  /// Voice is now managed through AI.setSelectedVoiceForProvider()
  @Deprecated(
      'Use AI.speak() with voice management via AI.setSelectedVoiceForProvider()')
  Future<ProviderResponse> generateAudio({
    required final String text,
    final String? voice,
    final String? model,
    final AdditionalParams? additionalParams,
  }) async {
    // Create a simple context for TTS request
    final ttsContext = AISystemPrompt(
      context: {'instructions': 'Convert text to speech'},
      dateTime: DateTime.now(),
      instructions: {'role': 'Convert the given text to speech'},
      history: [
        {'role': 'user', 'content': text}
      ],
    );
    return _sendTTSRequest(
      ttsContext,
      model,
      additionalParams,
      voice,
    );
  }

  Future<ProviderResponse> transcribeAudio({
    required final String audioBase64,
    final String? model,
    final AISystemPrompt? systemPrompt,
  }) async {
    final effectiveContext = systemPrompt ??
        AISystemPrompt(
          context: {'task': 'audio_transcription'},
          dateTime: DateTime.now(),
          instructions: {},
        );
    return _sendTranscriptionRequest(audioBase64, effectiveContext, model);
  }

  /// [REMOVED] createRealtimeClient - Replaced by HybridConversationService
  /// Use HybridConversationService for real-time conversation features

  bool supportsRealtimeForModel(final String? model) {
    if (model == null) {
      return supportsCapability(AICapability.realtimeConversation);
    }
    final realtimeModels =
        availableModels[AICapability.realtimeConversation] ?? [];
    return realtimeModels.contains(model) || model.contains('realtime');
  }

  List<String> getAvailableRealtimeModels() {
    return supportsCapability(AICapability.realtimeConversation)
        ? availableModels[AICapability.realtimeConversation] ?? []
        : [];
  }

  bool get supportsRealtime =>
      supportsCapability(AICapability.realtimeConversation);

  String? get defaultRealtimeModel => supportsRealtime
      ? getDefaultModel(AICapability.realtimeConversation)
      : null;

  // Voice management from config
  static final List<VoiceInfo> _availableVoices = [
    const VoiceInfo(
        id: 'sage', name: 'sage', language: 'en', gender: VoiceGender.female),
    const VoiceInfo(
        id: 'alloy', name: 'alloy', language: 'en', gender: VoiceGender.female),
    const VoiceInfo(
        id: 'ash', name: 'ash', language: 'en', gender: VoiceGender.male),
    const VoiceInfo(
        id: 'ballad',
        name: 'ballad',
        language: 'en',
        gender: VoiceGender.female),
    const VoiceInfo(
        id: 'coral', name: 'coral', language: 'en', gender: VoiceGender.female),
    const VoiceInfo(
        id: 'echo', name: 'echo', language: 'en', gender: VoiceGender.male),
    const VoiceInfo(
        id: 'fable', name: 'fable', language: 'en', gender: VoiceGender.female),
    const VoiceInfo(
        id: 'onyx', name: 'onyx', language: 'en', gender: VoiceGender.male),
    const VoiceInfo(
        id: 'nova', name: 'nova', language: 'en', gender: VoiceGender.female),
    const VoiceInfo(
        id: 'shimmer',
        name: 'shimmer',
        language: 'en',
        gender: VoiceGender.female),
    const VoiceInfo(
        id: 'verse', name: 'verse', language: 'en', gender: VoiceGender.male),
    const VoiceInfo(
        id: 'cedar', name: 'cedar', language: 'en', gender: VoiceGender.male),
    const VoiceInfo(
        id: 'marin', name: 'marin', language: 'en', gender: VoiceGender.female),
  ];

  Future<List<VoiceInfo>> getAvailableVoices() async => _availableVoices;
  VoiceGender getVoiceGender(final String voiceName) {
    return _availableVoices
        .firstWhere(
          (final v) => v.name.toLowerCase() == voiceName.toLowerCase(),
          orElse: () => const VoiceInfo(
              id: 'default',
              name: 'default',
              language: 'en',
              gender: VoiceGender.neutral),
        )
        .gender;
  }

  List<String> getVoiceNames() =>
      _availableVoices.map((final v) => v.name).toList();
  bool isValidVoice(final String voiceName) => _availableVoices
      .any((final v) => v.name.toLowerCase() == voiceName.toLowerCase());

  // === FUNCIONES PRIVADAS PARA ORGANIZAR LÓGICA ===

  /// Construye el texto de input combinando system prompt e historial desde systemPrompt
  String _buildInputText(final AISystemPrompt systemPrompt) {
    // Use processHistory to extract history and clean systemPrompt
    final (:history, :systemPromptWithoutHistory) =
        processHistory(systemPrompt);

    // Use systemPrompt WITHOUT history (agnostic approach)
    String inputText = systemPromptWithoutHistory.toString();

    // Add messages from extracted history
    for (final msg in history) {
      inputText += '\n${msg['content']?.toString() ?? ''}';
    }

    return inputText;
  }

  /// Construye la request completa para generación de imágenes
  void _buildImageGenerationRequest(
    final Map<String, dynamic> bodyMap,
    final AISystemPrompt systemPrompt,
    final String inputText,
    final AiImageParams imageParams,
  ) {
    // Construir input array similar al servicio antiguo
    final input = _buildImageInputArray(systemPrompt, inputText, imageParams);

    // Construir tools con parámetros de imagen
    final tools = _buildImageTools(imageParams);

    // Construir body final
    bodyMap['input'] = input;
    bodyMap['tools'] = tools;
  }

  /// Construye el array de input para generación de imágenes
  List<Map<String, dynamic>> _buildImageInputArray(
      final AISystemPrompt systemPrompt,
      final String inputText,
      final AiImageParams imageParams) {
    final input = <Map<String, dynamic>>[];

    // System prompt (agnostic approach - use systemPrompt WITHOUT history)
    final (:history, :systemPromptWithoutHistory) =
        processHistory(systemPrompt);
    input.add({
      'role': 'system',
      'content': [
        {'type': 'input_text', 'text': systemPromptWithoutHistory.toString()},
      ],
    });

    // User content
    final userContent = <dynamic>[
      {'type': 'input_text', 'text': inputText},
    ];

    // Agregar imagen source si está disponible (para edición)
    if (_hasSourceImageForEditing(imageParams)) {
      final sourceImage = imageParams.sourceImageBase64!;
      final imageUrl = sourceImage.startsWith('data:')
          ? sourceImage
          : 'data:image/png;base64,$sourceImage';

      userContent.add({
        'type': 'input_image',
        'image_url': imageUrl,
      });
    }

    input.add({'role': 'user', 'content': userContent});

    return input;
  }

  /// Construye los tools con parámetros de imagen
  List<Map<String, dynamic>> _buildImageTools(final AiImageParams imageParams) {
    final tools = <Map<String, dynamic>>[
      {
        'type': 'image_generation',
        'moderation': 'low',
      }
    ];

    // Mapear parámetros de imagen a tools
    final tool = tools[0];

    // Fidelity con default
    tool['input_fidelity'] = imageParams.fidelity ?? 'low';

    // Background con default
    tool['background'] = imageParams.background ?? 'opaque';

    // Quality opcional
    if (imageParams.quality != null) {
      tool['quality'] = imageParams.quality;
    }

    // Format opcional
    if (imageParams.format != null) {
      tool['output_format'] = imageParams.format;
    }

    // Mapear aspectRatio a size
    final derivedSize = _mapAspectRatioToSize(imageParams.aspectRatio);
    tool['size'] = derivedSize;

    return tools;
  }

  /// Mapea aspectRatio a size específico de la API
  String _mapAspectRatioToSize(final String? aspectRatio) {
    switch (aspectRatio) {
      case AiImageAspectRatio.square:
        return '1024x1024';
      case AiImageAspectRatio.portrait:
        return '1024x1536';
      case AiImageAspectRatio.landscape:
        return '1536x1024';
      case AiImageAspectRatio.auto:
        return '1024x1024'; // Auto defaults to square
      default:
        return '1024x1024'; // Default square
    }
  }

  /// Maneja sourceImageBase64 para edición de imágenes usando la API de Responses
  bool _hasSourceImageForEditing(final AiImageParams imageParams) {
    return imageParams.sourceImageBase64 != null &&
        imageParams.sourceImageBase64!.isNotEmpty;
  }

  /// Construye instructions de OpenAI combinando accent y emotion
  String _buildOpenAIInstructions(final AiAudioParams audioParams) {
    final parts = <String>[];

    // Añadir acento si está especificado
    if (audioParams.accent != null && audioParams.accent!.isNotEmpty) {
      parts.add(audioParams.accent!);
    }

    // Añadir emoción si está especificada
    if (audioParams.emotion != null && audioParams.emotion!.isNotEmpty) {
      parts.add(audioParams.emotion!);
    }

    // Combinar con punto y seguido para claridad
    return parts.join('. ');
  }

  /// Construye prompt para transcripción desde Context
  String _buildPromptFromContext(final AISystemPrompt systemPrompt) {
    final parts = <String>[];

    // Agregar contexto si hay
    if (systemPrompt.context.isNotEmpty) {
      final contextStr = systemPrompt.context.toString();
      if (contextStr.isNotEmpty && contextStr != '{}') {
        parts.add(contextStr);
      }
    }

    // Agregar instrucciones si hay
    if (systemPrompt.instructions.isNotEmpty) {
      final instructionsStr = systemPrompt.instructions.toString();
      if (instructionsStr.isNotEmpty && instructionsStr != '{}') {
        parts.add(instructionsStr);
      }
    }

    return parts.join(' ');
  }
}
