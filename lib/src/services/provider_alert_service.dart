/// Simplified Provider Alert Service for monitoring AI providers
library;

import 'dart:async';
import '../utils/logger.dart';

/// Alert threshold configuration
class AlertThresholds {
  const AlertThresholds({
    this.errorRateThreshold = 0.1,
    this.responseTimeThreshold = 5000.0,
    this.consecutiveFailureThreshold = 3,
    this.healthCheckInterval = const Duration(minutes: 1),
    this.alertCooldown = const Duration(minutes: 5),
  });

  final double errorRateThreshold;
  final double responseTimeThreshold;
  final int consecutiveFailureThreshold;
  final Duration healthCheckInterval;
  final Duration alertCooldown;
}

/// Simplified alert service
class ProviderAlertService {
  late AlertThresholds _thresholds;
  bool _initialized = false;

  /// Initialize the alert service
  Future<void> initialize(final AlertThresholds thresholds) async {
    if (_initialized) {
      AILogger.i('Alert service already initialized');
      return;
    }

    _thresholds = thresholds;
    _initialized = true;
    AILogger.i('Alert service initialized');
  }

  /// Record a provider error
  void recordError(final String providerId, final String error) {
    if (!_initialized) return;
    AILogger.w('Provider error recorded for $providerId: $error');
  }

  /// Record response time
  void recordResponseTime(
    final String providerId,
    final double responseTimeMs,
  ) {
    if (!_initialized) return;
    if (responseTimeMs > _thresholds.responseTimeThreshold) {
      AILogger.w('Slow response from $providerId: ${responseTimeMs}ms');
    }
  }

  /// Check if provider is healthy
  bool isHealthy(final String providerId) {
    return _initialized;
  }

  /// Cleanup resources
  Future<void> dispose() async {
    _initialized = false;
    AILogger.i('Alert service disposed');
  }
}
