/// Servicio consolidado de monitoreo y optimización
/// Combina performance monitoring y request deduplication
library;

import 'dart:async';
import 'dart:convert';
import '../utils/logger.dart';
import '../models/ai_response.dart';
import '../models/ai_system_prompt.dart';

/// Métricas de rendimiento para un provider
class ProviderMetrics {
  ProviderMetrics(this.providerId);

  final String providerId;
  final List<int> _responseTimes = [];
  final List<bool> _successResults = [];
  final Map<String, int> _errorCounts = {};
  int _totalRequests = 0;
  DateTime? _lastRequestTime;
  DateTime? _firstRequestTime;

  /// Agregar medición de rendimiento
  void addMeasurement(
      {required final int responseTimeMs,
      required final bool success,
      final String? errorType}) {
    _totalRequests++;
    _responseTimes.add(responseTimeMs);
    _successResults.add(success);

    final now = DateTime.now();
    _lastRequestTime = now;
    _firstRequestTime ??= now;

    if (!success && errorType != null) {
      _errorCounts[errorType] = (_errorCounts[errorType] ?? 0) + 1;
    }

    // Mantener solo últimas 1000 métricas para evitar memory leaks
    if (_responseTimes.length > 1000) {
      _responseTimes.removeAt(0);
      _successResults.removeAt(0);
    }
  }

  /// Estadísticas calculadas
  double get averageResponseTime {
    if (_responseTimes.isEmpty) return 0.0;
    return _responseTimes.reduce((final a, final b) => a + b) /
        _responseTimes.length;
  }

  double get successRate {
    if (_successResults.isEmpty) return 1.0;
    final successes = _successResults.where((final s) => s).length;
    return successes / _successResults.length;
  }

  int get totalRequests => _totalRequests;
  Map<String, int> get errorCounts => Map.unmodifiable(_errorCounts);
  DateTime? get lastRequestTime => _lastRequestTime;
  DateTime? get firstRequestTime => _firstRequestTime;
}

/// Huella dactilar de request para deduplicación
class RequestFingerprint {
  const RequestFingerprint({
    required this.hash,
    required this.providerId,
    required this.model,
    required this.capability,
    this.metadata = const {},
  });

  final String hash;
  final String providerId;
  final String model;
  final String capability;
  final Map<String, dynamic> metadata;

  @override
  String toString() => hash;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is RequestFingerprint &&
          runtimeType == other.runtimeType &&
          hash == other.hash;

  @override
  int get hashCode => hash.hashCode;
}

/// Request en vuelo para deduplicación
class InFlightRequest {
  InFlightRequest(this.completer, this.timestamp);

  final Completer<AIResponse> completer;
  final DateTime timestamp;

  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 5;
}

/// Servicio consolidado de monitoreo y optimización
class MonitoringService {
  MonitoringService._();

  static final MonitoringService _instance = MonitoringService._();
  static MonitoringService get instance => _instance;

  // === Performance Monitoring ===
  final Map<String, ProviderMetrics> _metrics = {};

  // === Request Deduplication ===
  final Map<String, InFlightRequest> _inFlightRequests = {};
  Timer? _cleanupTimer;

  /// Inicializar servicio
  void initialize() {
    // Limpiar requests expirados cada 2 minutos
    _cleanupTimer = Timer.periodic(const Duration(minutes: 2), (final _) {
      _cleanupExpiredRequests();
    });
    AILogger.d('[MonitoringService] Inicializado');
  }

  /// Agregar medición de performance
  void recordPerformance({
    required final String providerId,
    required final int responseTimeMs,
    required final bool success,
    final String? errorType,
  }) {
    final metrics =
        _metrics.putIfAbsent(providerId, () => ProviderMetrics(providerId));
    metrics.addMeasurement(
        responseTimeMs: responseTimeMs, success: success, errorType: errorType);
  }

  /// Obtener métricas de un provider
  ProviderMetrics? getMetrics(final String providerId) => _metrics[providerId];

  /// Obtener métricas de todos los providers
  Map<String, ProviderMetrics> getAllMetrics() => Map.unmodifiable(_metrics);

  /// Crear huella dactilar de request
  RequestFingerprint createFingerprint({
    required final String providerId,
    required final String model,
    required final String capability,
    required final List<AISystemPrompt> messages,
    final Map<String, dynamic>? parameters,
  }) {
    final content = {
      'provider': providerId,
      'model': model,
      'capability': capability,
      'messages': messages
          .map((final m) =>
              {'context': m.context.toString(), 'instructions': m.instructions})
          .toList(),
      if (parameters != null) 'params': parameters,
    };

    final jsonString = jsonEncode(content);
    final hash = jsonString.hashCode.abs().toString();

    return RequestFingerprint(
      hash: hash,
      providerId: providerId,
      model: model,
      capability: capability,
      metadata: {'created': DateTime.now().toIso8601String()},
    );
  }

  /// Verificar si request está en vuelo
  Future<AIResponse?> checkDuplicateRequest(
      final RequestFingerprint fingerprint) async {
    final inFlight = _inFlightRequests[fingerprint.hash];

    if (inFlight != null) {
      if (inFlight.isExpired) {
        _inFlightRequests.remove(fingerprint.hash);
        return null;
      }

      AILogger.d(
          '[MonitoringService] Request duplicado encontrado: ${fingerprint.hash}');
      return await inFlight.completer.future;
    }

    return null;
  }

  /// Registrar request en vuelo
  Completer<AIResponse> registerInFlightRequest(
      final RequestFingerprint fingerprint) {
    final completer = Completer<AIResponse>();
    _inFlightRequests[fingerprint.hash] =
        InFlightRequest(completer, DateTime.now());
    return completer;
  }

  /// Completar request en vuelo
  void completeInFlightRequest(
      final RequestFingerprint fingerprint, final AIResponse response) {
    final inFlight = _inFlightRequests.remove(fingerprint.hash);
    if (inFlight != null && !inFlight.completer.isCompleted) {
      inFlight.completer.complete(response);
    }
  }

  /// Limpiar requests expirados
  void _cleanupExpiredRequests() {
    final expired = <String>[];

    for (final entry in _inFlightRequests.entries) {
      if (entry.value.isExpired) {
        expired.add(entry.key);
      }
    }

    for (final key in expired) {
      final inFlight = _inFlightRequests.remove(key);
      if (inFlight != null && !inFlight.completer.isCompleted) {
        inFlight.completer.completeError(
            TimeoutException('Request expired', const Duration(minutes: 5)));
      }
    }

    if (expired.isNotEmpty) {
      AILogger.d(
          '[MonitoringService] Limpiados ${expired.length} requests expirados');
    }
  }

  /// Estadísticas globales
  Map<String, dynamic> getGlobalStats() {
    return {
      'total_providers': _metrics.length,
      'in_flight_requests': _inFlightRequests.length,
      'metrics_by_provider': _metrics.map(
        (final k, final v) => MapEntry(k, {
          'total_requests': v.totalRequests,
          'success_rate': v.successRate,
          'avg_response_time': v.averageResponseTime,
          'last_request': v.lastRequestTime?.toIso8601String(),
        }),
      ),
    };
  }

  /// Limpiar recursos
  void dispose() {
    _cleanupTimer?.cancel();
    _metrics.clear();

    // Completar todos los requests pendientes con error
    for (final inFlight in _inFlightRequests.values) {
      if (!inFlight.completer.isCompleted) {
        inFlight.completer.completeError(Exception('Service disposed'));
      }
    }
    _inFlightRequests.clear();

    AILogger.d('[MonitoringService] Disposed');
  }
}

/// Backward compatibility wrappers
class PerformanceMonitoringService {
  PerformanceMonitoringService._();
  static final PerformanceMonitoringService instance =
      PerformanceMonitoringService._();

  void recordRequest({
    required final String providerId,
    required final int responseTimeMs,
    required final bool success,
    final String? errorType,
  }) =>
      MonitoringService.instance.recordPerformance(
        providerId: providerId,
        responseTimeMs: responseTimeMs,
        success: success,
        errorType: errorType,
      );

  ProviderMetrics? getProviderMetrics(final String providerId) =>
      MonitoringService.instance.getMetrics(providerId);
}

class RequestDeduplicationService {
  RequestDeduplicationService._();
  static final RequestDeduplicationService instance =
      RequestDeduplicationService._();

  RequestFingerprint createFingerprint({
    required final String providerId,
    required final String model,
    required final String capability,
    required final List<AISystemPrompt> messages,
    final Map<String, dynamic>? parameters,
  }) =>
      MonitoringService.instance.createFingerprint(
        providerId: providerId,
        model: model,
        capability: capability,
        messages: messages,
        parameters: parameters,
      );

  Future<AIResponse?> checkDuplicate(final RequestFingerprint fingerprint) =>
      MonitoringService.instance.checkDuplicateRequest(fingerprint);
}
