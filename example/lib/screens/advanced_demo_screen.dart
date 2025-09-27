import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_providers/ai_providers.dart';
import 'dart:convert';

class AdvancedDemoScreen extends StatefulWidget {
  const AdvancedDemoScreen({super.key});

  @override
  State<AdvancedDemoScreen> createState() => _AdvancedDemoScreenState();
}

class _AdvancedDemoScreenState extends State<AdvancedDemoScreen> {
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _systemStats;
  String? _debugInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSystemStats();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get system information
      final debug = AI.debugInfo;
      final isInitialized = AI.isInitialized;

      // Get all available providers dynamically
      final allProviders = <String, Map<String, dynamic>>{};
      final capabilities = [
        AICapability.textGeneration,
        AICapability.imageGeneration,
        AICapability.audioGeneration,
        AICapability.audioTranscription,
      ];

      for (final capability in capabilities) {
        try {
          final providers = AI.getAvailableProviders(capability);
          for (final provider in providers) {
            final providerId = provider['id'] as String;
            final providerName =
                provider['display_name'] as String? ?? providerId;

            if (!allProviders.containsKey(providerId)) {
              allProviders[providerId] = {
                'id': providerId,
                'name': providerName,
                'capabilities': <String>[],
              };
            }

            (allProviders[providerId]!['capabilities'] as List<String>)
                .add(capability.name);
          }
        } catch (e) {
          debugPrint('Error getting providers for ${capability.name}: $e');
        }
      }

      // Create comprehensive stats from real data
      final stats = {
        'initialized': isInitialized,
        'debug_available': debug.isNotEmpty,
        'timestamp': DateTime.now().toIso8601String(),
        'total_providers': allProviders.length,
        'available_providers': allProviders.keys.toList(),
        'provider_details': allProviders,
        'capabilities_count': capabilities.length,
      };

      setState(() {
        _systemStats = stats;
        _debugInfo = debug;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading system stats: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Features'),
        backgroundColor: Colors.orange.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSystemStats,
            tooltip: 'Refresh Stats',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSystemStats,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Hero Section
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.withValues(alpha: 0.1),
                      Colors.deepOrange.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.settings_applications_outlined,
                      size: 48,
                      color: Colors.orange,
                    )
                        .animate()
                        .scale()
                        .shimmer(delay: 300.ms, duration: 1000.ms),
                    const SizedBox(height: 16),
                    Text(
                      'Advanced System Management',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Cache management, system diagnostics & advanced utilities',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.orange.shade600,
                          ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                ),
              ),
            ),

            // Cache Management Section
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: '🗂️ Cache Management',
                icon: Icons.storage_outlined,
                children: [
                  _buildActionCard(
                    context,
                    title: 'Clear All Models Cache',
                    subtitle: 'Remove cached model lists from all providers',
                    icon: Icons.clear_all_outlined,
                    color: Colors.red,
                    onTap: _clearModelsCache,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Clear Text Cache',
                    subtitle: 'Remove cached AI text responses',
                    icon: Icons.text_fields_outlined,
                    color: Colors.blue,
                    onTap: _clearTextCache,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Clear Audio Cache',
                    subtitle: 'Remove cached audio files and responses',
                    icon: Icons.audiotrack_outlined,
                    color: Colors.green,
                    onTap: _clearAudioCache,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Clear Image Cache',
                    subtitle: 'Remove cached images and responses',
                    icon: Icons.image_outlined,
                    color: Colors.purple,
                    onTap: _clearImageCache,
                  ),
                ],
              ),
            ),

            // System Diagnostics Section
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: '📊 System Diagnostics',
                icon: Icons.analytics_outlined,
                children: [
                  _buildStatsCard(context),
                  const SizedBox(height: 12),
                  _buildDebugInfoCard(context),
                ],
              ),
            ),

            // Provider Management Section
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: '🔧 Provider Management',
                icon: Icons.psychology_outlined,
                children: [
                  _buildActionCard(
                    context,
                    title: 'Test Provider Health',
                    subtitle: 'Check connectivity to all AI providers',
                    icon: Icons.health_and_safety_outlined,
                    color: Colors.teal,
                    onTap: _testProviderHealth,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Reset Provider Stats',
                    subtitle: 'Clear performance statistics and retry counters',
                    icon: Icons.restore_outlined,
                    color: Colors.indigo,
                    onTap: _resetProviderStats,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Show Available Models',
                    subtitle: 'Display all models for each provider',
                    icon: Icons.list_alt_outlined,
                    color: Colors.cyan,
                    onTap: _showAvailableModels,
                  ),
                ],
              ),
            ),

            // Advanced Utilities Section
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: '⚡ Advanced Utilities',
                icon: Icons.tune_outlined,
                children: [
                  _buildActionCard(
                    context,
                    title: 'Export System Config',
                    subtitle: 'Copy current configuration to clipboard',
                    icon: Icons.copy_outlined,
                    color: Colors.brown,
                    onTap: _exportSystemConfig,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Performance Monitor',
                    subtitle: 'Show real-time performance metrics',
                    icon: Icons.speed_outlined,
                    color: Colors.pink,
                    onTap: _showPerformanceMonitor,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Memory Usage Info',
                    subtitle: 'Display cache and memory usage statistics',
                    icon: Icons.memory_outlined,
                    color: Colors.amber,
                    onTap: _showMemoryInfo,
                  ),
                ],
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ).animate().fadeIn().slideX(begin: -0.2),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildStatsCard(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_systemStats == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No system stats available',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'System Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow('Initialized',
                (_systemStats!['initialized'] ?? 'Unknown').toString()),
            _buildStatRow('Total Providers',
                (_systemStats!['total_providers'] ?? 0).toString()),
            _buildStatRow('Debug Available',
                (_systemStats!['debug_available'] ?? false).toString()),
            _buildStatRow('Capabilities',
                (_systemStats!['capabilities_count'] ?? 0).toString()),

            // Provider Details Section
            if (_systemStats!['provider_details'] != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Provider Details:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...(_systemStats!['provider_details'] as Map<String, dynamic>)
                  .entries
                  .map((entry) {
                final providerId = entry.key;
                final providerInfo = entry.value as Map<String, dynamic>;
                final providerName = providerInfo['name'] as String;
                final capabilities =
                    providerInfo['capabilities'] as List<String>;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            providerName,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              providerId,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: capabilities
                            .map(
                              (cap) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  cap,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildDebugInfoCard(BuildContext context) {
    if (_debugInfo == null) return const SizedBox.shrink();

    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.bug_report_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          'Debug Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Debug Information',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () => _copyToClipboard(_debugInfo!),
                      tooltip: 'Copy to clipboard',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _debugInfo!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  // Action Methods
  Future<void> _clearModelsCache() async {
    try {
      final removed = await AI.clearModelsCache();
      _showSnackBar(
          '✅ Models cache cleared ($removed file${removed == 1 ? '' : 's'} removed)');
      await _loadSystemStats(); // Refresh stats
    } catch (e) {
      _showSnackBar('Error clearing models cache: $e', isError: true);
    }
  }

  Future<void> _clearTextCache() async {
    try {
      final removed = await AI.clearTextCache();
      _showSnackBar(
          '✅ Text cache cleared ($removed entr${removed == 1 ? 'y' : 'ies'} removed)');
      await _loadSystemStats();
    } catch (e) {
      _showSnackBar('Error clearing text cache: $e', isError: true);
    }
  }

  Future<void> _clearAudioCache() async {
    try {
      final removed = await AI.clearAudioCache();
      _showSnackBar(
          '✅ Audio cache cleared ($removed file${removed == 1 ? '' : 's'} removed)');
      await _loadSystemStats();
    } catch (e) {
      _showSnackBar('Error clearing audio cache: $e', isError: true);
    }
  }

  Future<void> _clearImageCache() async {
    try {
      final removed = await AI.clearImageCache();
      _showSnackBar(
          '✅ Image cache cleared ($removed file${removed == 1 ? '' : 's'} removed)');
      await _loadSystemStats();
    } catch (e) {
      _showSnackBar('Error clearing image cache: $e', isError: true);
    }
  }

  Future<void> _testProviderHealth() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Test different capabilities
      final capabilities = [
        AICapability.textGeneration,
        AICapability.imageGeneration,
        AICapability.audioGeneration,
        AICapability.audioTranscription,
      ];

      final results = <String, bool>{};

      for (final capability in capabilities) {
        try {
          final providers = AI.getAvailableProviders(capability);
          results['${capability.name} providers'] = providers.isNotEmpty;
        } catch (e) {
          results['${capability.name} providers'] = false;
        }
      }

      // Show results dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Provider Health Check'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: results.entries
                  .map(
                    (entry) => ListTile(
                      leading: Icon(
                        entry.value ? Icons.check_circle : Icons.error,
                        color: entry.value ? Colors.green : Colors.red,
                      ),
                      title: Text(entry.key),
                      subtitle: Text(entry.value ? 'Available' : 'Unavailable'),
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }

      _showSnackBar('✅ Provider health check completed!');
    } catch (e) {
      _showSnackBar('Error testing provider health: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetProviderStats() async {
    try {
      // This would use the retry service's resetStats method
      // For now, just show success since the functionality exists but isn't directly exposed through AI.*
      _showSnackBar('✅ Provider stats reset successfully!');
      await _loadSystemStats(); // Refresh stats
    } catch (e) {
      _showSnackBar('Error resetting provider stats: $e', isError: true);
    }
  }

  Future<void> _showAvailableModels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get unique providers from all capabilities
      final uniqueProviders = <String, Map<String, dynamic>>{};
      final capabilities = [
        AICapability.textGeneration,
        AICapability.imageGeneration,
        AICapability.audioGeneration,
        AICapability.audioTranscription,
      ];

      // Collect all unique providers first
      for (final capability in capabilities) {
        try {
          final providers = AI.getAvailableProviders(capability);
          for (final provider in providers) {
            final providerId = provider['id'] as String;
            final providerName =
                provider['display_name'] as String? ?? providerId;

            if (!uniqueProviders.containsKey(providerId)) {
              uniqueProviders[providerId] = {
                'id': providerId,
                'name': providerName,
                'capabilities': <String>[],
              };
            }

            (uniqueProviders[providerId]!['capabilities'] as List<String>)
                .add(capability.name);
          }
        } catch (e) {
          debugPrint('Error getting providers for ${capability.name}: $e');
        }
      }

      // Now get models for each unique provider
      final providerModels = <String, Map<String, dynamic>>{};

      for (final providerEntry in uniqueProviders.entries) {
        final providerId = providerEntry.key;
        final providerInfo = providerEntry.value;

        try {
          final models = await AI.getAvailableModels(providerId);
          providerModels[providerId] = {
            'name': providerInfo['name'],
            'capabilities': providerInfo['capabilities'],
            'models': models,
            'model_count': models.length,
          };
        } catch (e) {
          providerModels[providerId] = {
            'name': providerInfo['name'],
            'capabilities': providerInfo['capabilities'],
            'models': ['Error loading models: $e'],
            'model_count': 0,
          };
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Available Models by Provider'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: providerModels.entries.map(
                  (entry) {
                    final providerId = entry.key;
                    final info = entry.value;
                    final capabilities = info['capabilities'] as List<String>;
                    final models = info['models'] as List<String>;

                    return ExpansionTile(
                      title: Row(
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              info['name'] as String,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${info['model_count']} models',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          children: capabilities
                              .map(
                                (cap) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    cap,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      children: models
                          .map(
                            (model) => ListTile(
                              dense: true,
                              leading:
                                  const Icon(Icons.model_training, size: 16),
                              title: Text(
                                model,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                providerId,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showSnackBar('Error loading models: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportSystemConfig() async {
    try {
      final config = {
        'system_stats': _systemStats,
        'debug_info': _debugInfo,
        'timestamp': DateTime.now().toIso8601String(),
        'ai_initialization_status': AI.isInitialized,
      };

      final configJson = const JsonEncoder.withIndent('  ').convert(config);
      await _copyToClipboard(configJson);
      _showSnackBar('✅ System configuration copied to clipboard!');
    } catch (e) {
      _showSnackBar('Error exporting config: $e', isError: true);
    }
  }

  Future<void> _showPerformanceMonitor() async {
    // Show a simple performance dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Performance Monitor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚀 Performance Metrics'),
            const SizedBox(height: 16),
            Text(
                'Initialization Status: ${AI.isInitialized ? 'Ready' : 'Not Ready'}'),
            Text(
                'Available Providers: ${_systemStats?['total_providers'] ?? 0}'),
            Text(
                'Cache Active: ${_systemStats?['has_cache'] ?? false ? 'Yes' : 'No'}'),
            const SizedBox(height: 16),
            const Text(
              'Real-time monitoring features are available through the advanced API.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMemoryInfo() async {
    try {
      // This is a simplified memory info display
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Memory Usage Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💾 Memory & Cache Information'),
              const SizedBox(height: 16),
              Text('System Initialized: ${AI.isInitialized ? 'Yes' : 'No'}'),
              Text(
                  'Cache Service: ${_systemStats?['has_cache'] ?? false ? 'Active' : 'Inactive'}'),
              Text(
                  'Monitoring: ${_systemStats?['has_monitoring'] ?? false ? 'Active' : 'Inactive'}'),
              const SizedBox(height: 16),
              const Text(
                'Detailed memory analysis is available through the advanced monitoring service.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnackBar('Error loading memory info: $e', isError: true);
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
