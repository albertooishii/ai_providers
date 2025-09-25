import 'dart:async';
import 'package:ai_providers/ai_providers.dart';
import '../utils/logger.dart';

/// 🎙️ **HybridConversationService**
///
/// Servicio pragmático que orquesta la nueva API `AI.*` para conversaciones
/// híbridas con voz (text + TTS + STT):
/// - Combina `AI.text()` + `AI.speak()` + `AI.transcribe()`
/// - Maneja el flujo completo de conversación híbrida con voz
/// - Una sola responsabilidad: conversaciones híbridas (no realtime real)
///
/// **Reemplaza servicios fragmentados:**
/// - ChatService + VoiceService coordination
/// - Múltiples coordinadores de audio/texto
/// - Servicios híbridos existentes
///
/// **Nota:** Para realtime verdadero (streaming), se implementará otro servicio.
class HybridConversationService {
  HybridConversationService();

  // =================================================================
  // STATE MANAGEMENT
  // =================================================================

  bool _isActive = false;
  AISystemPrompt? _currentSystemPrompt;

  // Stream controllers para eventos de conversación
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();
  final StreamController<String> _transcriptionController =
      StreamController<String>.broadcast();
  final StreamController<HybridConversationState> _stateController =
      StreamController<HybridConversationState>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Historial de conversación
  final List<Map<String, String>> _conversationHistory = [];

  // =================================================================
  // PUBLIC STREAMS
  // =================================================================

  /// Stream de respuestas de texto de la IA
  Stream<String> get responseStream => _responseController.stream;

  /// Stream de transcripciones de audio del usuario
  Stream<String> get transcriptionStream => _transcriptionController.stream;

  /// Stream de cambios de estado de la conversación
  Stream<HybridConversationState> get stateStream => _stateController.stream;

  /// Stream de errores
  Stream<String> get errorStream => _errorController.stream;

  /// Historial actual de la conversación
  List<Map<String, String>> get conversationHistory =>
      List.unmodifiable(_conversationHistory);

  /// Indica si hay una conversación activa
  bool get isActive => _isActive;

  /// System prompt actual para la conversación
  AISystemPrompt? get currentSystemPrompt => _currentSystemPrompt;

  // =================================================================
  // CONVERSATION MANAGEMENT
  // =================================================================

  /// Inicia una conversación en tiempo real con voz
  ///
  /// [systemPrompt] - Prompt del sistema que define el contexto y comportamiento de la IA
  /// [initialMessage] - Mensaje inicial opcional de la IA
  Future<void> startConversation(final AISystemPrompt systemPrompt,
      {final String? initialMessage}) async {
    if (_isActive) {
      AILogger.w('[HybridConversation] Ya hay una conversación activa');
      return;
    }

    try {
      AILogger.d('[HybridConversation] 🚀 Iniciando conversación realtime');

      _isActive = true;
      _currentSystemPrompt = systemPrompt;
      _conversationHistory.clear();

      _stateController.add(HybridConversationState.initializing);

      // Mensaje inicial de la IA si se proporciona
      if (initialMessage != null && initialMessage.isNotEmpty) {
        await _processAIResponse(initialMessage, speakResponse: true);
      }

      _stateController.add(HybridConversationState.listening);
      AILogger.d('[HybridConversation] ✅ Conversación iniciada');
    } on Exception catch (e) {
      AILogger.e('[HybridConversation] Error iniciando conversación: $e');
      _errorController.add('Error iniciando conversación: $e');
      await stopConversation();
    }
  }

  /// Envía un mensaje de texto (sin voz)
  Future<void> sendTextMessage(final String message) async {
    if (!_isActive || _currentSystemPrompt == null) {
      AILogger.w('[HybridConversation] No hay conversación activa');
      return;
    }

    try {
      AILogger.d(
          '[HybridConversation] 📝 Enviando mensaje de texto: "$message"');

      _stateController.add(HybridConversationState.processing);

      // Agregar mensaje del usuario al historial
      _conversationHistory.add({'role': 'user', 'content': message});

      // Usar nueva API AI.text() con mensaje y systemPrompt actualizado
      final updatedSystemPrompt = _currentSystemPrompt!.copyWith(
        dateTime: DateTime.now(),
        history: _conversationHistory,
      );

      final response = await AI.text(message, updatedSystemPrompt);

      await _processAIResponse(response.text, speakResponse: true);
    } on Exception catch (e) {
      AILogger.e('[HybridConversation] Error enviando mensaje: $e');
      _errorController.add('Error enviando mensaje: $e');
      _stateController.add(HybridConversationState.listening);
    }
  }

  /// Envía audio para transcribir y procesar
  Future<void> sendAudioMessage(final String audioBase64) async {
    if (!_isActive || _currentSystemPrompt == null) {
      AILogger.w('[HybridConversation] No hay conversación activa');
      return;
    }

    try {
      AILogger.d('[HybridConversation] 🎤 Procesando mensaje de audio');

      _stateController.add(HybridConversationState.transcribing);

      // Usar nueva API AI.transcribe()
      final transcriptionResponse = await AI.transcribe(audioBase64);
      final transcribedText = transcriptionResponse.text;

      if (transcribedText.trim().isEmpty) {
        AILogger.w('[HybridConversation] Transcripción vacía');
        _stateController.add(HybridConversationState.listening);
        return;
      }

      AILogger.d('[HybridConversation] 📝 Transcrito: "$transcribedText"');
      _transcriptionController.add(transcribedText);

      // Procesar el texto transcrito como mensaje normal
      await sendTextMessage(transcribedText);
    } on Exception catch (e) {
      AILogger.e('[HybridConversation] Error procesando audio: $e');
      _errorController.add('Error procesando audio: $e');
      _stateController.add(HybridConversationState.listening);
    }
  }

  /// Detiene la conversación actual
  Future<void> stopConversation() async {
    if (!_isActive) return;

    AILogger.d('[HybridConversation] ⏹️ Deteniendo conversación');

    _isActive = false;
    _currentSystemPrompt = null;
    _stateController.add(HybridConversationState.stopped);

    AILogger.d('[HybridConversation] ✅ Conversación detenida');
  }

  /// Hace que la IA hable un mensaje predefinido (sin agregar al historial de conversación)
  /// Útil para mensajes del sistema, bienvenidas, instrucciones, etc.
  Future<void> speakPredefinedMessage(final String message) async {
    if (!_isActive) {
      AILogger.w(
          '[HybridConversation] No hay conversación activa para mensaje predefinido');
      return;
    }

    try {
      AILogger.d(
          '[HybridConversation] 📢 Hablando mensaje predefinido: "$message"');
      await _processAIResponse(message, speakResponse: true);
    } on Exception catch (e) {
      AILogger.e('[HybridConversation] Error hablando mensaje predefinido: $e');
      _errorController.add('Error hablando mensaje predefinido: $e');
    }
  }

  /// Limpia el historial de conversación
  void clearHistory() {
    _conversationHistory.clear();
    AILogger.d('[HybridConversation] 🧹 Historial limpiado');
  }

  // =================================================================
  // PRIVATE HELPERS
  // =================================================================

  /// Procesa la respuesta de la IA y opcionalmente la convierte a voz
  Future<void> _processAIResponse(final String responseText,
      {final bool speakResponse = false}) async {
    // Agregar respuesta de la IA al historial
    _conversationHistory.add({'role': 'assistant', 'content': responseText});

    // Emitir respuesta de texto
    _responseController.add(responseText);

    if (speakResponse) {
      try {
        _stateController.add(HybridConversationState.speaking);

        // Usar nueva API AI.speak() para generar audio
        final _ = await AI.speak(responseText);

        AILogger.d('[HybridConversation] 🔊 Audio generado para respuesta');

        // Aquí podrías reproducir el audio o emitir un evento
        // Por ahora solo loggeamos que se generó
      } on Exception catch (e) {
        AILogger.e('[HybridConversation] Error generando audio: $e');
        // No es crítico, continuamos sin audio
      }
    }

    _stateController.add(HybridConversationState.listening);
  }

  // =================================================================
  // CLEANUP
  // =================================================================

  /// Libera recursos
  void dispose() {
    stopConversation();
    _responseController.close();
    _transcriptionController.close();
    _stateController.close();
    _errorController.close();
  }
}

// =================================================================
// ENUMS
// =================================================================

/// Estados de la conversación híbrida
enum HybridConversationState {
  initializing,
  listening,
  transcribing,
  processing,
  speaking,
  stopped
}
