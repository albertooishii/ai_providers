/// High-performance HTTP Connection Pool implementation
///
/// Provides connection pooling, keep-alive, compression, and advanced
/// HTTP optimizations for AI provider requests.
library;

import 'dart:io';
import 'dart:async';
import 'dart:collection';
import '../utils/logger.dart';

/// Configuration for HTTP connection pool
class ConnectionPoolConfig {
  const ConnectionPoolConfig({
    this.maxConnectionsPerHost = 10,
    this.maxTotalConnections = 50,
    this.keepAliveTimeoutMs = 15000,
    this.maxIdleTimeMs = 30000,
    this.enableCompression = true,
    this.connectionTimeoutMs = 30000,
  });

  final int maxConnectionsPerHost;
  final int maxTotalConnections;
  final int keepAliveTimeoutMs;
  final int maxIdleTimeMs;
  final bool enableCompression;
  final int connectionTimeoutMs;
}

/// Connection statistics for monitoring
class ConnectionStats {
  const ConnectionStats({
    this.activeConnections = 0,
    this.idleConnections = 0,
    this.totalRequests = 0,
    this.cacheHits = 0,
    this.cacheMisses = 0,
    this.totalBytesTransferred = 0,
    this.averageResponseTimeMs = 0.0,
    this.averageReuseCount = 0.0,
    this.averageRequestTimeMs = 0.0,
  });

  final int activeConnections;
  final int idleConnections;
  final int totalRequests;
  final int cacheHits;
  final int cacheMisses;
  final int totalBytesTransferred;
  final double averageResponseTimeMs;
  final double averageReuseCount;
  final double averageRequestTimeMs;
}

/// Pooled HTTP Client wrapper with usage tracking
class _PooledHttpClient {
  _PooledHttpClient({
    required this.client,
    required this.host,
    required this.createdAt,
  })  : lastUsedAt = createdAt,
        usageCount = 0,
        isInUse = false;
  final HttpClient client;
  final String host;
  final DateTime createdAt;
  DateTime lastUsedAt;
  int usageCount;
  bool isInUse;

  bool get isIdle => !isInUse;

  Duration get idleTime => DateTime.now().difference(lastUsedAt);

  Duration get age => DateTime.now().difference(createdAt);

  void markUsed() {
    lastUsedAt = DateTime.now();
    usageCount++;
    isInUse = true;
  }

  void markReleased() {
    isInUse = false;
  }
}

/// Host-specific connection pool
class _HostPool {
  _HostPool(this.host, this.config);
  final String host;
  final Queue<_PooledHttpClient> availableClients = Queue<_PooledHttpClient>();
  final Set<_PooledHttpClient> activeClients = <_PooledHttpClient>{};
  final ConnectionPoolConfig config;

  int totalRequests = 0;
  int cacheHits = 0;
  int cacheMisses = 0;
  int totalBytesTransferred = 0;
  final List<int> requestTimes = <int>[];

  int get totalConnections => availableClients.length + activeClients.length;

  bool get canCreateNewConnection =>
      totalConnections < config.maxConnectionsPerHost;

  ConnectionStats get stats => ConnectionStats(
        activeConnections: activeClients.length,
        idleConnections: availableClients.length,
        totalRequests: totalRequests,
        cacheHits: cacheHits,
        cacheMisses: cacheMisses,
        averageReuseCount: _calculateAverageReuse(),
        totalBytesTransferred: totalBytesTransferred,
        averageRequestTimeMs: _calculateAverageRequestTime(),
      );

  double _calculateAverageReuse() {
    if (totalConnections == 0) return 0.0;
    final totalUsage = availableClients.fold<int>(
          0,
          (final sum, final client) => sum + client.usageCount,
        ) +
        activeClients.fold<int>(
          0,
          (final sum, final client) => sum + client.usageCount,
        );
    return totalUsage / totalConnections;
  }

  double _calculateAverageRequestTime() {
    if (requestTimes.isEmpty) return 0.0;
    final sum = requestTimes.fold<int>(
      0,
      (final sum, final time) => sum + time,
    );
    return sum / requestTimes.length;
  }

  void recordRequestTime(final int timeMs) {
    requestTimes.add(timeMs);
    // Keep only last 1000 request times for moving average
    if (requestTimes.length > 1000) {
      requestTimes.removeAt(0);
    }
  }
}

/// High-performance HTTP Connection Pool
class HttpConnectionPool {
  late ConnectionPoolConfig _config;
  final Map<String, _HostPool> _hostPools = <String, _HostPool>{};
  final Map<String, String> _defaultHeaders = <String, String>{};
  String? _proxyHost;
  int? _proxyPort;
  String? _proxyUsername;
  String? _proxyPassword;
  bool _compressionEnabled = true;
  bool _isInitialized = false;
  Timer? _cleanupTimer;

  Future<void> initialize(final ConnectionPoolConfig config) async {
    if (_isInitialized) {
      AILogger.i('Connection pool already initialized');
      return;
    }

    _config = config;
    _compressionEnabled = config.enableCompression;

    // Start periodic cleanup of idle connections
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (final _) => cleanupIdleConnections(),
    );

    _isInitialized = true;
    AILogger.i(
      'Initialized with config: '
      'maxPerHost=${config.maxConnectionsPerHost}, '
      'maxTotal=${config.maxTotalConnections}, '
      'keepAlive=${config.keepAliveTimeoutMs}ms',
    );
  }

  Future<HttpClient> getClient(final String host) async {
    if (!_isInitialized) {
      throw StateError('Connection pool not initialized');
    }

    final hostPool = _getOrCreateHostPool(host);
    final stopwatch = Stopwatch()..start();

    try {
      // Try to reuse existing idle connection
      if (hostPool.availableClients.isNotEmpty) {
        final pooledClient = hostPool.availableClients.removeFirst();
        pooledClient.markUsed();
        hostPool.activeClients.add(pooledClient);
        hostPool.cacheHits++;
        hostPool.totalRequests++;

        AILogger.d(
          'Reused connection for $host (usage: ${pooledClient.usageCount})',
        );
        return pooledClient.client;
      }

      // Create new connection if within limits
      if (hostPool.canCreateNewConnection &&
          _getTotalConnections() < _config.maxTotalConnections) {
        final client = await _createOptimizedClient(host);
        final pooledClient = _PooledHttpClient(
          client: client,
          host: host,
          createdAt: DateTime.now(),
        );

        pooledClient.markUsed();
        hostPool.activeClients.add(pooledClient);
        hostPool.cacheMisses++;
        hostPool.totalRequests++;

        AILogger.d(
          'Created new connection for $host (total: ${_getTotalConnections()})',
        );
        return client;
      }

      // Connection limit reached - wait for available connection or create temporary
      AILogger.w(
        'Connection limit reached for $host, creating temporary client',
      );
      return await _createOptimizedClient(host);
    } finally {
      stopwatch.stop();
      hostPool.recordRequestTime(stopwatch.elapsedMilliseconds);
    }
  }

  Future<void> releaseClient(final String host, final HttpClient client) async {
    final hostPool = _hostPools[host];
    if (hostPool == null) return;

    // Find the pooled client
    final pooledClient = hostPool.activeClients.firstWhere(
      (final pc) => identical(pc.client, client),
      orElse: () => throw ArgumentError('Client not found in active pool'),
    );

    hostPool.activeClients.remove(pooledClient);
    pooledClient.markReleased();

    // Check if connection is still healthy and within age limits
    if (pooledClient.age.inMilliseconds < _config.keepAliveTimeoutMs) {
      hostPool.availableClients.add(pooledClient);
      AILogger.d('Released connection back to pool for $host');
    } else {
      pooledClient.client.close();
      AILogger.d('Closed aged connection for $host');
    }
  }

  ConnectionStats getStats() {
    int totalActive = 0;
    int totalIdle = 0;
    int totalRequests = 0;
    int totalCacheHits = 0;
    int totalCacheMisses = 0;
    int totalBytes = 0;
    double totalReuse = 0.0;
    double totalRequestTime = 0.0;

    for (final hostPool in _hostPools.values) {
      final stats = hostPool.stats;
      totalActive += stats.activeConnections;
      totalIdle += stats.idleConnections;
      totalRequests += stats.totalRequests;
      totalCacheHits += stats.cacheHits;
      totalCacheMisses += stats.cacheMisses;
      totalBytes += stats.totalBytesTransferred;
      totalReuse += stats.averageReuseCount;
      totalRequestTime += stats.averageRequestTimeMs;
    }

    final hostCount = _hostPools.length;
    return ConnectionStats(
      activeConnections: totalActive,
      idleConnections: totalIdle,
      totalRequests: totalRequests,
      cacheHits: totalCacheHits,
      cacheMisses: totalCacheMisses,
      averageReuseCount: hostCount > 0 ? totalReuse / hostCount : 0.0,
      totalBytesTransferred: totalBytes,
      averageRequestTimeMs: hostCount > 0 ? totalRequestTime / hostCount : 0.0,
    );
  }

  ConnectionStats getHostStats(final String host) {
    final hostPool = _hostPools[host];
    return hostPool?.stats ?? const ConnectionStats();
  }

  Future<void> cleanupIdleConnections() async {
    int closedConnections = 0;

    for (final hostPool in _hostPools.values) {
      final toRemove = <_PooledHttpClient>[];

      for (final pooledClient in hostPool.availableClients) {
        if (pooledClient.idleTime.inMilliseconds > _config.maxIdleTimeMs) {
          toRemove.add(pooledClient);
        }
      }

      for (final pooledClient in toRemove) {
        hostPool.availableClients.remove(pooledClient);
        pooledClient.client.close();
        closedConnections++;
      }
    }

    if (closedConnections > 0) {
      AILogger.i('Cleaned up $closedConnections idle connections');
    }
  }

  Future<void> shutdown() async {
    _cleanupTimer?.cancel();

    int totalClosed = 0;
    for (final hostPool in _hostPools.values) {
      // Close all available connections
      for (final pooledClient in hostPool.availableClients) {
        pooledClient.client.close();
        totalClosed++;
      }

      // Close all active connections
      for (final pooledClient in hostPool.activeClients) {
        pooledClient.client.close();
        totalClosed++;
      }
    }

    _hostPools.clear();
    _isInitialized = false;

    AILogger.i('Shutdown complete, closed $totalClosed connections');
  }

  void setCompressionEnabled(final bool enabled) {
    _compressionEnabled = enabled;
    AILogger.i('Compression ${enabled ? "enabled" : "disabled"}');
  }

  void setDefaultHeaders(final Map<String, String> headers) {
    _defaultHeaders.clear();
    _defaultHeaders.addAll(headers);
    AILogger.i('Set ${headers.length} default headers');
  }

  void setProxy(
    final String proxyHost,
    final int proxyPort, {
    final String? username,
    final String? password,
  }) {
    _proxyHost = proxyHost;
    _proxyPort = proxyPort;
    _proxyUsername = username;
    _proxyPassword = password;
    AILogger.i('Proxy configured: $proxyHost:$proxyPort');
  }

  // Private helper methods

  _HostPool _getOrCreateHostPool(final String host) {
    return _hostPools.putIfAbsent(host, () => _HostPool(host, _config));
  }

  int _getTotalConnections() {
    return _hostPools.values.fold<int>(
      0,
      (final sum, final pool) => sum + pool.totalConnections,
    );
  }

  Future<HttpClient> _createOptimizedClient(final String host) async {
    final client = HttpClient();

    // Configure timeouts
    client.connectionTimeout = Duration(
      milliseconds: _config.connectionTimeoutMs,
    );
    client.idleTimeout = Duration(milliseconds: _config.keepAliveTimeoutMs);

    // Enable compression if configured
    if (_compressionEnabled) {
      client.autoUncompress = true;
    }

    // Configure proxy if set
    if (_proxyHost != null && _proxyPort != null) {
      client.findProxy = (final uri) => 'PROXY $_proxyHost:$_proxyPort';

      if (_proxyUsername != null && _proxyPassword != null) {
        client.addProxyCredentials(
          _proxyHost!,
          _proxyPort!,
          '',
          HttpClientBasicCredentials(_proxyUsername!, _proxyPassword!),
        );
      }
    }

    // Set default headers
    client.userAgent = 'AI-Providers SDK/${DateTime.now().year}';

    return client;
  }
}
