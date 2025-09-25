import 'package:flutter/foundation.dart';

/// Niveles de logging para ai_providers
enum LogLevel { off, error, warn, info, debug }

/// Sistema de logging interno para ai_providers
/// Configurable a través del archivo de configuración YAML
class AILogger {
  static LogLevel _level = kDebugMode ? LogLevel.debug : LogLevel.warn;
  static const String _prefix = '[AI_PROVIDERS]';

  /// Parsea un nivel de logging desde string
  static LogLevel _parseLevel(final String levelStr) {
    switch (levelStr.toLowerCase()) {
      case 'off':
        return LogLevel.off;
      case 'error':
        return LogLevel.error;
      case 'warn':
        return LogLevel.warn;
      case 'info':
        return LogLevel.info;
      case 'debug':
        return LogLevel.debug;
      default:
        return LogLevel.warn;
    }
  }

  /// Configura el logger desde la configuración YAML
  static void configure({required final String level}) {
    _level = _parseLevel(level);
  }

  /// Verifica si un nivel está habilitado
  static bool _isEnabled(final LogLevel level) {
    if (_level == LogLevel.off) return false;
    return level.index <= _level.index;
  }

  /// Log de debug (información de desarrollo)
  static void d(final String message, {final String? tag}) {
    if (!_isEnabled(LogLevel.debug)) return;
    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('🔍 $_prefix$tagStr $message');
  }

  /// Log de información (eventos importantes)
  static void i(final String message, {final String? tag}) {
    if (!_isEnabled(LogLevel.info)) return;
    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('ℹ️ $_prefix$tagStr $message');
  }

  /// Log de advertencia (situaciones que requieren atención)
  static void w(final String message, {final String? tag}) {
    if (!_isEnabled(LogLevel.warn)) return;
    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('⚠️ $_prefix$tagStr $message');
  }

  /// Log de error (errores que requieren acción)
  static void e(
    final String message, {
    final String? tag,
    final Object? error,
    final StackTrace? stackTrace,
  }) {
    if (!_isEnabled(LogLevel.error)) return;
    final tagStr = tag != null ? '[$tag]' : '';
    final errorStr = error != null ? ' | Error: $error' : '';
    final stackStr = stackTrace != null ? '\n$stackTrace' : '';
    debugPrint('❌ $_prefix$tagStr $message$errorStr$stackStr');
  }

  /// Verifica si el logging está habilitado para debug
  static bool get isDebugEnabled => _isEnabled(LogLevel.debug);
}
