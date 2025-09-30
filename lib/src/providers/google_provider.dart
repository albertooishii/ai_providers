import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/provider_registry.dart';
import '../models/provider_response.dart';
import '../models/ai_provider_metadata.dart';
import '../models/ai_context.dart';
import '../models/ai_audio_params.dart';

import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import '../models/ai_capability.dart';
import '../models/audio_models.dart';
import '../core/base_provider.dart';

/// Google Gemini provider - Complete Gemini API integration with native TTS/STT
class GoogleProvider extends BaseProvider {
  GoogleProvider(super.config);

  static void register() {
    ProviderRegistry.instance.registerConstructor(
        'google', (final config) => GoogleProvider(config));
  }

  @override
  String get providerId => 'google';

  @override
  AIProviderMetadata createMetadata() {
    return AIProviderMetadata(
      providerId: providerId,
      providerName: config.displayName,
      company: 'Google',
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
    return {'Content-Type': 'application/json', 'x-goog-api-key': apiKey};
  }

  @override
  Future<List<String>?> fetchModelsFromAPI() async {
    try {
      final url = Uri.parse(getEndpointUrl('models'));
      final response =
          await http.Client().get(url, headers: buildAuthHeaders());

      if (isSuccessfulResponse(response.statusCode)) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List<dynamic>)
            .map((final model) =>
                (model['name'] as String).replaceFirst('models/', ''))
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
    if (m.contains('experimental')) return 1;
    if (m.contains('flash')) return 2;
    if (m.contains('pro')) return 3;
    if (m.contains('nano')) return 4;
    return 99;
  }

  @override
  Future<ProviderResponse> sendMessage({
    required final AIContext aiContext,
    required final AICapability capability,
    final String? model,
    final String? imageBase64,
    final String? imageMimeType,
    final Map<String, dynamic>? additionalParams,
  }) async {
    switch (capability) {
      case AICapability.textGeneration:
      case AICapability.imageAnalysis:
        return _sendTextRequest(
            aiContext, model, imageBase64, imageMimeType, additionalParams);
      case AICapability.imageGeneration:
        return _sendImageGenerationRequest(aiContext, model, additionalParams);
      case AICapability.audioGeneration:
        return _sendTTSRequest(aiContext, model, additionalParams);
      case AICapability.audioTranscription:
        return _sendTranscriptionRequest(
          imageBase64 ?? '',
          aiContext,
          model,
        );
      case AICapability.realtimeConversation:
        return _handleRealtimeRequest(aiContext, model, additionalParams);
    }
  }

  Future<ProviderResponse> _sendTextRequest(
    final AIContext aiContext,
    final String? model,
    final String? imageBase64,
    final String? imageMimeType,
    final Map<String, dynamic>? additionalParams,
  ) async {
    try {
      final selectedModel =
          model ?? getDefaultModel(AICapability.textGeneration);
      if (selectedModel == null || !isValidModelForProvider(selectedModel)) {
        return ProviderResponse(
            text: 'Error: Invalid or missing model for Google provider');
      }

      final history = aiContext.history ?? [];
      final contents = <Map<String, dynamic>>[];
      // Add system prompt
      contents.add({
        'role': 'user',
        'parts': [
          {'text': aiContext.context.toString()},
        ],
      });
      contents.add({
        'role': 'model',
        'parts': [
          {
            'text':
                'I understand the system instructions and will follow them accordingly.'
          },
        ],
      });

      // Add conversation history
      for (int i = 0; i < history.length; i++) {
        final role = history[i]['role'] == 'assistant' ? 'model' : 'user';
        final parts = <Map<String, dynamic>>[];

        parts.add({'text': history[i]['content'] ?? ''});

        // Add image if present and it's the last message
        if (imageBase64 != null &&
            imageBase64.isNotEmpty &&
            i == history.length - 1) {
          final mimeType = imageMimeType ?? defaults['image_mime_type'];
          parts.add({
            'inline_data': {'mime_type': mimeType, 'data': imageBase64},
          });
        }

        contents.add({'role': role, 'parts': parts});
      }

      final bodyMap = {
        'contents': contents,
        'generationConfig': {
          'maxOutputTokens': config.configuration.maxOutputTokens,
          'temperature': additionalParams?['temperature'] ?? 0.7,
        },
      };

      final url = Uri.parse(
          getEndpointUrl('chat').replaceAll('{model}', selectedModel));
      final response = await http.Client()
          .post(url, headers: buildAuthHeaders(), body: jsonEncode(bodyMap));

      if (isSuccessfulResponse(response.statusCode)) {
        return _processGeminiResponse(jsonDecode(response.body));
      } else {
        final hasMoreKeys = handleApiError(
            response.statusCode, response.body, 'text_generation');
        if (!hasMoreKeys) {
          throw StateError(
              'All Google AI API keys have been exhausted - no retry needed');
        }
        throw Exception(
            '${response.statusCode} ${response.reasonPhrase ?? ''}: ${response.body}');
      }
    } on Exception catch (e) {
      AILogger.e('[GoogleProvider] Text request failed: $e');
      rethrow;
    }
  }

  ProviderResponse _processGeminiResponse(final Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final candidate = candidates.first as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;

        if (content != null) {
          final parts = content['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            // Check for image data first (Google uses camelCase 'inlineData')
            final imagePart = parts.firstWhere(
              (final part) => part is Map && part.containsKey('inlineData'),
              orElse: () => null,
            );

            if (imagePart != null) {
              final inlineData =
                  imagePart['inlineData'] as Map<String, dynamic>;
              final imageBase64 = inlineData['data'] as String?;

              if (imageBase64 != null && imageBase64.isNotEmpty) {
                // 🔥 CAPTURAR EL TEXTO REAL DE GEMINI también
                final textPart = parts.firstWhere(
                  (final part) => part is Map && part.containsKey('text'),
                  orElse: () => null,
                );

                final geminiText = textPart != null
                    ? textPart['text'] as String
                    : ''; // ✅ Si no hay texto, dejarlo vacío (más honesto)

                return ProviderResponse(
                  text: geminiText, // ✅ Usar el texto real de Gemini o vacío
                  imageBase64: imageBase64,
                );
              }
            }

            // Fallback to text content
            final textPart = parts.firstWhere(
              (final part) => part is Map && part.containsKey('text'),
              orElse: () => null,
            );

            if (textPart != null) {
              return ProviderResponse(text: textPart['text'] as String);
            }
          }
        }
      }

      return ProviderResponse(text: 'No response content found');
    } on Exception catch (e) {
      AILogger.e('[GoogleProvider] Error processing response: $e');
      return ProviderResponse(text: 'Error processing response: $e');
    }
  }

  Future<ProviderResponse> _sendImageGenerationRequest(
    final AIContext aiContext,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  ) async {
    final history = aiContext.history ?? [];
    final prompt = history.isNotEmpty ? history.last['content'] ?? '' : '';
    if (prompt.isEmpty) {
      return ProviderResponse(
          text: 'Error: No prompt provided for image generation.');
    }

    try {
      final selectedModel =
          model ?? getDefaultModel(AICapability.imageGeneration);
      if (selectedModel == null) {
        return ProviderResponse(
            text: 'Error: No model configured for image generation');
      }

      final bodyMap = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
      };

      final url = Uri.parse(
          getEndpointUrl('chat').replaceAll('{model}', selectedModel));
      final response = await http.Client()
          .post(url, headers: buildAuthHeaders(), body: jsonEncode(bodyMap));

      if (isSuccessfulResponse(response.statusCode)) {
        final responseBody = jsonDecode(response.body);
        return _processGeminiResponse(responseBody);
      } else {
        return ProviderResponse(
            text: 'Error generating image: ${response.statusCode}');
      }
    } on Exception catch (e) {
      AILogger.e('[GoogleProvider] Image generation failed: $e');
      return ProviderResponse(text: 'Error generating image: $e');
    }
  }

  /// Native Gemini TTS using generateContent
  Future<ProviderResponse> _sendTTSRequest(
    final AIContext aiContext,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  ) async {
    final history = aiContext.history ?? [];
    final text = history.isNotEmpty ? history.last['content'] ?? '' : '';
    if (text.isEmpty) {
      return ProviderResponse(text: 'Error: No text provided for TTS.');
    }

    try {
      final selectedModel =
          model ?? getDefaultModel(AICapability.audioGeneration);
      final voice =
          additionalParams?['voice'] ?? config.voices['default'] ?? 'Puck';

      // Crear AiAudioParams desde additionalParams para usar los nuevos campos
      final audioParams = AiAudioParams.fromMap(additionalParams);

      // Construir prompt nativo de TTS con parámetros avanzados
      final ttsPrompt = _buildAdvancedTtsPrompt(text, voice, audioParams);

      final contents = [
        {
          'role': 'user',
          'parts': [
            {'text': ttsPrompt}
          ],
        }
      ];

      final generationConfig = <String, dynamic>{
        'response_modalities': ['AUDIO'], // Configurar para respuesta de audio
        'speech_config': {
          'voice_config': {
            'prebuilt_voice_config': {
              'voice_name': voice,
            }
          }
        }
      };

      // Añadir temperature si está especificada
      if (audioParams.temperature != null) {
        generationConfig['temperature'] = audioParams.temperature;
      }

      final bodyMap = {
        'contents': contents,
        'generationConfig': generationConfig,
      };

      // Validation: ensure we have a model
      if (selectedModel == null || selectedModel.isEmpty) {
        throw StateError(
            'No TTS model available in Google provider configuration');
      }

      final url = Uri.parse(
          getEndpointUrl('tts_generate').replaceAll('{model}', selectedModel));
      final response = await http.Client()
          .post(url, headers: buildAuthHeaders(), body: jsonEncode(bodyMap));

      if (isSuccessfulResponse(response.statusCode)) {
        final responseBody = jsonDecode(response.body);

        // Extraer audio de la respuesta de Gemini
        String? audioBase64;
        if (responseBody['candidates'] != null &&
            responseBody['candidates'].isNotEmpty) {
          final candidate = responseBody['candidates'][0];
          if (candidate['content'] != null &&
              candidate['content']['parts'] != null &&
              candidate['content']['parts'].isNotEmpty) {
            final part = candidate['content']['parts'][0];
            if (part['inlineData'] != null &&
                part['inlineData']['data'] != null) {
              audioBase64 = part['inlineData']['data'];
              AILogger.d(
                  '[GoogleProvider] Extracted audio base64 data (${audioBase64?.length ?? 0} chars)');
              // Debug: verify base64 starts correctly
              if (audioBase64 != null && audioBase64.isNotEmpty) {
                final first50 = audioBase64.length > 50
                    ? audioBase64.substring(0, 50)
                    : audioBase64;
                AILogger.d('[GoogleProvider] Base64 preview: $first50...');
              }
            }
          }
        }

        return ProviderResponse(
          text: 'Audio generated successfully with Gemini TTS',
          audioBase64: audioBase64 ?? '',
        );
      } else {
        AILogger.e(
            '[GoogleProvider] Audio generation failed with HTTP ${response.statusCode}: ${response.body}');
        throw HttpException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Audio generation failed'}');
      }
    } on Exception catch (e) {
      AILogger.e('[GoogleProvider] TTS request failed: $e');
      return ProviderResponse(text: 'Error connecting to Gemini TTS: $e');
    }
  }

  /// Construye un prompt TTS avanzado usando los nuevos parámetros de audio
  String _buildAdvancedTtsPrompt(
    final String text,
    final String voice,
    final AiAudioParams audioParams,
  ) {
    final promptBuilder = StringBuffer();

    promptBuilder.write('''
Please generate speech audio for the following text using voice "$voice":
"$text"

Requirements:
- Use natural intonation and pacing
- Clear pronunciation''');

    // Añadir idioma si está especificado
    if (audioParams.language != null) {
      promptBuilder.write('\n- Speak in ${audioParams.language} language');
    }

    // Añadir acento personalizado si está especificado
    if (audioParams.accent != null) {
      promptBuilder
          .write('\n- Use accent/pronunciation style: ${audioParams.accent}');
    }

    // Añadir emoción personalizada si está especificada
    if (audioParams.emotion != null) {
      promptBuilder.write('\n- Emotional expression: ${audioParams.emotion}');
    }

    // Añadir velocidad si no es la por defecto
    if (audioParams.speed != 1.0) {
      final speedDescription = audioParams.speed > 1.0
          ? 'faster than normal (${audioParams.speed}x speed)'
          : 'slower than normal (${audioParams.speed}x speed)';
      promptBuilder.write('\n- Speaking pace: $speedDescription');
    }

    // Añadir formato de audio (Google siempre genera PCM internamente)
    promptBuilder
        .write('\n- Audio format preference: ${audioParams.audioFormat}');

    return promptBuilder.toString();
  }

  /// Native Gemini STT using generateContent
  Future<ProviderResponse> _sendTranscriptionRequest(
    final String audioBase64,
    final AIContext aiContext,
    final String? model,
  ) async {
    if (audioBase64.isEmpty) {
      return ProviderResponse(
          text: 'Error: No audio data provided for transcription.');
    }

    try {
      final selectedModel =
          model ?? getDefaultModel(AICapability.audioTranscription);

      // Construir prompt desde Context
      final promptText = _buildPromptFromContext(aiContext);
      final transcriptionPrompt = promptText.isNotEmpty
          ? promptText
          : 'Please transcribe this audio file to text. Provide only the transcribed text without additional comments.';

      // Native Gemini STT with multimodal input
      final contents = [
        {
          'role': 'user',
          'parts': [
            {'text': transcriptionPrompt},
            {
              'inline_data': {
                'mime_type': 'audio/wav',
                'data': audioBase64,
              }
            }
          ],
        }
      ];

      final bodyMap = {
        'contents': contents,
        'generationConfig': {
          'maxOutputTokens': 8192,
          'temperature': 0.1, // Very low temperature for accurate transcription
        },
      };

      // Validation: ensure we have a model
      if (selectedModel == null || selectedModel.isEmpty) {
        throw StateError(
            'No STT model available in Google provider configuration');
      }

      final url = Uri.parse(getEndpointUrl('stt_transcribe')
          .replaceAll('{model}', selectedModel));
      final response = await http.Client()
          .post(url, headers: buildAuthHeaders(), body: jsonEncode(bodyMap));

      if (isSuccessfulResponse(response.statusCode)) {
        return _processGeminiResponse(jsonDecode(response.body));
      } else {
        return ProviderResponse(
            text: 'Error transcribing audio: ${response.statusCode}');
      }
    } on Exception catch (e) {
      AILogger.e('[GoogleProvider] STT request failed: $e');
      return ProviderResponse(text: 'Error connecting to Gemini STT: $e');
    }
  }

  /// Handle realtime conversation setup
  Future<ProviderResponse> _handleRealtimeRequest(
    final AIContext aiContext,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  ) async {
    if (!supportsCapability(AICapability.realtimeConversation)) {
      return ProviderResponse(
          text:
              'Realtime conversation not supported by this Google provider configuration');
    }

    final realtimeModel =
        model ?? getDefaultModel(AICapability.realtimeConversation);
    return ProviderResponse(
      text:
          'Realtime conversation session configured successfully. Provider: google, Model: $realtimeModel, History: ${aiContext.history?.length ?? 0} messages',
    );
  }

  Future<ProviderResponse> generateAudio({
    required final String text,
    final String? voice,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  }) async {
    // Create temporary AIContext for TTS
    final aiContext = AIContext(
      context: '',
      dateTime: DateTime.now(),
      instructions: {},
      history: [
        {'role': 'user', 'content': text}
      ],
    );

    return _sendTTSRequest(
      aiContext,
      model,
      {...?additionalParams, 'voice': voice},
    );
  }

  Future<ProviderResponse> transcribeAudio({
    required final String audioBase64,
    final String? model,
    final AIContext? aiContext,
  }) async {
    final effectiveContext = aiContext ??
        AIContext(
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
    return realtimeModels.contains(model) || model.contains('gemini');
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

  // Native Gemini voices - All 30 official voices from Gemini API documentation
  static final List<VoiceInfo> _availableVoices = [
    // Row 1: Brilliant, Optimistic, Informative
    const VoiceInfo(
        id: 'Zephyr',
        name: 'Zephyr',
        language: 'multi',
        gender: VoiceGender.neutral,
        description: 'Brilliant voice'),
    const VoiceInfo(
        id: 'Puck',
        name: 'Puck',
        language: 'multi',
        gender: VoiceGender.neutral,
        description: 'Optimistic voice'),
    const VoiceInfo(
        id: 'Charon',
        name: 'Charon',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Informative voice'),

    // Row 2: Firm, Exciting, Youthful
    const VoiceInfo(
        id: 'Kore',
        name: 'Kore',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Firm voice'),
    const VoiceInfo(
        id: 'Fenrir',
        name: 'Fenrir',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Exciting voice'),
    const VoiceInfo(
        id: 'Leda',
        name: 'Leda',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Youthful voice'),

    // Row 3: Firm, Breezy, Quiet
    const VoiceInfo(
        id: 'Orus',
        name: 'Orus',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Firm voice'),
    const VoiceInfo(
        id: 'Aoede',
        name: 'Aoede',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Breezy voice'),
    const VoiceInfo(
        id: 'Callirrhoe',
        name: 'Callirrhoe',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Quiet voice'),

    // Row 4: Bright, Breathy, Clear
    const VoiceInfo(
        id: 'Autonoe',
        name: 'Autonoe',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Bright voice'),
    const VoiceInfo(
        id: 'Enceladus',
        name: 'Enceladus',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Breathy voice'),
    const VoiceInfo(
        id: 'Iapetus',
        name: 'Iapetus',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Clear voice'),

    // Row 5: Relaxed, Soft, Soft
    const VoiceInfo(
        id: 'Umbriel',
        name: 'Umbriel',
        language: 'multi',
        gender: VoiceGender.neutral,
        description: 'Relaxed voice'),
    const VoiceInfo(
        id: 'Algieba',
        name: 'Algieba',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Soft voice'),
    const VoiceInfo(
        id: 'Despina',
        name: 'Despina',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Soft voice'),

    // Row 6: Clear, Sandy, Informative
    const VoiceInfo(
        id: 'Erinome',
        name: 'Erinome',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Clear voice'),
    const VoiceInfo(
        id: 'Algenib',
        name: 'Algenib',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Sandy voice'),
    const VoiceInfo(
        id: 'Rasalgethi',
        name: 'Rasalgethi',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Informative voice'),

    // Row 7: Optimistic, Soft, Firm
    const VoiceInfo(
        id: 'Laomedeia',
        name: 'Laomedeia',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Optimistic voice'),
    const VoiceInfo(
        id: 'Achernar',
        name: 'Achernar',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Soft voice'),
    const VoiceInfo(
        id: 'Alnilam',
        name: 'Alnilam',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Firm voice'),

    // Row 8: Even, Mature, Forward
    const VoiceInfo(
        id: 'Schedar',
        name: 'Schedar',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Even voice'),
    const VoiceInfo(
        id: 'Gacrux',
        name: 'Gacrux',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Mature voice'),
    const VoiceInfo(
        id: 'Pulcherrima',
        name: 'Pulcherrima',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Forward voice'),

    // Row 9: Friendly, Casual, Soft
    const VoiceInfo(
        id: 'Achird',
        name: 'Achird',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Friendly voice'),
    const VoiceInfo(
        id: 'Zubenelgenubi',
        name: 'Zubenelgenubi',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Casual voice'),
    const VoiceInfo(
        id: 'Vindemiatrix',
        name: 'Vindemiatrix',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Soft voice'),

    // Row 10: Animated, Knowledgeable, Warm
    const VoiceInfo(
        id: 'Sadachbia',
        name: 'Sadachbia',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Animated voice'),
    const VoiceInfo(
        id: 'Sadaltager',
        name: 'Sadaltager',
        language: 'multi',
        gender: VoiceGender.male,
        description: 'Knowledgeable voice'),
    const VoiceInfo(
        id: 'Sulafat',
        name: 'Sulafat',
        language: 'multi',
        gender: VoiceGender.female,
        description: 'Warm voice'),
  ];

  Future<List<VoiceInfo>> getAvailableVoices() async => _availableVoices;

  VoiceGender getVoiceGender(final String voiceName) {
    return _availableVoices
        .firstWhere(
          (final v) => v.name.toLowerCase() == voiceName.toLowerCase(),
          orElse: () => const VoiceInfo(
              id: 'default',
              name: 'default',
              language: 'multi',
              gender: VoiceGender.neutral),
        )
        .gender;
  }

  List<String> getVoiceNames() =>
      _availableVoices.map((final v) => v.name).toList();

  bool isValidVoice(final String voiceName) => _availableVoices
      .any((final v) => v.name.toLowerCase() == voiceName.toLowerCase());

  /// Construye prompt para transcripción desde Context
  String _buildPromptFromContext(final AIContext aiContext) {
    final parts = <String>[];

    // Agregar contexto si hay
    if (aiContext.context.isNotEmpty) {
      final contextStr = aiContext.context.toString();
      if (contextStr.isNotEmpty && contextStr != '{}') {
        parts.add(contextStr);
      }
    }

    // Agregar instrucciones si hay
    if (aiContext.instructions.isNotEmpty) {
      final instructionsStr = aiContext.instructions.toString();
      if (instructionsStr.isNotEmpty && instructionsStr != '{}') {
        parts.add(instructionsStr);
      }
    }

    return parts.join(' ');
  }
}
