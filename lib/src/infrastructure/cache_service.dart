/// Complete cache system for AI providers - In-memory + Persistent cache
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import '../utils/logger.dart';
import '../models/ai_response.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Cache configuration
class CacheConfig {
  const CacheConfig({this.maxSize = 1000, this.ttlMinutes = 30});

  final int maxSize;
  final int ttlMinutes;
}

/// Cache entry with TTL
class CacheEntry<T> {
  CacheEntry(this.value, this.timestamp);

  final T value;
  final DateTime timestamp;

  bool isExpired(final Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }
}

/// Cache key for requests
class CacheKey {
  const CacheKey({required this.providerId, required this.prompt, this.model});

  final String providerId;
  final String prompt;
  final String? model;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is CacheKey &&
          runtimeType == other.runtimeType &&
          providerId == other.providerId &&
          prompt == other.prompt &&
          model == other.model;

  @override
  int get hashCode =>
      providerId.hashCode ^ prompt.hashCode ^ (model?.hashCode ?? 0);

  @override
  String toString() => 'CacheKey($providerId, $prompt, $model)';
}

/// Simplified in-memory cache service
class InMemoryCacheService {
  InMemoryCacheService([final CacheConfig? config])
      : _config = config ?? const CacheConfig() {
    _startCleanupTimer();
  }

  final CacheConfig _config;
  final LinkedHashMap<String, CacheEntry<AIResponse>> _cache = LinkedHashMap();
  Timer? _cleanupTimer;

  /// Get cached response
  Future<AIResponse?> get(final CacheKey key) async {
    final keyStr = key.toString();
    final entry = _cache[keyStr];

    if (entry == null) return null;

    if (entry.isExpired(Duration(minutes: _config.ttlMinutes))) {
      _cache.remove(keyStr);
      return null;
    }

    // Move to end (LRU)
    _cache.remove(keyStr);
    _cache[keyStr] = entry;

    return entry.value;
  }

  /// Set cached response
  Future<void> set(final CacheKey key, final AIResponse response) async {
    final keyStr = key.toString();

    // Remove if exists
    _cache.remove(keyStr);

    // Add to end
    _cache[keyStr] = CacheEntry(response, DateTime.now());

    // Evict if over limit
    while (_cache.length > _config.maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Clear cache
  void clear() {
    _cache.clear();
    AILogger.i('Cache cleared');
  }

  /// Get cache size
  int get size => _cache.length;

  /// Start cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (final _) {
      _cleanupExpired();
    });
  }

  /// Clean up expired entries
  void _cleanupExpired() {
    final ttl = Duration(minutes: _config.ttlMinutes);
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired(ttl)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      AILogger.d('Cleaned up ${keysToRemove.length} expired cache entries');
    }
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}

// ============================================================
// Persistent Cache Service - Consolidated functionality
// ============================================================

/// Complete cache service with both in-memory and persistent capabilities
class CompleteCacheService {
  CompleteCacheService._();
  static final CompleteCacheService _instance = CompleteCacheService._();
  static CompleteCacheService get instance => _instance;

  // In-memory cache for AI responses
  InMemoryCacheService? _memoryCache;

  // ============================================================
  // Cache Management Business Logic
  // ============================================================

  /// Business rule for cache directory structure
  static String _getAudioSubdirectory() => 'audio';
  static String _getVoicesSubdirectory() => 'voices';
  static String _getModelsSubdirectory() => 'models';

  /// Business rule for cache expiration policy
  static Duration _getCacheExpirationDuration() => const Duration(days: 7);

  /// Business rule for determining if cache is expired
  static bool _isCacheExpired(
      {required final int cacheTimestamp,
      required final int currentTimestamp}) {
    final cacheAge = currentTimestamp - cacheTimestamp;
    final maxAge = _getCacheExpirationDuration().inMilliseconds;
    return cacheAge > maxAge;
  }

  /// Business rule for TTS hash generation strategy
  /// Incluye audioFormat para evitar colisiones entre formatos (M4A vs MP3)
  static String _generateTtsIdentifier({
    required final String text,
    required final String voice,
    required final String languageCode,
    required final String provider,
    required final double speakingRate,
    required final double pitch,
    final String audioFormat = 'm4a',
  }) {
    return '$provider:$voice:$languageCode:$speakingRate:$pitch:$audioFormat:$text';
  }

  /// Business rule for default audio file extension
  static String _getDefaultAudioExtension() => 'mp3';

  /// Business rule for cache key generation
  static String _generateCacheKey(
      {required final String provider, required final String type}) {
    return '${provider}_${type}_cache.json';
  }

  // ============================================================
  // Initialization
  // ============================================================

  /// Initialize cache service with memory cache
  void initialize({final CacheConfig? config}) {
    _memoryCache = InMemoryCacheService(config);
    AILogger.d('[CompleteCacheService] Initialized with memory cache');
  }

  /// Get memory cache for AI responses
  InMemoryCacheService? get memoryCache => _memoryCache;

  // ============================================================
  // Directory Management
  // ============================================================

  /// Internal cache directory resolver - portable implementation
  Future<Directory> _getLocalCacheDir() async {
    if (kIsWeb) {
      return Directory('ai_providers_cache');
    }

    // Prefer tmp directory for cache-like ephemeral files, but place cache
    // inside a dedicated subfolder so files don't get mixed with other tmp
    // data (e.g. /tmp/ai_providers_cache).
    try {
      final tmp = await getTemporaryDirectory();
      final cacheDir =
          Directory('${tmp.path}${Platform.pathSeparator}ai_providers_cache');
      if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
      return cacheDir;
    } on Exception {
      // In tests, path_provider plugin may not be available.
      // Create a fallback directory in system temp.
      if (kDebugMode) {
        try {
          final systemTmp = Directory.systemTemp;
          final cacheDir = Directory(
              '${systemTmp.path}${Platform.pathSeparator}ai_providers_cache_fallback');
          if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
          return cacheDir;
        } on Exception catch (_) {
          // Last resort fallback
        }
      }

      // Fallback to application support directory if tmp not available
      final support = await getApplicationSupportDirectory();
      final cacheDir = Directory(
          '${support.path}${Platform.pathSeparator}ai_providers_cache');
      if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
      return cacheDir;
    }
  }

  /// Obtiene el directorio de caché base
  Future<Directory> getCacheDirectory() async {
    try {
      return await _getLocalCacheDir();
    } on Exception catch (e) {
      AILogger.e('Error getting local cache directory: $e');
      // Fallback to application support directory
      return await getApplicationSupportDirectory();
    }
  }

  /// Obtiene el directorio de caché de audio
  Future<Directory> getAudioCacheDirectory() async {
    final cacheDir = await getCacheDirectory();
    final audioDir = Directory('${cacheDir.path}/${_getAudioSubdirectory()}');
    if (!audioDir.existsSync()) {
      audioDir.createSync(recursive: true);
    }
    return audioDir;
  }

  /// Obtiene el directorio de caché de voces
  Future<Directory> getVoicesCacheDirectory() async {
    final cacheDir = await getCacheDirectory();
    final voicesDir = Directory('${cacheDir.path}/${_getVoicesSubdirectory()}');
    if (!voicesDir.existsSync()) {
      voicesDir.createSync(recursive: true);
    }
    return voicesDir;
  }

  // ============================================================
  // TTS Cache (Persistent Audio Files)
  // ============================================================

  /// Genera un hash único para el texto y configuración TTS
  /// Incluye audioFormat para diferenciación M4A vs MP3
  String generateTtsHash({
    required final String text,
    required final String voice,
    required final String languageCode,
    required final String provider,
    final double speakingRate = 1.0,
    final double pitch = 0.0,
    final String audioFormat = 'm4a',
  }) {
    // Use Domain Service to generate identifier
    final input = _generateTtsIdentifier(
      text: text,
      voice: voice,
      languageCode: languageCode,
      provider: provider,
      speakingRate: speakingRate,
      pitch: pitch,
      audioFormat: audioFormat,
    );

    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Obtiene archivo de audio cacheado
  /// Incluye audioFormat en la búsqueda para diferenciación correcta
  Future<File?> getCachedAudioFile({
    required final String text,
    required final String voice,
    required final String languageCode,
    required final String provider,
    final double speakingRate = 1.0,
    final double pitch = 0.0,
    final String? extension,
    final String audioFormat = 'm4a',
  }) async {
    try {
      final hash = generateTtsHash(
        text: text,
        voice: voice,
        languageCode: languageCode,
        provider: provider,
        speakingRate: speakingRate,
        pitch: pitch,
        audioFormat: audioFormat,
      );

      final audioDir = await getAudioCacheDirectory();
      final ext = (extension != null && extension.trim().isNotEmpty)
          ? extension.trim().replaceAll('.', '')
          : _getDefaultAudioExtension();
      final cachedFile = File('${audioDir.path}/$hash.$ext');

      if (cachedFile.existsSync()) {
        try {
          final len = await cachedFile.length();
          if (len > 0) {
            AILogger.d(
                '[Cache] Audio encontrado en caché: ${cachedFile.path} (size=$len)');
            return cachedFile;
          } else {
            // Remove zero-length files to avoid playback errors
            AILogger.d(
                '[Cache] Found zero-length cached audio, deleting: ${cachedFile.path}');
            try {
              await cachedFile.delete();
            } on Exception catch (_) {}
          }
        } on Exception catch (e) {
          AILogger.e('[Cache] Error checking cached file length: $e');
          return null;
        }
      }
    } on Exception catch (e) {
      AILogger.e('[Cache] Error obteniendo audio cacheado: $e');
    }
    return null;
  }

  // ============================================================
  // Models Cache (Persistent JSON)
  // ============================================================

  /// Guarda lista de modelos en caché
  Future<void> saveModelsToCache(
      {required final List<String> models,
      required final String provider}) async {
    try {
      final cacheDir = await getCacheDirectory();
      final modelsDir =
          Directory('${cacheDir.path}/${_getModelsSubdirectory()}');
      if (!modelsDir.existsSync()) modelsDir.createSync(recursive: true);
      final cacheFile = File(
          '${modelsDir.path}/${_generateCacheKey(provider: provider, type: 'models')}');

      final cacheData = {
        'provider': provider,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'models': models
      };

      await cacheFile.writeAsString(jsonEncode(cacheData));
      AILogger.d(
          '[Cache] Modelos $provider guardados en caché: ${models.length} modelos');
    } on Exception catch (e) {
      AILogger.e('[Cache] Error guardando modelos en caché: $e');
    }
  }

  /// Obtiene lista de modelos desde caché por proveedor
  Future<List<String>?> getCachedModels(
      {required final String provider, final bool forceRefresh = false}) async {
    if (forceRefresh) return null;

    try {
      final cacheDir = await getCacheDirectory();
      final modelsDir =
          Directory('${cacheDir.path}/${_getModelsSubdirectory()}');
      final cacheFile = File(
          '${modelsDir.path}/${_generateCacheKey(provider: provider, type: 'models')}');

      if (!cacheFile.existsSync()) return null;

      final raw = await cacheFile.readAsString();
      final cached = jsonDecode(raw) as Map<String, dynamic>;

      // Use Domain Service to validate cache expiration
      final timestamp = cached['timestamp'] as int?;
      if (timestamp != null) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        if (_isCacheExpired(
            cacheTimestamp: timestamp, currentTimestamp: currentTime)) {
          final cacheAge = currentTime - timestamp;
          debugPrint(
              '[Cache] Caché de modelos $provider expirado (${cacheAge ~/ (24 * 60 * 60 * 1000)} días)');
          return null;
        }
      }

      final cachedModels = (cached['models'] as List<dynamic>?) ?? [];
      debugPrint(
          '[Cache] Modelos $provider cargados desde caché: ${cachedModels.length} modelos');

      return cachedModels.map((final m) => m.toString()).toList();
    } on Exception catch (e) {
      debugPrint('[Cache] Error leyendo modelos desde caché: $e');
      return null;
    }
  }

  /// Elimina todos los archivos de caché de modelos
  Future<int> clearAllModelsCache() async {
    int deletedFiles = 0;
    try {
      final cacheDir = await getCacheDirectory();
      final modelsDir =
          Directory('${cacheDir.path}/${_getModelsSubdirectory()}');
      if (!modelsDir.existsSync()) {
        return deletedFiles;
      }

      final entities = modelsDir.listSync();
      for (final entity in entities) {
        try {
          if (entity is File) {
            await entity.delete();
            deletedFiles++;
          } else if (entity is Directory) {
            deletedFiles += await _clearDirectoryRecursively(entity);
            await entity.delete(recursive: true);
          }
        } on Exception catch (e) {
          debugPrint('[Cache] Warning clearing models cache entry: $e');
        }
      }

      debugPrint(
          '[Cache] All models cache cleared ($deletedFiles files removed)');
      return deletedFiles;
    } on Exception catch (e) {
      debugPrint('[Cache] Error clearing all models cache: $e');
      return deletedFiles;
    }
  }

  Future<int> _clearDirectoryRecursively(final Directory dir) async {
    int deletedFiles = 0;
    if (!dir.existsSync()) return deletedFiles;

    final entities = dir.listSync();
    for (final entity in entities) {
      try {
        if (entity is File) {
          await entity.delete();
          deletedFiles++;
        } else if (entity is Directory) {
          deletedFiles += await _clearDirectoryRecursively(entity);
          await entity.delete(recursive: true);
        }
      } on Exception catch (e) {
        debugPrint('[Cache] Warning clearing directory entry: $e');
      }
    }
    return deletedFiles;
  }

  // ============================================================
  // Voices Cache (Persistent JSON)
  // ============================================================

  /// Obtiene lista de voces desde caché
  Future<List<Map<String, dynamic>>?> getCachedVoices({
    required final String provider,
    final bool forceRefresh = false,
  }) async {
    if (forceRefresh) return null;

    try {
      final voicesDir = await getVoicesCacheDirectory();
      final cacheFile = File('${voicesDir.path}/${provider}_voices_cache.json');

      if (!cacheFile.existsSync()) return null;

      final raw = await cacheFile.readAsString();
      final cached = jsonDecode(raw) as Map<String, dynamic>;

      // Use Domain Service to validate cache expiration
      final timestamp = cached['timestamp'] as int?;
      if (timestamp != null) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        if (_isCacheExpired(
            cacheTimestamp: timestamp, currentTimestamp: currentTime)) {
          final cacheAge = currentTime - timestamp;
          debugPrint(
              '[Cache] Caché de voces $provider expirado (${cacheAge ~/ (24 * 60 * 60 * 1000)} días)');
          return null;
        }
      }

      final cachedVoices = (cached['voices'] as List<dynamic>?) ?? [];
      debugPrint(
          '[Cache] Voces $provider cargadas desde caché: ${cachedVoices.length} voces');

      return cachedVoices
          .map((final v) => Map<String, dynamic>.from(v))
          .toList();
    } on Exception catch (e) {
      debugPrint('[Cache] Error leyendo voces desde caché: $e');
      return null;
    }
  }

  /// Dispose all cache resources
  void dispose() {
    _memoryCache?.dispose();
    _memoryCache = null;
  }
}
