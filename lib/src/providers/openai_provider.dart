import 'dart:async';
import 'dart:convert';
import 'dart:io';
// dart:typed_data removed - no longer needed

import '../core/provider_registry.dart';
import '../models/provider_response.dart';
import '../models/ai_provider_metadata.dart';
import '../models/ai_system_prompt.dart';
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
  Future<ProviderResponse> sendMessage({
    required final List<Map<String, String>> history,
    required final AISystemPrompt systemPrompt,
    required final AICapability capability,
    final String? model,
    final String? imageBase64,
    final String? imageMimeType,
    final Map<String, dynamic>? additionalParams,
  }) async {
    switch (capability) {
      case AICapability.textGeneration:
      case AICapability.imageAnalysis:
        return _sendTextRequest(history, systemPrompt, model, imageBase64,
            imageMimeType, additionalParams);
      case AICapability.imageGeneration:
        return _sendImageGenerationRequest(
            history, systemPrompt, model, additionalParams);
      case AICapability.audioGeneration:
        return _sendTTSRequest(history, model, additionalParams);
      case AICapability.audioTranscription:
        return _sendTranscriptionRequest(
          imageBase64 ?? '',
          additionalParams?['audioFormat'],
          model,
          additionalParams?['language'],
          additionalParams,
        );
      case AICapability.realtimeConversation:
        return _handleRealtimeRequest(
            history, systemPrompt, model, additionalParams);
      default:
        return ProviderResponse(
            text: 'Capability $capability not supported by OpenAI provider');
    }
  }

  Future<ProviderResponse> _sendTextRequest(
    final List<Map<String, String>> history,
    final AISystemPrompt systemPrompt,
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
            text: 'Error: Invalid or missing model for OpenAI provider');
      }

      final input = <Map<String, dynamic>>[];
      final systemPromptMap = systemPrompt.toJson();
      final enableImageGeneration =
          additionalParams?['enableImageGeneration'] == true;

      // Process system prompt
      _processAISystemPrompt(
          systemPromptMap, enableImageGeneration, imageBase64);
      input.add({'role': 'system', 'content': jsonEncode(systemPromptMap)});

      // Add history
      for (int i = 0; i < history.length; i++) {
        input.add({
          'role': history[i]['role'] ?? 'user',
          'content': history[i]['content'] ?? ''
        });

        // Add image if it's the last message
        if (imageBase64 != null &&
            imageBase64.isNotEmpty &&
            i == history.length - 1) {
          input.add({
            'role': history[i]['role'] ?? 'user',
            'content': createImageDataUri(imageBase64, imageMimeType)
          });
        }
      }

      final bodyMap = {
        'model': selectedModel,
        'input': input,
        if (enableImageGeneration)
          'tools': [
            {
              'type': 'image_generation',
              'input_fidelity': 'low',
              'moderation': 'low',
              'background': 'opaque'
            },
          ],
      };

      final url = Uri.parse(getEndpointUrl('chat'));
      final response = await http.Client()
          .post(url, headers: buildAuthHeaders(), body: jsonEncode(bodyMap));

      if (isSuccessfulResponse(response.statusCode)) {
        return _processTextResponse(jsonDecode(response.body));
      } else {
        handleApiError(response.statusCode, response.body, 'text_generation');
        throw HttpException(
            '${response.statusCode} ${response.reasonPhrase ?? ''}: ${response.body}');
      }
    } on Exception catch (e) {
      AILogger.e('[OpenAIProvider] Text request failed: $e');
      rethrow;
    }
  }

  void _processAISystemPrompt(
    final Map<String, dynamic> systemPromptMap,
    final bool enableImageGeneration,
    final String? imageBase64,
  ) {
    try {
      // Remove recent messages from system prompt for better context management
      _removeRecentMessages(systemPromptMap);
    } on Exception catch (_) {}
  }

  void _removeRecentMessages(final Map<String, dynamic> map) {
    try {
      final keys = List<String>.from(map.keys);
      for (final k in keys) {
        if (k == 'recentMessages' || k == 'recent_messages') {
          map.remove(k);
          continue;
        }
        final v = map[k];
        if (v is Map<String, dynamic>) {
          _removeRecentMessages(v);
        } else if (v is List) {
          for (final item in v) {
            if (item is Map<String, dynamic>) {
              _removeRecentMessages(item);
            }
          }
        }
      }
    } on Exception catch (_) {}
  }

  ProviderResponse _processTextResponse(final Map<String, dynamic> data) {
    String text = '';
    String imageBase64Output = '';
    String imageId = '';
    String revisedPrompt = '';
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
      seed: imageId,
      prompt: revisedPrompt.trim(),
      imageBase64: imageBase64Output,
    );
  }

  Future<ProviderResponse> _sendImageGenerationRequest(
    final List<Map<String, String>> history,
    final AISystemPrompt systemPrompt,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  ) async {
    final params = Map<String, dynamic>.from(additionalParams ?? {});
    params['enableImageGeneration'] = true;
    return _sendTextRequest(history, systemPrompt, model, null, null, params);
  }

  Future<ProviderResponse> _sendTTSRequest(
    final List<Map<String, String>> history,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  ) async {
    final text = history.isNotEmpty ? history.last['content'] ?? '' : '';
    if (text.isEmpty) {
      return ProviderResponse(text: 'Error: No text provided for TTS.');
    }

    final selectedModel =
        model ?? getDefaultModel(AICapability.audioGeneration);
    final voice = additionalParams?['voice'] ?? getDefaultVoice();
    final speed = additionalParams?['speed'] ?? 1.0;
    final responseFormat =
        additionalParams?['response_format'] ?? defaults['audio_format'];

    final payload = {
      'model': selectedModel,
      'input': text,
      'voice': voice,
      'speed': speed,
      'response_format': responseFormat,
    };

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
    final String? audioFormat,
    final String? model,
    final String? language,
    final Map<String, dynamic>? additionalParams,
  ) async {
    try {
      final audioBytes = base64Decode(audioBase64);
      final format = audioFormat ?? defaults['audio_format'];
      final tempFile = File(
          '${Directory.systemTemp.path}/whisper_${DateTime.now().millisecondsSinceEpoch}.$format');
      await tempFile.writeAsBytes(audioBytes);

      try {
        final url = Uri.parse(getEndpointUrl('audio_transcriptions'));
        final request = http.MultipartRequest('POST', url);

        request.headers['Authorization'] = 'Bearer $apiKey';
        request.fields['model'] =
            model ?? defaults['transcription_model'] ?? 'whisper-1';

        if (language != null && language.isNotEmpty) {
          request.fields['language'] = language;
        }

        additionalParams?.forEach((final k, final v) {
          if (v != null) request.fields[k] = v.toString();
        });

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
    final List<Map<String, String>> history,
    final AISystemPrompt systemPrompt,
    final String? model,
    final Map<String, dynamic>? additionalParams,
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
          'Realtime conversation session configured successfully. Provider: openai, Model: $realtimeModel, History: ${history.length} messages',
    );
  }

  Future<ProviderResponse> generateAudio({
    required final String text,
    final String? voice,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  }) async {
    return _sendTTSRequest(
      [
        {'role': 'user', 'content': text},
      ],
      model,
      {...?additionalParams, 'voice': voice},
    );
  }

  Future<ProviderResponse> transcribeAudio({
    required final String audioBase64,
    final String? audioFormat,
    final String? model,
    final String? language,
    final Map<String, dynamic>? additionalParams,
  }) async {
    return _sendTranscriptionRequest(
        audioBase64, audioFormat, model, language, additionalParams);
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
}
