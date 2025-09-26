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

/// Google Gemini provider - optimized and without hardcodes
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
      default:
        return ProviderResponse(
            text: 'Capability $capability not supported by Google provider');
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
            text: 'Error: Invalid or missing model for Google provider');
      }

      final contents = <Map<String, dynamic>>[];

      // Add system prompt
      contents.add({
        'role': 'user',
        'parts': [
          {'text': jsonEncode(systemPrompt.toJson())},
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

      final url = Uri.parse('${getEndpointUrl('chat')}:generateContent');
      final response = await http.Client()
          .post(url, headers: buildAuthHeaders(), body: jsonEncode(bodyMap));

      if (isSuccessfulResponse(response.statusCode)) {
        return _processGeminiResponse(jsonDecode(response.body));
      } else {
        handleApiError(response.statusCode, response.body, 'text_generation');
        throw HttpException(
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
    final List<Map<String, String>> history,
    final AISystemPrompt systemPrompt,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  ) async {
    return ProviderResponse(
        text:
            'Image generation not supported by Google provider. Use Imagen API separately.');
  }

  Future<ProviderResponse> generateAudio({
    required final String text,
    final String? voice,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  }) async {
    return ProviderResponse(
        text:
            'Audio generation not supported by Google provider in current configuration');
  }

  Future<ProviderResponse> transcribeAudio({
    required final String audioBase64,
    final String? audioFormat,
    final String? model,
    final String? language,
    final Map<String, dynamic>? additionalParams,
  }) async {
    return ProviderResponse(
        text:
            'Audio transcription not supported by Google provider in current configuration');
  }

  /// [REMOVED] createRealtimeClient - Replaced by HybridConversationService
  /// Use HybridConversationService for real-time conversation features

  bool supportsRealtimeForModel(final String? model) => false;

  List<String> getAvailableRealtimeModels() => [];

  bool get supportsRealtime => false;

  String? get defaultRealtimeModel => null;

  // Voice management - Google doesn't have TTS in Gemini API
  Future<List<VoiceInfo>> getAvailableVoices() async => [];
  VoiceGender getVoiceGender(final String voiceName) => VoiceGender.neutral;
  List<String> getVoiceNames() => [];
  bool isValidVoice(final String voiceName) => false;
}
