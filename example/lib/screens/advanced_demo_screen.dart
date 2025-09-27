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
      // Obtener información del sistema usando solo API AI.*
      final isInitialized = AI.isInitialized;
      final debugInfo = AI.debugInfo;

      // Obtener proveedores para cada capability
      final textProviders =
          AI.getAvailableProviders(AICapability.textGeneration);
      final imageProviders =
          AI.getAvailableProviders(AICapability.imageGeneration);
      final audioProviders =
          AI.getAvailableProviders(AICapability.audioGeneration);
      final transcriptionProviders =
          AI.getAvailableProviders(AICapability.audioTranscription);

      // Combinar todos los proveedores únicos
      final allProviders = <String, AIProvider>{};

      for (final providerList in [
        textProviders,
        imageProviders,
        audioProviders,
        transcriptionProviders
      ]) {
        for (final provider in providerList) {
          final providerId = provider.id;
          if (!allProviders.containsKey(providerId)) {
            allProviders[providerId] = provider;
          }
          // Note: AIProvider ya tiene todas las capabilities agregadas automáticamente
          // No necesitamos combinar capabilities manualmente
        }
      }

      // Obtener modelos actuales para cada capability
      final currentModels = <String, String?>{};
      for (final capability in AICapability.values) {
        try {
          currentModels[capability.name] = await AI.getCurrentModel(capability);
        } catch (e) {
          currentModels[capability.name] = null;
        }
      }

      setState(() {
        _systemStats = {
          'initialized': isInitialized,
          'timestamp': DateTime.now().toIso8601String(),
          'totalProviders': allProviders.length,
          'providerDetails': allProviders,
          'currentModels': currentModels,
          'debugInfo': debugInfo,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error cargando estadísticas: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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
        title: const Text('Gestión Avanzada'),
        backgroundColor: Colors.orange.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSystemStats,
            tooltip: 'Actualizar estadísticas',
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
                      Icons.admin_panel_settings_outlined,
                      size: 48,
                      color: Colors.orange,
                    )
                        .animate()
                        .scale()
                        .shimmer(delay: 300.ms, duration: 1000.ms),
                    const SizedBox(height: 16),
                    Text(
                      'Gestión del Sistema AI',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Administración de caché, modelos y configuración',
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
                title: '🗂️ Gestión de Caché',
                icon: Icons.storage_outlined,
                children: [
                  _buildActionCard(
                    context,
                    title: 'Limpiar Caché de Texto',
                    subtitle: 'Eliminar respuestas de texto en memoria',
                    icon: Icons.text_fields_outlined,
                    color: Colors.blue,
                    onTap: _clearTextCache,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Limpiar Caché de Audio',
                    subtitle: 'Eliminar archivos de audio guardados',
                    icon: Icons.audiotrack_outlined,
                    color: Colors.green,
                    onTap: _clearAudioCache,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Limpiar Caché de Imágenes',
                    subtitle: 'Eliminar imágenes generadas guardadas',
                    icon: Icons.image_outlined,
                    color: Colors.purple,
                    onTap: _clearImageCache,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Limpiar Caché de Modelos',
                    subtitle: 'Eliminar listas de modelos persistidas',
                    icon: Icons.model_training_outlined,
                    color: Colors.red,
                    onTap: _clearModelsCache,
                  ),
                ],
              ),
            ),

            // System Information Section
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: '📊 Información del Sistema',
                icon: Icons.info_outline,
                children: [
                  _buildSystemInfoCard(context),
                  const SizedBox(height: 12),
                  _buildProvidersCard(context),
                ],
              ),
            ),

            // Configuration Management Section
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: '⚙️ Gestión de Configuración',
                icon: Icons.settings_outlined,
                children: [
                  _buildActionCard(
                    context,
                    title: 'Ver Modelos Disponibles',
                    subtitle: 'Mostrar todos los modelos por proveedor',
                    icon: Icons.list_alt_outlined,
                    color: Colors.cyan,
                    onTap: _showAvailableModels,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Exportar Configuración',
                    subtitle: 'Copiar configuración actual al portapapeles',
                    icon: Icons.copy_outlined,
                    color: Colors.brown,
                    onTap: _exportSystemConfig,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    title: 'Información de Debug',
                    subtitle: 'Ver información detallada del sistema',
                    icon: Icons.bug_report_outlined,
                    color: Colors.amber,
                    onTap: _showDebugInfo,
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

  Widget _buildSystemInfoCard(BuildContext context) {
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
            'No hay estadísticas disponibles',
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
                  'Estado del Sistema',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow('Inicializado',
                (_systemStats!['initialized'] ?? false) ? '✅ Sí' : '❌ No'),
            _buildStatRow('Total Proveedores',
                (_systemStats!['totalProviders'] ?? 0).toString()),
            _buildStatRow('Última Actualización',
                _formatTimestamp(_systemStats!['timestamp'] as String?)),

            // Current Models Section
            if (_systemStats!['currentModels'] != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.model_training_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Modelos Actuales:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...(_systemStats!['currentModels'] as Map<String, dynamic>)
                  .entries
                  .map((entry) {
                final capability = entry.key;
                final model = entry.value as String?;
                return _buildStatRow(
                  _formatCapabilityName(capability),
                  model ?? 'No configurado',
                );
              }),
            ],
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildProvidersCard(BuildContext context) {
    if (_systemStats == null || _systemStats!['providerDetails'] == null) {
      return const SizedBox.shrink();
    }

    final providers = _systemStats!['providerDetails'] as Map<String, dynamic>;

    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.psychology_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          'Proveedores Disponibles (${providers.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        children: providers.entries.map((entry) {
          final providerId = entry.key;
          final providerInfo = entry.value as Map<String, dynamic>;
          final displayName = providerInfo['displayName'] as String;
          final description = providerInfo['description'] as String;
          final capabilities = providerInfo['capabilities'] as List<String>;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    Expanded(
                      child: Text(
                        displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        providerId,
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: capabilities
                      .map(
                        (capability) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatCapabilityName(capability),
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
        }).toList(),
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
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCapabilityName(String capability) {
    switch (capability) {
      case 'textGeneration':
        return 'Texto';
      case 'imageGeneration':
        return 'Imagen';
      case 'audioGeneration':
        return 'Audio TTS';
      case 'audioTranscription':
        return 'Audio STT';
      default:
        return capability;
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Desconocido';
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Hace unos segundos';
      } else if (difference.inHours < 1) {
        return 'Hace ${difference.inMinutes} min';
      } else if (difference.inDays < 1) {
        return 'Hace ${difference.inHours} h';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Formato inválido';
    }
  }

  // Action Methods
  Future<void> _clearTextCache() async {
    try {
      final removed = await AI.clearTextCache();
      _showSnackBar('✅ Caché de texto limpiado ($removed entradas eliminadas)');
      await _loadSystemStats();
    } catch (e) {
      _showSnackBar('Error limpiando caché de texto: $e', isError: true);
    }
  }

  Future<void> _clearAudioCache() async {
    try {
      final removed = await AI.clearAudioCache();
      _showSnackBar('✅ Caché de audio limpiado ($removed archivos eliminados)');
      await _loadSystemStats();
    } catch (e) {
      _showSnackBar('Error limpiando caché de audio: $e', isError: true);
    }
  }

  Future<void> _clearImageCache() async {
    try {
      final removed = await AI.clearImageCache();
      _showSnackBar(
          '✅ Caché de imágenes limpiado ($removed archivos eliminados)');
      await _loadSystemStats();
    } catch (e) {
      _showSnackBar('Error limpiando caché de imágenes: $e', isError: true);
    }
  }

  Future<void> _clearModelsCache() async {
    try {
      final removed = await AI.clearModelsCache();
      _showSnackBar(
          '✅ Caché de modelos limpiado ($removed archivos eliminados)');
      await _loadSystemStats();
    } catch (e) {
      _showSnackBar('Error limpiando caché de modelos: $e', isError: true);
    }
  }

  Future<void> _showAvailableModels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final providers =
          _systemStats!['providerDetails'] as Map<String, dynamic>;
      final providerModels = <String, Map<String, dynamic>>{};

      for (final entry in providers.entries) {
        final providerId = entry.key;
        final providerInfo = entry.value as Map<String, dynamic>;

        try {
          final models = await AI.getAvailableModels(providerId);
          providerModels[providerId] = {
            'displayName': providerInfo['displayName'],
            'models': models,
          };
        } catch (e) {
          providerModels[providerId] = {
            'displayName': providerInfo['displayName'],
            'models': ['Error: ${e.toString()}'],
          };
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Modelos Disponibles'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView(
                children: providerModels.entries.map((entry) {
                  final providerId = entry.key;
                  final info = entry.value;
                  final displayName = info['displayName'] as String;
                  final models = info['models'] as List<String>;

                  return ExpansionTile(
                    title: Text(displayName),
                    subtitle: Text('$providerId • ${models.length} modelos'),
                    children: models
                        .map((model) => ListTile(
                              dense: true,
                              title: Text(
                                model,
                                style: const TextStyle(fontSize: 12),
                              ),
                              leading:
                                  const Icon(Icons.model_training, size: 16),
                            ))
                        .toList(),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showSnackBar('Error cargando modelos: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportSystemConfig() async {
    try {
      final config = {
        'systemStats': _systemStats,
        'timestamp': DateTime.now().toIso8601String(),
        'aiInitialized': AI.isInitialized,
        'debugInfo': AI.debugInfo,
      };

      final configJson = JsonEncoder.withIndent('  ').convert(config);
      await Clipboard.setData(ClipboardData(text: configJson));
      _showSnackBar('✅ Configuración copiada al portapapeles');
    } catch (e) {
      _showSnackBar('Error exportando configuración: $e', isError: true);
    }
  }

  Future<void> _showDebugInfo() async {
    final debugInfo = AI.debugInfo;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de Debug'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Debug Info:'),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: debugInfo));
                        _showSnackBar('✅ Información copiada');
                      },
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
                  child: SelectableText(
                    debugInfo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
