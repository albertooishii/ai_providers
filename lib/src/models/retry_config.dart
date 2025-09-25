/// Configuración para el sistema de reintentos
class RetryConfig {
  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelayMs = 1000,
    this.initialDelayMs = 1000,
    this.maxDelayMs = 30000,
    this.delayMultiplier = 2.0,
    this.backoffMultiplier = 2.0,
    this.jitterFactor = 0.1,
    this.enableCircuitBreaker = true,
    this.retryOnNetworkError = true,
    this.retryOnTimeout = true,
    this.retryOnServerError = true,
    this.retryOnRateLimit = true,
    this.retryOnStatusCodes = const <int>[502, 503, 504],
  });

  final int maxAttempts;
  final int baseDelayMs;
  final int initialDelayMs;
  final int maxDelayMs;
  final double delayMultiplier;
  final double backoffMultiplier;
  final double jitterFactor;
  final bool enableCircuitBreaker;
  final bool retryOnNetworkError;
  final bool retryOnTimeout;
  final bool retryOnServerError;
  final bool retryOnRateLimit;
  final List<int> retryOnStatusCodes;

  @override
  String toString() =>
      'RetryConfig(maxAttempts: $maxAttempts, baseDelayMs: $baseDelayMs)';
}

/// Configuración para Circuit Breaker
class CircuitBreakerConfig {
  const CircuitBreakerConfig({
    required this.failureThreshold,
    required this.successThreshold,
    required this.timeoutMs,
    required this.recoveryTimeoutMs,
    required this.failureWindowMs,
    required this.halfOpenMaxCalls,
    required this.halfOpenRequestPercent,
    this.immediateSuccesses = 3,
  });

  final int failureThreshold;
  final int successThreshold;
  final int timeoutMs;
  final int recoveryTimeoutMs;
  final int failureWindowMs;
  final int halfOpenMaxCalls;
  final double halfOpenRequestPercent;
  final int immediateSuccesses;

  @override
  String toString() =>
      'CircuitBreakerConfig(failureThreshold: $failureThreshold)';
}

/// Estados del Circuit Breaker
enum CircuitBreakerState { closed, open, halfOpen }

/// Estado del Circuit Breaker
class CircuitBreakerStatus {
  const CircuitBreakerStatus({
    required this.state,
    required this.failureCount,
    required this.successCount,
    this.lastFailureTime,
    this.openedAt,
    this.halfOpenAt,
    this.nextRetryAt,
  });

  final CircuitBreakerState state;
  final int failureCount;
  final int successCount;
  final DateTime? lastFailureTime;
  final DateTime? openedAt;
  final DateTime? halfOpenAt;
  final DateTime? nextRetryAt;

  @override
  String toString() =>
      'CircuitBreakerStatus(state: $state, failures: $failureCount)';
}

/// Información sobre un intento de reintento
class RetryAttempt {
  const RetryAttempt({
    required this.attempt,
    required this.maxAttempts,
    required this.delayMs,
    required this.totalElapsed,
    this.previousError,
    this.nextRetryAt,
    this.isFinalAttempt = false,
  });

  final int attempt;
  final int maxAttempts;
  final int delayMs;
  final Duration totalElapsed;
  final Exception? previousError;
  final DateTime? nextRetryAt;
  final bool isFinalAttempt;

  @override
  String toString() =>
      'RetryAttempt(attempt: $attempt/$maxAttempts, delay: ${delayMs}ms)';
}

/// Estadísticas de reintentos
class RetryStats {
  const RetryStats({
    required this.immediateSuccesses,
    required this.totalFailures,
    required this.averageAttempts,
    required this.eventualSuccessRate,
    required this.circuitBreakerTrips,
  });

  final int immediateSuccesses;
  final int totalFailures;
  final double averageAttempts;
  final double eventualSuccessRate;
  final int circuitBreakerTrips;

  @override
  String toString() =>
      'RetryStats(successes: $immediateSuccesses, failures: $totalFailures, trips: $circuitBreakerTrips)';
}

/// Estadísticas complejas del sistema de reintentos
class CompleteRetryStats {
  const CompleteRetryStats({
    required this.totalOperations,
    required this.immediateSuccesses,
    required this.eventualSuccesses,
    required this.totalFailures,
    required this.totalRetryAttempts,
    required this.averageAttempts,
    required this.eventualSuccessRate,
    required this.circuitBreakerTrips,
    required this.circuitBreakerStates,
  });

  final int totalOperations;
  final int immediateSuccesses;
  final int eventualSuccesses;
  final int totalFailures;
  final int totalRetryAttempts;
  final double averageAttempts;
  final double eventualSuccessRate;
  final int circuitBreakerTrips;
  final Map<String, CircuitBreakerStatus> circuitBreakerStates;

  @override
  String toString() =>
      'CompleteRetryStats(operations: $totalOperations, retries: $totalRetryAttempts)';
}
