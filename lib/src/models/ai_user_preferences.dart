import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'ai_capability.dart';

/// Configuración robusta de usuario usando JSON en SharedPreferences
///
/// Este sistema reemplaza las keys concatenadas por una estructura JSON clara:
/// {
///   "text_generation": {
///     "provider": "openai",
///     "model": "gpt-4.1-mini",
///     "last_updated": "2025-09-27T..."
///   }
/// }
class AIUserPreferences {
  static const String _configKey = 'ai_provider_config_v2';

  /// Configuración para una capability específica
  static Future<CapabilityConfig?> getConfigForCapability(
      final AICapability capability) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);

      if (configJson == null) {
        AILogger.d('[AIUserPreferences] No configuration found');
        return null;
      }

      final config = jsonDecode(configJson) as Map<String, dynamic>;
      final capabilityData =
          config[capability.identifier] as Map<String, dynamic>?;

      if (capabilityData == null) {
        AILogger.d(
            '[AIUserPreferences] No config for capability ${capability.identifier}');
        return null;
      }

      final result = CapabilityConfig.fromMap(capabilityData);
      AILogger.d(
          '[AIUserPreferences] ✅ Loaded config for ${capability.identifier}: provider=${result.provider}, model=${result.model}${result.voice != null ? ', voice=${result.voice}' : ''}');
      return result;
    } on Exception catch (e) {
      AILogger.w(
          '[AIUserPreferences] Error reading config for ${capability.identifier}: $e');
      return null;
    }
  }

  /// Guarda configuración para una capability específica
  static Future<void> setConfigForCapability(
    final AICapability capability,
    final String provider,
    final String model, {
    final String? voice,
    final Map<String, dynamic>? additionalData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Leer configuración existente o crear nueva
      Map<String, dynamic> config = {};
      final existingJson = prefs.getString(_configKey);
      if (existingJson != null) {
        config = jsonDecode(existingJson) as Map<String, dynamic>;
      }

      // Actualizar configuración para esta capability
      config[capability.identifier] = {
        'provider': provider,
        'model': model,
        if (voice != null) 'voice': voice,
        'last_updated': DateTime.now().toIso8601String(),
        if (additionalData != null) ...additionalData,
      };

      // Guardar
      await prefs.setString(_configKey, jsonEncode(config));

      AILogger.i(
          '[AIUserPreferences] ✅ Saved config for ${capability.identifier}: provider=$provider, model=$model${voice != null ? ', voice=$voice' : ''}');
    } on Exception catch (e) {
      AILogger.e(
          '[AIUserPreferences] ❌ Error saving config for ${capability.identifier}: $e');
      rethrow;
    }
  }

  /// Obtiene toda la configuración para debug
  static Future<Map<String, dynamic>> getAllConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);

      if (configJson == null) {
        return {};
      }

      return jsonDecode(configJson) as Map<String, dynamic>;
    } on Exception catch (e) {
      AILogger.w('[AIUserPreferences] Error reading full config: $e');
      return {};
    }
  }

  /// Limpia toda la configuración (útil para desarrollo)
  static Future<void> clearAllConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_configKey);
      AILogger.i('[AIUserPreferences] 🧹 Cleared all configuration');
    } on Exception catch (e) {
      AILogger.w('[AIUserPreferences] Error clearing config: $e');
    }
  }
}

/// Configuración de una capability específica
class CapabilityConfig {

  const CapabilityConfig({
    required this.provider,
    required this.model,
    this.voice,
    required this.lastUpdated,
    this.additionalData = const {},
  });

  factory CapabilityConfig.fromMap(final Map<String, dynamic> map) {
    return CapabilityConfig(
      provider: map['provider'] as String,
      model: map['model'] as String,
      voice: map['voice'] as String?,
      lastUpdated: DateTime.parse(map['last_updated'] as String),
      additionalData: Map<String, dynamic>.from(map)
        ..remove('provider')
        ..remove('model')
        ..remove('voice')
        ..remove('last_updated'),
    );
  }
  final String provider;
  final String model;
  final String? voice;
  final DateTime lastUpdated;
  final Map<String, dynamic> additionalData;

  Map<String, dynamic> toMap() {
    return {
      'provider': provider,
      'model': model,
      if (voice != null) 'voice': voice,
      'last_updated': lastUpdated.toIso8601String(),
      ...additionalData,
    };
  }

  @override
  String toString() {
    return 'CapabilityConfig(provider: $provider, model: $model, voice: $voice, lastUpdated: $lastUpdated)';
  }
}
