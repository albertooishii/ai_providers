import 'dart:async';
import 'dart:convert';
// dart:typed_data removed - no longer needed

import '../core/provider_registry.dart';
import '../models/provider_response.dart';
import '../models/ai_provider_metadata.dart';
import '../models/ai_system_prompt.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import '../models/ai_capability.dart';
import '../models/audio_models.dart';
import '../core/base_provider.dart';

/// X.AI Grok provider - optimized and without hardcodes
class XAIProvider extends BaseProvider {
  XAIProvider(super.config);

  static void register() {
    ProviderRegistry.instance
        .registerConstructor('xai', (final config) => XAIProvider(config));
  }

  @override
  String get providerId => 'xai';

  @override
  AIProviderMetadata createMetadata() {
    return AIProviderMetadata(
      providerId: providerId,
      providerName: config.displayName,
      company: 'X.AI',
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
      'Content-Type': 'application/json'
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
    if (m.contains('beta')) return 1;
    if (m.contains('latest')) return 2;
    if (m.contains('preview')) return 3;
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
      default:
        return ProviderResponse(
            text: 'Capability $capability not supported by XAI provider');
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
            text: 'Error: Invalid or missing model for XAI provider');
      }

      final messages = <Map<String, dynamic>>[];

      // Add system prompt
      messages.add(
          {'role': 'system', 'content': jsonEncode(systemPrompt.toJson())});

      // Add conversation history
      for (int i = 0; i < history.length; i++) {
        final content = <Map<String, dynamic>>[];

        // Add text content
        content.add({'type': 'text', 'text': history[i]['content'] ?? ''});

        // Add image if present and it's the last message
        if (imageBase64 != null &&
            imageBase64.isNotEmpty &&
            i == history.length - 1) {
          content.add({
            'type': 'image_url',
            'image_url': {
              'url': createImageDataUri(imageBase64, imageMimeType)
            },
          });
        }

        messages.add({
          'role': history[i]['role'] ?? 'user',
          'content': content.length == 1 ? content.first['text'] : content,
        });
      }

      final bodyMap = {
        'model': selectedModel,
        'messages': messages,
        'max_tokens': config.configuration.maxOutputTokens,
        'temperature': additionalParams?['temperature'] ?? 0.7,
      };

      final url = Uri.parse(getEndpointUrl('chat'));
      final response = await http.Client()
          .post(url, headers: buildAuthHeaders(), body: jsonEncode(bodyMap));

      if (isSuccessfulResponse(response.statusCode)) {
        return _processGrokResponse(jsonDecode(response.body));
      } else {
        handleApiError(response.statusCode, response.body, 'text_generation');
        return ProviderResponse(
            text: 'API Error ${response.statusCode}: ${response.body}');
      }
    } on Exception catch (e) {
      AILogger.e('[XAIProvider] Text request failed: $e');
      return ProviderResponse(text: 'Error: $e');
    }
  }

  ProviderResponse _processGrokResponse(final Map<String, dynamic> data) {
    try {
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final choice = choices.first as Map<String, dynamic>;
        final message = choice['message'] as Map<String, dynamic>?;

        if (message != null) {
          final content = message['content'];
          if (content is String) {
            return ProviderResponse(text: content);
          }
        }
      }

      return ProviderResponse(text: 'No response content found');
    } on Exception catch (e) {
      AILogger.e('[XAIProvider] Error processing response: $e');
      return ProviderResponse(text: 'Error processing response: $e');
    }
  }

  Future<ProviderResponse> generateAudio({
    required final String text,
    final String? voice,
    final String? model,
    final Map<String, dynamic>? additionalParams,
  }) async {
    return ProviderResponse(
        text: 'Audio generation not supported by XAI provider');
  }

  Future<ProviderResponse> transcribeAudio({
    required final String audioBase64,
    final String? audioFormat,
    final String? model,
    final String? language,
    final Map<String, dynamic>? additionalParams,
  }) async {
    return ProviderResponse(
        text: 'Audio transcription not supported by XAI provider');
  }

  /// [REMOVED] createRealtimeClient - Replaced by HybridConversationService
  /// Use HybridConversationService for real-time conversation features

  bool supportsRealtimeForModel(final String? model) => false;

  List<String> getAvailableRealtimeModels() => [];

  bool get supportsRealtime => false;

  String? get defaultRealtimeModel => null;

  // Voice management - XAI doesn't have voice capabilities
  Future<List<VoiceInfo>> getAvailableVoices() async => [];
  VoiceGender getVoiceGender(final String voiceName) => VoiceGender.neutral;
  List<String> getVoiceNames() => [];
  bool isValidVoice(final String voiceName) => false;
}
