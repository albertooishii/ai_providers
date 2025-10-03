import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../models/ai_response.dart';
import '../models/ai_audio.dart';

import '../models/ai_capability.dart';
import '../models/ai_system_prompt.dart';
import '../core/ai_provider_manager.dart';
import '../utils/logger.dart';
import '../utils/waveform_utils.dart';
import '../infrastructure/cache_service.dart';

/// 🎧 AudioTranscriptionService - Servicio completo de transcripción de audio
///
/// Consolida TODA la funcionalidad de STT/transcripción:
/// - Transcripción de archivos usando AI.listen()
/// - Grabación de audio con transcripción en tiempo real
/// - Gestión de permisos de micrófono
/// - Detección automática de plataforma (móvil vs desktop)
/// - Streams de waveform y transcripción en vivo
/// - Gestión inteligente de timeouts y silencios
///
/// Reemplaza stt_service.dart (680 líneas) con funcionalidad consolidada
class AudioTranscriptionService {
  AudioTranscriptionService._();
  static final AudioTranscriptionService _instance =
      AudioTranscriptionService._();
  static AudioTranscriptionService get instance => _instance;

  // Grabación
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  // Control manual para forzar terminación
  bool _forceStop = false;
  bool _isInSilenceDetectionMode = false;
  Completer<AIResponse?>? _manualStopCompleter;
  StreamSubscription<Uint8List>? _currentStreamSubscription;

  // Calibración de ruido ambiente para detección de silencio adaptativa
  double _ambientNoiseLevel = 0.0;
  bool _isNoiseCalibrated = false;

  // Streams
  final StreamController<List<int>> _waveformController =
      StreamController<List<int>>.broadcast();
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  // Getters
  bool get isRecording => _isRecording;
  Duration get recordingDuration => _recordingDuration;

  // Streams
  Stream<List<int>> get waveformStream => _waveformController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  /// 🎯 MÉTODO DE INTEGRACIÓN - usado por AI.listen()
  ///
  /// Recibe mismos parámetros que AI.listen() y delega a AIProviderManager.
  /// Esta es la firma EXACTA que necesita AI.listen() para evitar circular dependency.
  Future<AIResponse> transcribe(
    final String audioBase64, [
    final AISystemPrompt? systemPrompt,
  ]) async {
    try {
      AILogger.d('[AudioTranscriptionService] 🎧 Transcribiendo audio...');

      // Usar el Context proporcionado o crear uno por defecto
      final effectiveContext =
          systemPrompt ?? _createDefaultTranscriptionContext();

      // Llamar directamente a AIProviderManager (no a AI.listen() para evitar circular dependency)
      // Nota: El caché está deshabilitado para audioTranscription en AIProviderManager
      return await AIProviderManager.instance.sendMessage(
        message:
            'CRITICAL: You are a speech transcription system. ONLY transcribe the actual spoken words in the provided audio. Do NOT create fictional dialogue. Do NOT generate sample conversations about Maria del Carmen, directors, schools, or any invented content. If no clear speech is detected, return empty text. Transcribe ONLY what is actually spoken.',
        systemPrompt: effectiveContext,
        capability: AICapability.audioTranscription,
        imageBase64: audioBase64, // Reutilizamos imageBase64 para audio
      );
    } catch (e) {
      AILogger.e(
          '[AudioTranscriptionService] ❌ Error transcribiendo audio: $e');
      rethrow;
    }
  }

  /// Transcribir archivo de audio usando AI.listen()
  Future<AIResponse> transcribeAudioFile(final String filePath) async {
    try {
      AILogger.d(
        '[AudioTranscriptionService] 🎧 Transcribiendo archivo: $filePath',
      );

      if (!File(filePath).existsSync()) {
        throw Exception('Archivo no existe: $filePath');
      }

      // Leer archivo y convertir a base64
      final audioBytes = await File(filePath).readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      // 🚀 Usar nuestro método de integración (no AI.listen() para evitar circular)
      final response = await transcribe(base64Audio);

      AILogger.d(
        '[AudioTranscriptionService] ✅ Transcripción completada: ${response.text.length} chars',
      );
      return response;
    } on Exception catch (e) {
      AILogger.e(
        '[AudioTranscriptionService] Error transcribiendo archivo: $e',
      );
      rethrow;
    }
  }

  /// Transcribir audio desde base64
  Future<AIResponse> transcribeAudio(final String audioBase64) async {
    try {
      AILogger.d('[AudioTranscriptionService] 🎧 Transcribiendo audio base64');
      return await transcribe(audioBase64);
    } on Exception catch (e) {
      AILogger.e('[AudioTranscriptionService] Error transcribiendo base64: $e');
      rethrow;
    }
  }

  /// Transcribir audio desde bytes
  Future<AIResponse> transcribeBytes(final Uint8List audioBytes) async {
    try {
      AILogger.d(
        '[AudioTranscriptionService] 🎧 Transcribiendo ${audioBytes.length} bytes',
      );
      final base64Audio = base64Encode(audioBytes);
      return await transcribe(base64Audio);
    } on Exception catch (e) {
      AILogger.e('[AudioTranscriptionService] Error transcribiendo bytes: $e');
      rethrow;
    }
  }

  /// Verificar permisos de micrófono
  Future<bool> hasPermissions() async {
    try {
      return await _recorder.hasPermission();
    } on Exception catch (e) {
      AILogger.e('[AudioTranscriptionService] Error verificando permisos: $e');
      return false;
    }
  }

  /// Solicitar permisos de micrófono
  Future<bool> requestPermissions() async {
    try {
      return await _recorder.hasPermission();
    } on Exception catch (e) {
      AILogger.e('[AudioTranscriptionService] Error solicitando permisos: $e');
      return false;
    }
  }

  /// 🎯 MÉTODO PRINCIPAL: Grabar y transcribir audio con funcionalidad avanzada
  /// Este es el método principal del servicio para funcionalidad completa STT
  ///
  /// CASOS DE USO:
  /// - Básico: recordAndTranscribe(duration: Duration(seconds: 5))
  /// - Auto-detección: recordAndTranscribe(duration: null, autoStop: true)
  /// - Control fino: recordAndTranscribe(silenceTimeout: Duration(seconds: 2))
  ///
  /// [duration] - Duración máxima (null = ilimitado hasta silencio)
  /// [silenceTimeout] - Tiempo de silencio para auto-detención
  /// [autoStop] - Detener automáticamente al detectar silencio
  /// [systemPrompt] - Contexto e instrucciones del sistema para transcripción
  ///
  /// **Devuelve:**
  /// - AIResponse con transcripción si autoStop=true o duration!=null
  /// - null si autoStop=false (grabación iniciada, sin resultado aún)
  Future<AIResponse?> recordAndTranscribe({
    final Duration? duration,
    final Duration silenceTimeout = const Duration(seconds: 2),
    final bool autoStop = true,
    final AISystemPrompt? systemPrompt,
  }) async {
    try {
      // Log de configuración inteligente
      final configLog = duration != null
          ? 'fixed duration: ${duration.inSeconds}s'
          : autoStop
              ? 'auto-stop on silence (${silenceTimeout.inSeconds}s timeout)'
              : 'manual stop only';

      AILogger.d(
          '[AudioTranscriptionService] 🎯 recordAndTranscribe with $configLog');

      // Verificar permisos
      if (!await hasPermissions()) {
        throw Exception('Permisos de micrófono denegados');
      }

      // Iniciar grabación
      await startRecording();

      // Lógica de grabación avanzada
      AIResponse? result;
      if (duration != null) {
        // Modo duración fija - comportamiento original
        await Future.delayed(duration);
        result = await stopRecording();
      } else if (autoStop) {
        // Modo auto-detección de silencio
        result = await _recordWithSilenceDetection(silenceTimeout);
      } else {
        // Modo manual - solo iniciar, el usuario debe llamar stopRecording()
        AILogger.d(
            '[AudioTranscriptionService] Recording started - manual stop required, returning null');
        return null; // ✅ Retorna null para indicar que no hay resultado aún
      }

      // Las instrucciones de transcripción se pasan directamente al provider via Context
      if (result != null) {
        AILogger.d(
            '[AudioTranscriptionService] ✅ recordAndTranscribe completado: ${result.text}');
        return result;
      } else {
        return null; // ✅ Retorna null si no hay resultado
      }
    } catch (e) {
      AILogger.e(
          '[AudioTranscriptionService] Error en recordAndTranscribe(): $e');
      await cancelRecording(); // Limpiar en caso de error
      rethrow;
    }
  }

  /// Iniciar grabación con transcripción en tiempo real
  Future<void> startRecording() async {
    try {
      if (_isRecording) {
        AILogger.w(
          '[AudioTranscriptionService] Ya hay una grabación en progreso',
        );
        return;
      }

      // Reset completo del estado para evitar problemas entre grabaciones
      _resetRecordingState();

      // Verificar permisos
      if (!await hasPermissions()) {
        throw Exception('Permisos de micrófono denegados');
      }

      AILogger.d('[AudioTranscriptionService] 🎤 Iniciando grabación...');

      // Configurar grabación
      const config = RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000);

      // Obtener directorio de cache para audio
      final cacheService = CompleteCacheService.instance;
      final audioDir = await cacheService.getAudioCacheDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final recordingPath = '${audioDir.path}/recording_$timestamp.wav';

      // Iniciar grabación
      await _recorder.start(config, path: recordingPath);
      _isRecording = true;
      _recordingDuration = Duration.zero;

      // Iniciar timers para waveform y duración
      _startRecordingTimers();

      AILogger.d('[AudioTranscriptionService] ✅ Grabación iniciada');
    } on Exception catch (e) {
      AILogger.e('[AudioTranscriptionService] Error iniciando grabación: $e');
      rethrow;
    }
  }

  /// Detener grabación y transcribir
  /// **Devuelve:** AIResponse con transcripción en `text` y audio grabado en `audio` (URL + base64)
  Future<AIResponse?> stopRecording() async {
    try {
      if (!_isRecording) {
        AILogger.w('[AudioTranscriptionService] No hay grabación activa');
        return null;
      }

      AILogger.d('[AudioTranscriptionService] ⏹️ Manual stop requested...');

      // Si estamos en modo detección de silencio, detener inmediatamente
      if (_isInSilenceDetectionMode) {
        AILogger.d(
            '[AudioTranscriptionService] 🛑 Forcing stop in silence detection mode');
        _forceStop = true;

        // Detener el stream inmediatamente para cerrar el micrófono
        if (_currentStreamSubscription != null) {
          await _currentStreamSubscription!.cancel();
          _currentStreamSubscription = null;
          AILogger.d(
              '[AudioTranscriptionService] 🎤 Microphone stream closed immediately');
        }

        // Forzar liberación del recorder para asegurar que el micrófono se cierra
        if (await _recorder.isRecording()) {
          await _recorder.stop();
          AILogger.d(
              '[AudioTranscriptionService] 🎤 Recorder force-stopped to release microphone');
        }

        // Crear completer para esperar el resultado
        _manualStopCompleter = Completer<AIResponse?>();

        // Esperar hasta que _recordWithSilenceDetection() complete la transcripción
        return await _manualStopCompleter!.future;
      }

      // Modo normal: detener grabación directamente
      final audioPath = await _recorder.stop();
      _isRecording = false;
      _stopRecordingTimers();

      if (audioPath == null) {
        AILogger.w('[AudioTranscriptionService] No se generó archivo de audio');
        return null;
      }

      // Transcribir el audio grabado
      AILogger.d(
        '[AudioTranscriptionService] 🎧 Transcribiendo audio grabado...',
      );
      final response = await transcribeAudioFile(audioPath);

      // NO limpiar archivo - mantener en caché para reutilización
      AILogger.d(
          '[AudioTranscriptionService] 💾 Audio guardado en caché: $audioPath');

      final transcript = response.text.trim();
      AILogger.d(
        '[AudioTranscriptionService] ✅ Transcripción completada: $transcript',
      );

      // Crear AIResponse con transcripción Y audio grabado
      final result = await _createAIResponseWithAudio(
          audioPath, transcript, response.provider);

      // Reset estado para próxima grabación
      _resetRecordingState();

      return result;
    } on Exception catch (e) {
      AILogger.e('[AudioTranscriptionService] Error deteniendo grabación: $e');
      _isRecording = false;
      _stopRecordingTimers();
      _resetRecordingState(); // Reset también en caso de error
      return null;
    }
  }

  /// Cancelar grabación actual
  Future<void> cancelRecording() async {
    try {
      if (!_isRecording) return;

      AILogger.d('[AudioTranscriptionService] 🚫 Cancelando grabación...');

      // Cancelar stream si existe
      if (_currentStreamSubscription != null) {
        await _currentStreamSubscription!.cancel();
        _currentStreamSubscription = null;
      }

      await _recorder.stop();
      _isRecording = false;
      _stopRecordingTimers();
      _resetRecordingState();

      AILogger.d('[AudioTranscriptionService] Grabación cancelada');
    } on Exception catch (e) {
      AILogger.e('[AudioTranscriptionService] Error cancelando grabación: $e');
    }
  }

  // === MÉTODOS PRIVADOS ===

  /// Crea AIResponse con transcripción y audio completo (URL + base64)
  Future<AIResponse> _createAIResponseWithAudio(
      final String audioPath, final String transcript,
      [final String? provider]) async {
    try {
      // Leer archivo de audio para obtener base64 y metadatos
      final file = File(audioPath);
      final audioBytes = await file.readAsBytes();
      final base64Audio = base64Encode(audioBytes);
      final fileStat = file.statSync();

      // Crear objeto AiAudio con toda la información
      final aiAudio = AiAudio(
        url: audioPath,
        transcript: transcript,
        base64: base64Audio,
        durationMs: _recordingDuration.inMilliseconds,
        createdAtMs: fileStat.modified.millisecondsSinceEpoch,
        isAutoTts: false, // Es grabación, no TTS
      );

      return AIResponse(
        text: transcript,
        provider: provider ?? 'transcription_service',
        audio: aiAudio,
      );
    } on Exception catch (e) {
      AILogger.e(
          '[AudioTranscriptionService] Error creando AIResponse con audio: $e');
      // Fallback: solo transcripción sin audio
      return AIResponse(text: transcript, provider: 'transcription_service');
    }
  }

  /// Crea Context por defecto para transcripción de audio
  AISystemPrompt _createDefaultTranscriptionContext() {
    final context = <String, dynamic>{
      'task': 'audio_transcription',
      'stt': true,
      'prevent_hallucinations': true,
    };

    final instructions = <String, dynamic>{
      'language': 'auto',
      'format': 'simple',
      'includePunctuation': true,
      'includeTimestamps': false,
      'preventHallucinations': true,
      'context': 'general',
    };

    return AISystemPrompt(
      context: context,
      dateTime: DateTime.now(),
      instructions: instructions,
    );
  }

  /// Grabación con detección automática de silencio REAL
  Future<AIResponse?> _recordWithSilenceDetection(
      final Duration silenceTimeout) async {
    AILogger.d(
        '[AudioTranscriptionService] 🔇 Starting REAL silence detection with ${silenceTimeout.inSeconds}s timeout');

    try {
      // Marcar que estamos en modo detección de silencio
      _isInSilenceDetectionMode = true;
      // Configuración para stream - usar PCM ya que guardamos manualmente
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      // Variables para detección de silencio mejorada
      final maxDuration = const Duration(seconds: 60); // Límite máximo
      final startTime = DateTime.now();
      DateTime? silenceStartTime;

      // Buffer para análisis de audio y calibración
      final audioBuffer = <int>[];
      final calibrationSamples = <double>[];
      bool calibrationComplete = false;
      final calibrationDuration =
          const Duration(milliseconds: 1000); // 1s para calibrar ruido ambiente

      // Variables de detección adaptativa
      double dynamicSilenceThreshold =
          0.01; // Umbral inicial básico      // Obtener directorio de cache para audio
      final cacheService = CompleteCacheService.instance;
      final audioDir = await cacheService.getAudioCacheDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final recordingPath = '${audioDir.path}/recording_silence_$timestamp.wav';

      // Usar SOLO stream - grabamos manualmente los chunks
      final audioStream = await _recorder.startStream(config);
      final audioFile = File(recordingPath);
      final audioSink = audioFile.openWrite();

      // Escuchar stream de audio para análisis Y guardado
      _currentStreamSubscription = audioStream.listen((final audioChunk) {
        // Guardar chunk al archivo
        audioSink.add(audioChunk); // Agregar al buffer para análisis
        final samples = _convertBytesToSamples(audioChunk);
        audioBuffer.addAll(samples);

        // Mantener buffer de último segundo para análisis
        final samplesPerSecond = 16000; // 16kHz
        if (audioBuffer.length > samplesPerSecond) {
          audioBuffer.removeRange(0, audioBuffer.length - samplesPerSecond);
        }

        // Calcular volumen RMS de las últimas muestras
        final volumeLevel = _calculateRMSVolume(audioBuffer);

        // Calibración continua NO BLOQUEANTE - funciona en paralelo con la detección
        if (!calibrationComplete &&
            !_isNoiseCalibrated &&
            DateTime.now().difference(startTime) < calibrationDuration) {
          calibrationSamples.add(volumeLevel);

          // Calibración adaptativa instantánea - usa muestras disponibles hasta ahora
          if (calibrationSamples.length >= 5) {
            // Con 5+ muestras ya se puede estimar
            final currentAvg =
                calibrationSamples.reduce((final a, final b) => a + b) /
                    calibrationSamples.length;
            _ambientNoiseLevel = currentAvg;
            // Usar threshold más inteligente basado en nivel de ruido ambiente
            if (_ambientNoiseLevel > 0.5) {
              // Ambiente muy ruidoso - threshold más alto
              dynamicSilenceThreshold = _ambientNoiseLevel * 0.6;
            } else if (_ambientNoiseLevel > 0.1) {
              // Ambiente con algo de ruido - threshold medio
              dynamicSilenceThreshold = _ambientNoiseLevel * 0.8;
            } else {
              // Ambiente silencioso - threshold bajo
              dynamicSilenceThreshold = 0.05;
            }

            // Completar calibración al final del período
            if (DateTime.now().difference(startTime) >= calibrationDuration) {
              calibrationComplete = true;
              _isNoiseCalibrated = true;
              // Ajuste final más preciso y robusto
              if (_ambientNoiseLevel > 0.5) {
                dynamicSilenceThreshold =
                    _ambientNoiseLevel * 0.5; // Muy ruidoso
              } else if (_ambientNoiseLevel > 0.1) {
                dynamicSilenceThreshold =
                    _ambientNoiseLevel * 0.7; // Algo ruidoso
              } else {
                dynamicSilenceThreshold = 0.03; // Silencioso
              }

              AILogger.d(
                  '[AudioTranscriptionService] 🎯 Adaptive calibration complete - Ambient: ${(_ambientNoiseLevel * 100).toStringAsFixed(2)}%, Final threshold: ${(dynamicSilenceThreshold * 100).toStringAsFixed(2)}%');
            }
          }
        }

        // Detección de silencio inteligente - funciona desde el primer momento
        // Usa umbral dinámico si está disponible, o usa umbral adaptativo inteligente
        final currentThreshold = calibrationComplete
            ? dynamicSilenceThreshold
            : (_ambientNoiseLevel > 0.1
                ? _ambientNoiseLevel *
                    0.8 // Si hay ruido ambiente, usar 80% del nivel
                : 0.05); // Si no hay datos aún, threshold más alto (5%)
        final isCurrentlySilent = volumeLevel < currentThreshold;

        // Solo empezar a contar silencio después de 800ms (permite hablar inmediatamente)
        final recordingTime = DateTime.now().difference(startTime);
        if (recordingTime.inMilliseconds > 800) {
          if (isCurrentlySilent) {
            // Inicio del silencio
            silenceStartTime ??= DateTime.now();

            // Verificar si hemos estado en silencio por el tiempo requerido
            final silenceDuration =
                DateTime.now().difference(silenceStartTime!);
            if (silenceDuration >= silenceTimeout) {
              final thresholdType = calibrationComplete ? 'adaptive' : 'basic';
              AILogger.d(
                  '[AudioTranscriptionService] 🔇 ${thresholdType.toUpperCase()} silence detected for ${silenceDuration.inMilliseconds}ms (volume: ${(volumeLevel * 100).toStringAsFixed(1)}%, threshold: ${(currentThreshold * 100).toStringAsFixed(1)}%)');
            }
          } else {
            // Resetear contador de silencio si hay sonido por encima del umbral
            silenceStartTime = null;
          }
        }

        // Log de nivel de volumen cada 2 segundos con mejor información
        if (DateTime.now().difference(startTime).inSeconds % 2 == 0) {
          final status = calibrationComplete ? 'CALIBRATED' : 'CALIBRATING';
          final voiceDetected = volumeLevel >
              (currentThreshold * 1.5); // 50% por encima del threshold
          final statusIcon = voiceDetected ? '🗣️' : '🔇';
          AILogger.d(
              '[AudioTranscriptionService] 📊 [$status] $statusIcon Volume: ${(volumeLevel * 100).toStringAsFixed(1)}% (threshold: ${(currentThreshold * 100).toStringAsFixed(1)}%, ambient: ${(_ambientNoiseLevel * 100).toStringAsFixed(1)}%) ${voiceDetected ? 'VOICE DETECTED' : 'SILENCE'}');
        }
      });

      // Esperar hasta que se detecte silencio, se alcance el tiempo máximo, o se fuerce la terminación
      while (
          DateTime.now().difference(startTime) < maxDuration && !_forceStop) {
        await Future.delayed(const Duration(milliseconds: 100));

        // Verificar si detectamos silencio
        if (silenceStartTime != null) {
          final silenceDuration = DateTime.now().difference(silenceStartTime!);
          if (silenceDuration >= silenceTimeout) {
            AILogger.d(
                '[AudioTranscriptionService] 🔇 Silence threshold reached, stopping recording');
            break;
          }
        }
      }

      // Verificar si se detuvo por forzado manual
      if (_forceStop) {
        AILogger.d(
            '[AudioTranscriptionService] 🛑 Manual stop detected, ending recording');
      }

      // Detener stream si no se ha cancelado ya
      if (_currentStreamSubscription != null) {
        await _currentStreamSubscription!.cancel();
        _currentStreamSubscription = null;
      }
      await audioSink.close();

      // CRÍTICO: Detener el recorder explícitamente para liberar el micrófono del SO
      if (await _recorder.isRecording()) {
        await _recorder.stop();
        AILogger.d(
            '[AudioTranscriptionService] 🎤 Recorder stopped - microphone released');
      }

      // Convertir PCM a WAV para compatibilidad
      final pcmBytes = await File(recordingPath).readAsBytes();
      final wavBytes = _createWavFile(
        pcmBytes,
        sampleRate: 16000,
        channels: 1,
        bitsPerSample: 16,
      );
      await File(recordingPath).writeAsBytes(wavBytes);

      // Transcribir el audio grabado
      AILogger.d(
          '[AudioTranscriptionService] 🎧 Transcribing recorded audio...');
      final response = await transcribeAudioFile(recordingPath);

      // NO limpiar archivo - mantener en caché para reutilización
      AILogger.d(
          '[AudioTranscriptionService] 💾 Audio guardado en caché: $recordingPath');

      final transcript = response.text.trim();
      AILogger.d(
          '[AudioTranscriptionService] ✅ Real silence detection completed: $transcript');

      final result = transcript.isNotEmpty ? transcript : null;

      // Crear AIResponse con audio si tenemos resultado y recordingPath
      final audioResponse = result != null
          ? await _createAIResponseWithAudio(
              recordingPath, result, response.provider)
          : AIResponse(text: result ?? '', provider: 'transcription_service');

      // Si hay un completer esperando (manual stop), completarlo
      if (_manualStopCompleter != null && !_manualStopCompleter!.isCompleted) {
        _manualStopCompleter!.complete(audioResponse);
      }

      // CRÍTICO: Reset del estado después de completar la transcripción
      // para que la siguiente grabación funcione correctamente
      _resetRecordingState();

      return audioResponse;
    } on Exception catch (e) {
      AILogger.e(
          '[AudioTranscriptionService] Error in real silence detection: $e');

      // Si hay un completer esperando (manual stop), completarlo con error
      if (_manualStopCompleter != null && !_manualStopCompleter!.isCompleted) {
        _manualStopCompleter!.complete(null);
      }

      // Reset del estado también en caso de error
      _resetRecordingState();

      return AIResponse(
          text: '',
          provider:
              'transcription_service'); // Retornar AIResponse vacío en caso de error
    }
  }

  /// Convertir bytes de audio a muestras enteras para análisis
  List<int> _convertBytesToSamples(final Uint8List audioBytes) {
    final samples = <int>[];

    // PCM 16-bit: cada muestra son 2 bytes (little-endian)
    for (int i = 0; i < audioBytes.length - 1; i += 2) {
      final sample = (audioBytes[i + 1] << 8) | audioBytes[i];
      // Convertir de unsigned a signed 16-bit
      final signedSample = sample > 32767 ? sample - 65536 : sample;
      samples.add(signedSample);
    }

    return samples;
  }

  /// Calcular volumen RMS (Root Mean Square) de las muestras de audio
  double _calculateRMSVolume(final List<int> samples) {
    if (samples.isEmpty) return 0.0;

    // Calcular la suma de cuadrados
    double sumOfSquares = 0.0;
    for (final sample in samples) {
      sumOfSquares += sample * sample;
    }

    // Calcular RMS y normalizar (dividir por el valor máximo de 16-bit)
    final rms = sqrt(sumOfSquares / samples.length);
    return rms / 32768.0; // Normalizar a rango 0.0 - 1.0
  }

  // === MÉTODOS SIMPLIFICADOS DE FORMATO ===
  // Nota: El formato real ahora se maneja directamente en los providers via Context

  void _startRecordingTimers() {
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
      final timer,
    ) {
      _recordingDuration = Duration(
        milliseconds: _recordingDuration.inMilliseconds + 100,
      );
      _durationController.add(_recordingDuration);

      // Generar waveform animado usando utility
      final waveform = WaveformUtils.animateRecordingWaveform(
        _recordingDuration,
      );
      _waveformController.add(waveform);

      // Simular transcripción en vivo (en implementación real vendría del STT)
      _updateLiveTranscript();
    });
  }

  void _stopRecordingTimers() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  void _resetRecordingState() {
    // Reset variables de grabación básicas
    _recordingDuration = Duration.zero;
    _durationController.add(Duration.zero);
    _transcriptController.add('');
    _waveformController.add(<int>[]);

    // Reset variables de calibración de ruido para nueva grabación
    _ambientNoiseLevel = 0.0;
    _isNoiseCalibrated = false;

    // Reset control manual de terminación
    _forceStop = false;
    _isInSilenceDetectionMode = false;
    _manualStopCompleter = null;
    _currentStreamSubscription = null;

    AILogger.d(
        '[AudioTranscriptionService] 🔄 Recording state reset - ready for new recording');
  }

  void _updateLiveTranscript() {
    // Actualizar el transcript placeholder durante la grabación
    // En implementación real, esto vendría del STT en streaming
    _transcriptController.add('Grabando... ${_recordingDuration.inSeconds}s');
  }

  /// Limpiar recursos
  void dispose() {
    // Cancelar grabación si está activa
    if (_isRecording) {
      cancelRecording();
    }

    // Cerrar streams
    _waveformController.close();
    _transcriptController.close();
    _durationController.close();

    // Detener timers
    _stopRecordingTimers();

    AILogger.d('[AudioTranscriptionService] Recursos liberados');
  }

  /// Convertir datos PCM a formato WAV
  Uint8List _createWavFile(
    final Uint8List pcmData, {
    required final int sampleRate,
    required final int channels,
    required final int bitsPerSample,
  }) {
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final wavBytes = ByteData(44 + dataSize);
    var offset = 0;

    // RIFF header
    wavBytes.setUint8(offset++, 0x52); // 'R'
    wavBytes.setUint8(offset++, 0x49); // 'I'
    wavBytes.setUint8(offset++, 0x46); // 'F'
    wavBytes.setUint8(offset++, 0x46); // 'F'
    wavBytes.setUint32(offset, fileSize, Endian.little);
    offset += 4;

    // WAVE format
    wavBytes.setUint8(offset++, 0x57); // 'W'
    wavBytes.setUint8(offset++, 0x41); // 'A'
    wavBytes.setUint8(offset++, 0x56); // 'V'
    wavBytes.setUint8(offset++, 0x45); // 'E'

    // fmt chunk
    wavBytes.setUint8(offset++, 0x66); // 'f'
    wavBytes.setUint8(offset++, 0x6D); // 'm'
    wavBytes.setUint8(offset++, 0x74); // 't'
    wavBytes.setUint8(offset++, 0x20); // ' '
    wavBytes.setUint32(offset, 16, Endian.little); // fmt chunk size
    offset += 4;
    wavBytes.setUint16(offset, 1, Endian.little); // audio format (PCM)
    offset += 2;
    wavBytes.setUint16(offset, channels, Endian.little);
    offset += 2;
    wavBytes.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    wavBytes.setUint32(offset, sampleRate * channels * (bitsPerSample ~/ 8),
        Endian.little); // byte rate
    offset += 4;
    wavBytes.setUint16(
        offset, channels * (bitsPerSample ~/ 8), Endian.little); // block align
    offset += 2;
    wavBytes.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data chunk
    wavBytes.setUint8(offset++, 0x64); // 'd'
    wavBytes.setUint8(offset++, 0x61); // 'a'
    wavBytes.setUint8(offset++, 0x74); // 't'
    wavBytes.setUint8(offset++, 0x61); // 'a'
    wavBytes.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // PCM data
    for (int i = 0; i < pcmData.length; i++) {
      wavBytes.setUint8(offset + i, pcmData[i]);
    }

    return wavBytes.buffer.asUint8List();
  }
}
