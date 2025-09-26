import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_providers/ai_providers.dart';

class TextDemoScreen extends StatefulWidget {
  const TextDemoScreen({super.key});

  @override
  State<TextDemoScreen> createState() => _TextDemoScreenState();
}

class _TextDemoScreenState extends State<TextDemoScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  String _generatedText = '';
  String _selectedProvider = ''; // Will be loaded from system configuration
  String _selectedModel = '';

  @override
  void initState() {
    super.initState();
    _promptController.addListener(() {
      setState(() {}); // Update UI when text changes
    });

    // Load default model for the initial provider
    _loadDefaultModel();
  }

  Future<void> _loadDefaultModel() async {
    try {
      // Get the current/default provider for text generation
      final currentProvider =
          await AI.getCurrentProvider(AICapability.textGeneration);
      if (currentProvider != null) {
        setState(() {
          _selectedProvider = currentProvider;
        });
        debugPrint('🎯 Loaded current provider: $currentProvider');
      }

      // Get the current/default model for text generation
      final currentModel =
          await AI.getCurrentModel(AICapability.textGeneration);
      if (currentModel != null && _selectedModel.isEmpty) {
        setState(() {
          _selectedModel = currentModel;
        });
        debugPrint('🎯 Loaded current model: $currentModel');
      } else {
        // Fallback: get models for provider and use first one
        final models = await _getModelsForProvider(_selectedProvider);
        if (models.isNotEmpty && _selectedModel.isEmpty) {
          setState(() {
            _selectedModel = models.first;
          });
          debugPrint('🎯 Fallback to first model: ${models.first}');
        }
      }
    } catch (e) {
      debugPrint('Error loading default model: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Generation'),
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
        foregroundColor: Colors.blue.shade700,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: Colors.blue.shade700),
            tooltip: 'AI Configuration',
            onPressed: () => _showConfigurationDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Text Generation',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Provider: ${_formatProviderName(_selectedProvider)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      if (_selectedModel.isNotEmpty)
                        Text(
                          'Model: $_selectedModel',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn().slideY(begin: -0.2),

            const SizedBox(height: 32),

            // Quick prompts
            Text(
              'Quick Prompts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickPrompt('Write a haiku about technology'),
                  _buildQuickPrompt('Explain quantum computing simply'),
                  _buildQuickPrompt('Create a recipe for chocolate cake'),
                  _buildQuickPrompt('Write a motivational quote'),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 24),

            // Input field
            TextField(
              controller: _promptController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Enter your prompt',
                hintText: 'Ask me anything...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.edit_rounded),
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 24),

            // Generate button
            FilledButton.icon(
              onPressed: _isGenerating || _promptController.text.trim().isEmpty
                  ? null
                  : _generateText,
              icon: _isGenerating
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isGenerating ? 'Generating...' : 'Generate Text'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 32),

            // Results
            if (_generatedText.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    'Generated Text',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _generatedText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Copy to clipboard',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Text(
                        _generatedText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                      ),
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: 0.2),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Generated text will appear here',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPrompt(String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ActionChip(
        label: Text(prompt),
        onPressed: () {
          _promptController.text = prompt;
        },
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
      ),
    );
  }

  Future<void> _generateText() async {
    setState(() {
      _isGenerating = true;
      _generatedText = '';
    });

    try {
      // 🚀 ¡USANDO EL SDK REAL DE AI PROVIDERS!
      debugPrint(
          '🤖 Generating text with ${_selectedProvider.toUpperCase()}...');

      // Create system prompt with the selected provider preference
      final systemPrompt = AISystemPrompt(
        context: {
          'user': 'Demo User',
          'app': 'AI Providers Example',
          'provider': _selectedProvider,
        },
        dateTime: DateTime.now(),
        instructions: {
          'role':
              'You are a helpful AI assistant demonstrating the AI Providers SDK.',
          'style':
              'Be informative, friendly, and showcase the capabilities of the unified AI SDK.',
          'format':
              'Provide clear, well-structured responses with examples when relevant.',
          'provider_context':
              'You are currently running through the $_selectedProvider provider via the AI Providers SDK.',
        },
      );

      // 🎯 Call the real AI.text() method!
      final response = await AI.text(_promptController.text, systemPrompt);

      debugPrint('✅ AI response received: ${response.text.length} characters');

      setState(() {
        _generatedText = response.text;
      });

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Generated by ${_selectedProvider.toUpperCase()}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ AI generation error: $e');

      setState(() {
        _generatedText =
            '❌ Error generating text with ${_selectedProvider.toUpperCase()}:\n\n$e\n\n'
            '💡 Make sure your API keys are configured in the .env file:\n'
            '• OPENAI_API_KEY for OpenAI\n'
            '• GOOGLE_API_KEY for Google Gemini\n\n'
            'The AI Providers SDK handles automatic fallbacks and retry logic, '
            'but requires at least one valid API key to work.';
      });

      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error with ${_selectedProvider.toUpperCase()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _showConfigurationDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.settings_rounded, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('AI Configuration'),
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 500, // Limitar altura para evitar overflow
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Text Generation Settings',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),

                      // Provider Selection
                      Builder(
                        builder: (context) {
                          try {
                            // Debug: Check initialization and config
                            debugPrint(
                                '🔍 AI initialized: ${AI.isInitialized}');
                            debugPrint('🔍 AI debug info: ${AI.debugInfo}');

                            // Get rich provider information (all providers for debugging)
                            final providersInfo = AI.getAvailableProviders(
                                AICapability.textGeneration);

                            // Debug: Print provider info
                            debugPrint(
                                '🔍 Providers found: ${providersInfo.length}');
                            for (final provider in providersInfo) {
                              debugPrint(
                                  '🔍 Provider: ${provider['id']} - ${provider['displayName']} - enabled: ${provider['enabled']}');
                            }

                            // Also check text generation specific providers
                            final textProviders = AI.getAvailableProviders(
                                AICapability.textGeneration);
                            debugPrint(
                                '🔍 Text generation providers: ${textProviders.length}');
                            for (final provider in textProviders) {
                              debugPrint(
                                  '🔍 Text Provider: ${provider['id']} - ${provider['displayName']}');
                            }

                            if (providersInfo.isEmpty) {
                              return const Center(
                                  child: Text('No providers available'));
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Provider',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: providersInfo.any(
                                          (p) => p['id'] == _selectedProvider)
                                      ? _selectedProvider
                                      : (providersInfo.isNotEmpty
                                          ? providersInfo.first['id'] as String
                                          : null),
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.business_rounded),
                                  ),
                                  items: providersInfo.map((providerInfo) {
                                    final providerId =
                                        providerInfo['id'] as String;
                                    final displayName =
                                        providerInfo['displayName'] as String;
                                    return DropdownMenuItem(
                                      value: providerId,
                                      child: Text(displayName),
                                    );
                                  }).toList(),
                                  onChanged: (newProvider) async {
                                    if (newProvider != null) {
                                      setDialogState(() {
                                        _selectedProvider = newProvider;
                                        _selectedModel =
                                            ''; // Reset model when provider changes
                                      });

                                      // Auto-select default model for the new provider
                                      try {
                                        final defaultModel =
                                            await AI.getDefaultModelForProvider(
                                                newProvider,
                                                AICapability.textGeneration);
                                        if (defaultModel != null) {
                                          setDialogState(() {
                                            _selectedModel = defaultModel;
                                          });
                                          debugPrint(
                                              '🎯 Auto-selected default model: $defaultModel for provider: $newProvider');
                                        } else {
                                          // Fallback to first available model
                                          final models =
                                              await _getModelsForProvider(
                                                  newProvider);
                                          if (models.isNotEmpty) {
                                            setDialogState(() {
                                              _selectedModel = models.first;
                                            });
                                            debugPrint(
                                                '🎯 Fallback to first model: ${models.first}');
                                          }
                                        }
                                      } catch (e) {
                                        debugPrint(
                                            'Error auto-selecting model: $e');
                                      }
                                    }
                                  },
                                ),
                              ],
                            );
                          } catch (e) {
                            debugPrint('Error loading providers: $e');
                            return const Center(
                                child: Text('Error loading providers'));
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // Model Selection
                      FutureBuilder<List<String>>(
                        key: ValueKey(
                            'models_$_selectedProvider'), // Force rebuild when provider changes
                        future: _getModelsForProvider(_selectedProvider),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              height: 40,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final models = snapshot.data!;
                          debugPrint(
                              '🔍 FutureBuilder rebuilt for provider $_selectedProvider with ${models.length} models');

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Model',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: models.contains(_selectedModel)
                                    ? _selectedModel
                                    : null,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.psychology_rounded),
                                  hintText: 'Select a model...',
                                ),
                                items: models.map((model) {
                                  return DropdownMenuItem(
                                    value: model,
                                    child: Text(model),
                                  );
                                }).toList(),
                                onChanged: (newModel) {
                                  if (newModel != null) {
                                    setDialogState(() {
                                      _selectedModel = newModel;
                                    });
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Current Configuration Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Configuration',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Provider: ${_formatProviderName(_selectedProvider)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'Model: ${_selectedModel.isEmpty ? "Default" : _selectedModel}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      // Save configuration to SharedPreferences
                      if (_selectedProvider.isNotEmpty &&
                          _selectedModel.isNotEmpty) {
                        await AI.setModel(
                          _selectedProvider,
                          _selectedModel,
                          AICapability.textGeneration,
                        );
                      }

                      setState(() {
                        // Update main state with dialog selections
                      });

                      navigator.pop();

                      messenger.showSnackBar(
                        const SnackBar(
                            content: Text('Configuration saved successfully!')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                            content: Text('Error saving configuration: $e')),
                      );
                    }
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<String>> _getModelsForProvider(String providerId) async {
    try {
      debugPrint('🔍 Getting models for provider: $providerId');

      // Use the simplified method - no capability needed!
      final providerModels = await AI.getAvailableModels(providerId);

      debugPrint(
          '🔍 Found ${providerModels.length} models for provider $providerId: $providerModels');

      return providerModels;
    } catch (e) {
      debugPrint('❌ Error getting models for provider $providerId: $e');
      return []; // Return empty list on error
    }
  }

  String _formatProviderName(String providerId) {
    try {
      // Get provider info dynamically from AI system using the new rich data
      final providersInfo =
          AI.getAvailableProviders(AICapability.textGeneration);
      final providerInfo = providersInfo.firstWhere(
        (provider) => provider['id'] == providerId,
        orElse: () => {},
      );

      return providerInfo['displayName'] ?? _fallbackProviderName(providerId);
    } catch (e) {
      // Fallback to basic formatting if provider info not available
      return _fallbackProviderName(providerId);
    }
  }

  String _fallbackProviderName(String providerId) {
    // Basic capitalization without hardcoding specific provider names
    return providerId
        .split('_')
        .map((word) =>
            word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}
