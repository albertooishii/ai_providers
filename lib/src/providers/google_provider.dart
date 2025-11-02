import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/provider_registry.dart';
import '../models/additional_params.dart';
import '../models/provider_response.dart';
import '../models/ai_provider_metadata.dart';
import '../models/ai_system_prompt.dart';
import '../models/ai_audio_params.dart';

import '../utils/json_utils.dart' as json_utils;
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
        return ProviderResponse(
            text: 'Error: Invalid or missing model for Google provider');
      }

      // Use processHistory to extract history and clean systemPrompt
      final (:history, :systemPromptWithoutHistory) =
          processHistory(systemPrompt);
      final contents = <Map<String, dynamic>>[];

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

      final bodyMap = <String, dynamic>{
        'contents': contents,
        'generationConfig': {
          'maxOutputTokens': config.configuration.maxOutputTokens,
          'temperature': 0.7,
        },
      };

      // ✨ Use systemPrompt WITHOUT history (agnostic approach)
      final systemContent = systemPromptWithoutHistory.toString();
      if (systemContent.isNotEmpty && systemContent != '{}') {
        bodyMap['systemInstruction'] = {
          'parts': [
            {'text': systemContent}
          ]
        };
        AILogger.d(
            '[GoogleProvider] 🎯 Using native systemInstruction with complete systemPrompt');
      }

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

        // 🎯 NUEVO: Verificar finishReason para detectar rechazos de políticas
        final finishReason = candidate['finishReason'] as String?;
        if (finishReason != null) {
          switch (finishReason) {
            case 'IMAGE_OTHER':
              AILogger.w(
                  '[GoogleProvider] ⚠️ Google rechazó la imagen por políticas de contenido (IMAGE_OTHER)');
              return ProviderResponse(
                text:
                    'Error: Google rechazó generar la imagen por políticas de contenido. Intenta con una descripción menos específica.',
              );
            case 'SAFETY':
              AILogger.w(
                  '[GoogleProvider] ⚠️ Google rechazó la imagen por seguridad (SAFETY)');
              return ProviderResponse(
                text:
                    'Error: Google rechazó generar la imagen por motivos de seguridad.',
              );
            case 'RECITATION':
              AILogger.w(
                  '[GoogleProvider] ⚠️ Google rechazó la imagen por recitación (RECITATION)');
              return ProviderResponse(
                text:
                    'Error: Google rechazó generar la imagen por políticas de recitación.',
              );
            case 'STOP':
              // STOP es normal, continuar procesando
              break;
            default:
              AILogger.w(
                  '[GoogleProvider] ⚠️ Google finalizó con razón desconocida: $finishReason');
              break;
          }
        }

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
                // 🔥 CAPTURAR EL TEXTO REAL DE GEMINI como "revised prompt"
                final textPart = parts.firstWhere(
                  (final part) => part is Map && part.containsKey('text'),
                  orElse: () => null,
                );

                String geminiText = '';
                String revisedPrompt = '';

                if (textPart != null) {
                  final fullText = textPart['text'] as String? ?? '';

                  AILogger.d(
                      '[GoogleProvider] 🖼️ Processing image response text (${fullText.length} chars)');

                  // Extraer JSON estructurado de la respuesta
                  final jsonExtracted = json_utils.extractJsonBlock(fullText);

                  if (!jsonExtracted.containsKey('raw')) {
                    // JSON válido extraído - usar solo el campo description
                    final description = jsonExtracted['description'];
                    final response = jsonExtracted['response'];

                    // Asegurarse de que description no contenga delimitadores markdown
                    if (description != null) {
                      revisedPrompt = description.toString().trim();
                      AILogger.d(
                          '[GoogleProvider] ✅ Extracted description (${revisedPrompt.length} chars)');
                    } else {
                      AILogger.w(
                          '[GoogleProvider] ⚠️ No description field in extracted JSON');
                      revisedPrompt = '';
                    }

                    if (response != null) {
                      geminiText = response.toString().trim();
                    } else {
                      geminiText = 'Image generated successfully';
                    }
                  } else {
                    // Fallback: si no hay JSON válido, usar texto completo como descripción
                    final rawText =
                        jsonExtracted['raw']?.toString() ?? fullText;
                    revisedPrompt = rawText;
                    geminiText = 'Image generated successfully';
                    AILogger.w(
                        '[GoogleProvider] ⚠️ Could not extract JSON, using raw text as prompt');
                  }
                } else {
                  AILogger.w(
                      '[GoogleProvider] ⚠️ No text part found in image response');
                }

                return ProviderResponse(
                  text: geminiText.isNotEmpty
                      ? geminiText
                      : 'Image generated successfully',
                  prompt: revisedPrompt, // ✅ Solo la descripción limpia
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

        // 🎯 NUEVO: Si tenemos finishReason problemático y sin contenido, reportar específicamente
        if (finishReason == 'IMAGE_OTHER' ||
            finishReason == 'SAFETY' ||
            finishReason == 'RECITATION') {
          return ProviderResponse(
            text:
                'Error: Google no pudo generar la imagen (finishReason: $finishReason)',
          );
        }
      }

      return ProviderResponse(text: 'No response content found');
    } on Exception catch (e) {
      AILogger.e('[GoogleProvider] Error processing response: $e');
      return ProviderResponse(text: 'Error processing response: $e');
    }
  }

  Future<ProviderResponse> _sendImageGenerationRequest(
    final AISystemPrompt systemPrompt,
    final String? model,
    final AdditionalParams? additionalParams,
  ) async {
    final history = systemPrompt.history ?? [];
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

      final contents = <Map<String, dynamic>>[];

      // ✨ 1. Preparar el prompt del usuario (con imagen base si está disponible)
      // ✅ Obtener imagen base para edición si está en additionalParams
      final sourceImageBase64 =
          additionalParams?.imageParams?.sourceImageBase64;

      // Modificar el prompt para que Gemini también genere una descripción detallada
      final isEditing =
          sourceImageBase64 != null && sourceImageBase64.isNotEmpty;

      final enhancedPrompt = isEditing
          ? '''$prompt

After editing the image, provide your response as a JSON object with the following structure:
{
  "description": "Detailed description of the changes made and final result including what was modified, visual elements, composition, colors, lighting, style and key features",
  "response": "Brief confirmation message about the edit"
}'''
          : '''$prompt

After generating the image, provide your response as a JSON object with the following structure:
{
  "description": "Detailed description of what you created including visual elements, composition, colors, lighting, style, key features and artistic choices",
  "response": "Brief confirmation message about the generation"
}''';

      final userParts = <Map<String, dynamic>>[
        {'text': enhancedPrompt}
      ];
      if (sourceImageBase64 != null && sourceImageBase64.isNotEmpty) {
        final imageData = sourceImageBase64.startsWith('data:')
            ? sourceImageBase64.split(',').last
            : sourceImageBase64;

        userParts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': imageData,
          },
        });

        AILogger.d(
            '[GoogleProvider] 🖼️ Image editing mode: usando imagen base para edición');
      }

      contents.add({
        'role': 'user',
        'parts': userParts,
      });

      // ✨ 2. Build systemInstruction from AISystemPrompt (mismo enfoque que _sendTextRequest)
      final contextJson = systemPrompt.toJson();
      final systemParts = <String>[];

      // Include context
      final contextData = contextJson['context'];
      if (contextData != null) {
        final contextStr =
            contextData is String ? contextData : jsonEncode(contextData);
        if (contextStr.isNotEmpty &&
            contextStr != '{}' &&
            contextStr != 'null') {
          systemParts.add('Context:\n$contextStr');
        }
      }

      // Include instructions from systemPrompt.instructions
      if (systemPrompt.instructions.isNotEmpty) {
        final instructionsStr = jsonEncode(systemPrompt.instructions);
        if (instructionsStr.isNotEmpty &&
            instructionsStr != '{}' &&
            instructionsStr != 'null') {
          // If instructions contain a 'raw' key, use that directly
          if (systemPrompt.instructions.containsKey('raw')) {
            systemParts
                .add('Instructions:\n${systemPrompt.instructions['raw']}');
          } else {
            systemParts.add('Instructions:\n$instructionsStr');
          }
        }
      }

      final bodyMap = <String, dynamic>{
        'contents': contents,
        'generationConfig': {
          'maxOutputTokens': config.configuration.maxOutputTokens,
          'temperature': 0.7,
        },
      };

      // ✨ Add systemInstruction at top level if we have system content
      if (systemParts.isNotEmpty) {
        bodyMap['systemInstruction'] = {
          'parts': [
            {'text': systemParts.join('\n\n')}
          ]
        };
        AILogger.d(
            '[GoogleProvider] 🎯 Image generation using native systemInstruction with ${systemParts.length} parts');
      }

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
    final AISystemPrompt systemPrompt,
    final String? model,
    final AdditionalParams? additionalParams,
    final String? voice,
  ) async {
    final history = systemPrompt.history ?? [];
    final text = history.isNotEmpty ? history.last['content'] ?? '' : '';
    if (text.isEmpty) {
      return ProviderResponse(text: 'Error: No text provided for TTS.');
    }

    try {
      final selectedModel =
          model ?? getDefaultModel(AICapability.audioGeneration);
      final audioParams =
          additionalParams?.audioParams ?? const AiAudioParams();

      // 🎭 Multi-voice mode: use Gemini's multi-speaker support with freeform text
      if (audioParams.multiVoiceEnabled) {
        return _sendMultiVoiceTTSRequest(text, selectedModel, audioParams);
      }

      // Single-voice mode (existing logic)
      final selectedVoice = voice ?? getDefaultVoice();
      final ttsPrompt =
          _buildAdvancedTtsPrompt(text, selectedVoice, audioParams);

      final contents = [
        {
          'role': 'user',
          'parts': [
            {'text': ttsPrompt}
          ],
        }
      ];

      final generationConfig = <String, dynamic>{
        'response_modalities': ['AUDIO'],
        'speech_config': {
          'voice_config': {
            'prebuilt_voice_config': {
              'voice_name': selectedVoice,
            }
          }
        }
      };

      if (audioParams.temperature != null) {
        generationConfig['temperature'] = audioParams.temperature;
      }

      final bodyMap = {
        'contents': contents,
        'generationConfig': generationConfig,
      };

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

        AILogger.d(
            '[GoogleProvider] 📊 TTS Response (full body): $responseBody');

        String? audioBase64;
        if (responseBody['candidates'] != null &&
            responseBody['candidates'].isNotEmpty) {
          final candidate = responseBody['candidates'][0];
          AILogger.d('[GoogleProvider] 🎵 Candidate structure: $candidate');

          if (candidate['content'] != null &&
              candidate['content']['parts'] != null &&
              candidate['content']['parts'].isNotEmpty) {
            final part = candidate['content']['parts'][0];
            AILogger.d('[GoogleProvider] 📦 Part structure: $part');

            if (part['inlineData'] != null &&
                part['inlineData']['data'] != null) {
              audioBase64 = part['inlineData']['data'];
              AILogger.d(
                  '[GoogleProvider] ✅ Extracted audio base64 data (${audioBase64?.length ?? 0} chars)');
              if (audioBase64 != null && audioBase64.isNotEmpty) {
                final first50 = audioBase64.length > 50
                    ? audioBase64.substring(0, 50)
                    : audioBase64;
                AILogger.d('[GoogleProvider] Base64 preview: $first50...');
              }
            } else {
              AILogger.w(
                  '[GoogleProvider] ⚠️ No inlineData found in part: ${part.keys.toList()}');
            }
          } else {
            AILogger.w(
                '[GoogleProvider] ⚠️ No content/parts in candidate: ${candidate.keys.toList()}');
          }
        } else {
          AILogger.w(
              '[GoogleProvider] ⚠️ No candidates in response: ${responseBody.keys.toList()}');
        }

        if (audioBase64 == null || audioBase64.isEmpty) {
          AILogger.e(
              '[GoogleProvider] ❌ No audio extracted from response. Response keys: ${responseBody.keys.toList()}');

          if (responseBody['candidates'] != null &&
              responseBody['candidates'].isNotEmpty) {
            final finishReason = responseBody['candidates'][0]['finishReason'];
            AILogger.e('[GoogleProvider] Finish reason: $finishReason');

            if (finishReason == 'OTHER') {
              AILogger.e(
                  '[GoogleProvider] Gemini returned finishReason=OTHER (likely safety filter or unsupported request)');
              throw StateError(
                  'Gemini TTS returned OTHER finish reason - possibly blocked by safety filter');
            }
          }

          throw StateError(
              'Gemini TTS returned no audio data. Full response: ${responseBody.toString()}');
        }

        return ProviderResponse(
          text: 'Audio generated successfully with Gemini TTS',
          audioBase64: audioBase64,
        );
      } else {
        AILogger.e(
            '[GoogleProvider] ❌ Audio generation failed with HTTP ${response.statusCode}: ${response.body}');
        throw HttpException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Audio generation failed'}');
      }
    } on Exception catch (e) {
      AILogger.e('[GoogleProvider] TTS request failed: $e');
      return ProviderResponse(text: 'Error connecting to Gemini TTS: $e');
    }
  }

  /// Multi-voice TTS using speaker names in text
  /// Text should be formatted as: "Speaker1: text\nSpeaker2: text"
  /// Speakers must match names in speakerVoiceConfigs
  Future<ProviderResponse> _sendMultiVoiceTTSRequest(
    final String text,
    final String? selectedModel,
    final AiAudioParams audioParams,
  ) async {
    try {
      AILogger.d('[GoogleProvider] 🎭 Multi-voice TTS');
      AILogger.d('[GoogleProvider] 🎭 Input text: $text');

      // Get configured voices from YAML
      final voices = config.voices;
      if (voices.isEmpty) {
        throw StateError('No voices configured in YAML for multi-voice TTS');
      }

      // Build speaker voice configs
      // Gemini multi-voice requires exactly 2 speakers maximum
      final maxVoices = voices.take(2).toList();
      if (maxVoices.length < 2) {
        throw StateError(
            'Multi-voice TTS requires at least 2 voices configured in YAML');
      }

      final speakerVoiceConfigs = <Map<String, dynamic>>[];
      for (int i = 0; i < maxVoices.length; i++) {
        speakerVoiceConfigs.add({
          'speaker': 'Speaker${i + 1}',
          'voiceConfig': {
            'prebuiltVoiceConfig': {
              'voiceName': maxVoices[i],
            }
          }
        });
      }

      AILogger.d('[GoogleProvider] 🎭 Speaker configs: $speakerVoiceConfigs');

      // Build enhanced prompt with language and other parameters
      final enhancedText = _buildMultiVoiceTtsPrompt(text, audioParams);

      final contents = [
        {
          'role': 'user',
          'parts': [
            {
              'text': enhancedText
            } // Text should have "Speaker1: ...\nSpeaker2: ..." format with language instructions
          ],
        }
      ];

      // Multi-voice config using correct field names
      final generationConfig = <String, dynamic>{
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'multiSpeakerVoiceConfig': {
            'speakerVoiceConfigs': speakerVoiceConfigs,
          }
        }
      };

      if (audioParams.temperature != null) {
        generationConfig['temperature'] = audioParams.temperature;
      }

      final bodyMap = {
        'contents': contents,
        'generationConfig': generationConfig,
      };

      if (selectedModel == null || selectedModel.isEmpty) {
        throw StateError('No TTS model available');
      }

      final url = Uri.parse(
          getEndpointUrl('tts_generate').replaceAll('{model}', selectedModel));
      final response = await http.Client()
          .post(url, headers: buildAuthHeaders(), body: jsonEncode(bodyMap));

      if (isSuccessfulResponse(response.statusCode)) {
        final responseBody = jsonDecode(response.body);

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
            }
          }
        }

        if (audioBase64 == null || audioBase64.isEmpty) {
          throw StateError('Multi-voice TTS returned no audio data');
        }

        return ProviderResponse(
          text: 'Multi-voice audio generated successfully',
          audioBase64: audioBase64,
        );
      } else {
        AILogger.e(
            '[GoogleProvider] ❌ Multi-voice TTS failed (HTTP ${response.statusCode})');
        AILogger.e('[GoogleProvider] ❌ Response body: ${response.body}');
        throw HttpException(
            'Multi-voice TTS failed: HTTP ${response.statusCode}');
      }
    } on Exception catch (e) {
      AILogger.e('[GoogleProvider] Multi-voice TTS error: $e');
      rethrow;
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

  /// Construye un prompt TTS avanzado para multi-voice incluyendo idioma y parámetros
  String _buildMultiVoiceTtsPrompt(
    final String text,
    final AiAudioParams audioParams,
  ) {
    final promptBuilder = StringBuffer();

    promptBuilder.write(
        '''Please generate multi-speaker speech audio for the following text:
"$text"

Requirements:
- Use natural intonation and pacing for each speaker
- Clear pronunciation for all speakers''');

    // Añadir idioma si está especificado
    if (audioParams.language != null) {
      promptBuilder.write(
          '\n- All speakers should speak in ${audioParams.language} language');
    }

    // Añadir acento personalizado si está especificado
    if (audioParams.accent != null) {
      promptBuilder
          .write('\n- Use accent/pronunciation style: ${audioParams.accent}');
    }

    // Añadir emoción personalizada si está especificada
    if (audioParams.emotion != null) {
      promptBuilder.write(
          '\n- Emotional expression for all speakers: ${audioParams.emotion}');
    }

    // Añadir velocidad si no es la por defecto
    if (audioParams.speed != 1.0) {
      final speedDescription = audioParams.speed > 1.0
          ? 'faster than normal (${audioParams.speed}x speed)'
          : 'slower than normal (${audioParams.speed}x speed)';
      promptBuilder
          .write('\n- Speaking pace for all speakers: $speedDescription');
    }

    // Añadir formato de audio (Google siempre genera PCM internamente)
    promptBuilder
        .write('\n- Audio format preference: ${audioParams.audioFormat}');

    return promptBuilder.toString();
  }

  /// Native Gemini STT using generateContent
  Future<ProviderResponse> _sendTranscriptionRequest(
    final String audioBase64,
    final AISystemPrompt systemPrompt,
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
      final promptText = _buildPromptFromContext(systemPrompt);
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
    final AISystemPrompt systemPrompt,
    final String? model,
    final AdditionalParams? additionalParams,
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
          'Realtime conversation session configured successfully. Provider: google, Model: $realtimeModel, History: ${systemPrompt.history?.length ?? 0} messages',
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
        gender: VoiceGender.female,
        description: 'Brilliant voice'),
    const VoiceInfo(
        id: 'Puck',
        name: 'Puck',
        language: 'multi',
        gender: VoiceGender.male,
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
        gender: VoiceGender.male,
        description: 'Relaxed voice'),
    const VoiceInfo(
        id: 'Algieba',
        name: 'Algieba',
        language: 'multi',
        gender: VoiceGender.male,
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
        gender: VoiceGender.female,
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
        gender: VoiceGender.male,
        description: 'Even voice'),
    const VoiceInfo(
        id: 'Gacrux',
        name: 'Gacrux',
        language: 'multi',
        gender: VoiceGender.female,
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
        gender: VoiceGender.male,
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
  String _buildPromptFromContext(final AISystemPrompt systemPrompt) {
    final parts = <String>[];
    final contextJson = systemPrompt.toJson();

    // Agregar contexto usando serialización correcta
    final contextData = contextJson['context'];
    if (contextData != null) {
      final contextStr =
          contextData is String ? contextData : jsonEncode(contextData);
      if (contextStr.isNotEmpty && contextStr != '{}') {
        parts.add(contextStr);
      }
    }

    // Agregar instrucciones si hay
    if (systemPrompt.instructions.isNotEmpty) {
      final instructionsStr = jsonEncode(systemPrompt.instructions);
      if (instructionsStr.isNotEmpty && instructionsStr != '{}') {
        parts.add(instructionsStr);
      }
    }

    return parts.join(' ');
  }
}
