import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_providers/ai_providers.dart';

class AudioDemoScreen extends StatefulWidget {
  const AudioDemoScreen({super.key});

  @override
  State<AudioDemoScreen> createState() => _AudioDemoScreenState();
}

class _AudioDemoScreenState extends State<AudioDemoScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  bool _isGenerating = false;
  bool _isRecording = false;
  String? _transcribedText;

  late AnimationController _waveController;

  // Provider and model selection for TTS and STT
  String _selectedTTSProvider = '';
  String _selectedTTSModel = '';
  String _selectedTTSVoice = '';
  String _selectedSTTProvider = '';
  String _selectedSTTModel = '';

  // Tab controller to track active tab
  late TabController _tabController;

  // Generated audio state
  String? _generatedAudioBase64;
  String? _generatedAudioFileName;
  bool _hasAudioGenerated = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _textController.addListener(() {
      setState(() {}); // Update UI when text changes
    });

    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Update header when tab changes
    });

    // Load default providers and models
    _loadDefaultConfiguration();
  }

  Future<void> _loadDefaultConfiguration() async {
    try {
      // Load default provider and model for audio generation (TTS)
      final ttsProvider =
          await AI.getCurrentProvider(AICapability.audioGeneration);
      if (ttsProvider != null) {
        setState(() {
          _selectedTTSProvider = ttsProvider;
        });

        final ttsModel = await AI.getCurrentModel(AICapability.audioGeneration);
        if (ttsModel != null && _selectedTTSModel.isEmpty) {
          setState(() {
            _selectedTTSModel = ttsModel;
          });
        }

        // Load configured voice for TTS provider (from cache or default)
        final currentVoice = await AI.getCurrentVoiceForProvider(ttsProvider);
        if (currentVoice != null && _selectedTTSVoice.isEmpty) {
          setState(() {
            _selectedTTSVoice = currentVoice;
          });
        } else {
          // Fallback: get available voices and use first one
          final voices = await _getVoicesForProvider(ttsProvider);
          if (voices.isNotEmpty && _selectedTTSVoice.isEmpty) {
            setState(() {
              _selectedTTSVoice = voices.first;
            });
          }
        }
      }

      // Load default provider and model for audio transcription (STT)
      final sttProvider =
          await AI.getCurrentProvider(AICapability.audioTranscription);
      if (sttProvider != null) {
        setState(() {
          _selectedSTTProvider = sttProvider;
        });

        final sttModel =
            await AI.getCurrentModel(AICapability.audioTranscription);
        if (sttModel != null && _selectedSTTModel.isEmpty) {
          setState(() {
            _selectedSTTModel = sttModel;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading default audio configuration: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Processing'),
        backgroundColor: Colors.green.withValues(alpha: 0.1),
        foregroundColor: Colors.green.shade700,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: Colors.green.shade700),
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
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.audiotrack_outlined,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Audio Processing',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      // Show info based on active tab
                      Text(
                        _tabController.index == 0
                            ? 'Provider: ${_formatProviderName(_selectedTTSProvider)}'
                            : 'Provider: ${_formatProviderName(_selectedSTTProvider)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      if ((_tabController.index == 0 &&
                              _selectedTTSModel.isNotEmpty) ||
                          (_tabController.index == 1 &&
                              _selectedSTTModel.isNotEmpty))
                        Text(
                          'Model: ${_tabController.index == 0 ? _selectedTTSModel : _selectedSTTModel}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                      // Show voice only for TTS (tab 0)
                      if (_tabController.index == 0 &&
                          _selectedTTSVoice.isNotEmpty)
                        Text(
                          'Voice: $_selectedTTSVoice',
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

            // Tabs
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.green.shade700,
                    unselectedLabelColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    indicatorColor: Colors.green.shade700,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.record_voice_over_rounded),
                        text: 'Text to Speech',
                      ),
                      Tab(
                        icon: Icon(Icons.mic_rounded),
                        text: 'Speech to Text',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTextToSpeechTab(),
                        _buildSpeechToTextTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextToSpeechTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Text to convert to speech',
              hintText: 'Enter text here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              prefixIcon: const Icon(Icons.text_fields_rounded),
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 16),

          const SizedBox(height: 24),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _isGenerating || _textController.text.trim().isEmpty
                ? null
                : _generateSpeech,
            icon: _isGenerating
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.volume_up_rounded),
            label: Text(_isGenerating ? 'Generating...' : 'Generate Speech'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green.shade600,
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 32),

          // Audio player area
          if (_isGenerating) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 20 +
                                  (20 *
                                      (0.5 +
                                          0.5 *
                                              (1 +
                                                      (index * 0.3) +
                                                      _waveController.value)
                                                  .sin())),
                              width: 4,
                              decoration: BoxDecoration(
                                color: Colors.green.shade400,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Generating audio...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn().scale(),
          ] else if (_hasAudioGenerated) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.audiotrack_rounded,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Generated Audio',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Audio controls
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: _playGeneratedAudio,
                                icon: const Icon(Icons.play_arrow_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: _pauseGeneratedAudio,
                                icon: const Icon(Icons.pause_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: _stopGeneratedAudio,
                                icon: const Icon(Icons.stop_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Audio generated and saved • Ready to play',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.green.shade700,
                                    ),
                          ),
                          if (_generatedAudioFileName != null)
                            Text(
                              'File: ${_generatedAudioFileName!.split('/').last}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
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
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.2),
          ] else ...[
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.audiotrack_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Generated audio will appear here',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Add some padding at the bottom for scroll
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSpeechToTextTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recording button
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isRecording ? null : _handleRecordTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isRecording ? 120 : 100,
                    height: _isRecording ? 120 : 100,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.green.shade600,
                      shape: BoxShape.circle,
                      boxShadow: _isRecording
                          ? [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: _isRecording ? 40 : 36,
                    ),
                  ),
                ).animate().scale(),

                // Manual stop button (only visible when recording)
                if (_isRecording) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _stopRecordingManually,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('Stop Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            _isRecording
                ? 'Recording... speak now, will auto-stop when you finish'
                : 'Tap to record with automatic stop',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _isRecording
                      ? Colors.red
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 32),

          // Transcription results
          if (_transcribedText != null) ...[
            Text(
              'Transcription',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _transcribedText!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.2),
          ] else ...[
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mic_none_rounded,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Transcribed text will appear here',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Add some padding at the bottom for scroll
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _generateSpeech() async {
    if (!mounted) return;
    setState(() {
      _isGenerating = true;
    });
    try {
      // Set the selected provider and model if specified
      if (_selectedTTSProvider.isNotEmpty && _selectedTTSModel.isNotEmpty) {
        await AI.setModel(
          _selectedTTSProvider,
          _selectedTTSModel,
          AICapability.audioGeneration,
        );
      }

      // Use AI.speak for real TTS
      final audioParams = AiAudioParams(
        language: 'es-ES', // Default language
        speed: 1.0,
        // audioFormat: M4A por defecto (opcional especificar)
      );

      final response = await AI.speak(
        _textController.text.trim(),
        audioParams,
      );

      if (!mounted) return;

      // Nueva lógica simplificada: siempre disponible en ambos formatos
      if (response.audio != null &&
          (response.audio!.url?.isNotEmpty == true ||
              response.audio!.base64?.isNotEmpty == true)) {
        if (!mounted) return;
        setState(() {
          // Guardar ambos formatos - el usuario puede elegir cuál usar
          _generatedAudioFileName = response.audio?.url;
          _generatedAudioBase64 = response.audio?.base64;
          _hasAudioGenerated = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '🎵 Audio generado y guardado por ${_selectedTTSProvider.toUpperCase()}!')),
        );
      } else if (response.text.isNotEmpty) {
        // Fallback: mostrar respuesta de texto si no hay audio
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Respuesta: ${response.text.length > 100 ? '${response.text.substring(0, 100)}...' : response.text}')),
        );
      } else {
        throw Exception('No se recibieron datos de audio del proveedor');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('❌ Error with ${_selectedTTSProvider.toUpperCase()}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _handleRecordTap() async {
    if (_isRecording) return;

    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _transcribedText = null; // Limpiar texto anterior
    });

    await _transcribeAudio();

    if (!mounted) return;
    setState(() {
      _isRecording = false;
    });
  }

  /// Parar grabación manualmente usando AI.stopListen()
  Future<void> _stopRecordingManually() async {
    try {
      debugPrint(
          '[AudioDemo] 🛑 Stopping recording manually with AI.stopListen()');

      // Mostrar estado de procesamiento
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _transcribedText = '🎧 Processing recorded audio...';
      });

      // Usar la nueva API AI.stopListen() para parar la grabación
      final response = await AI.stopListen();

      if (!mounted) return;
      setState(() {
        if (response != null && response.text.trim().isNotEmpty) {
          _transcribedText = response.text.trim();
        } else {
          _transcribedText = 'No speech detected in recording';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🛑 Recording stopped manually by ${_selectedSTTProvider.toUpperCase()}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _transcribedText = 'Error stopping recording: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error stopping recording: $e')),
      );
    }
  }

  Future<void> _transcribeAudio() async {
    try {
      // Set the selected provider and model if specified
      if (_selectedSTTProvider.isNotEmpty && _selectedSTTModel.isNotEmpty) {
        await AI.setModel(
          _selectedSTTProvider,
          _selectedSTTModel,
          AICapability.audioTranscription,
        );
      }

      // Mostrar estado de procesamiento durante la grabación automática
      if (!mounted) return;
      setState(() {
        _transcribedText =
            '🎧 Processing audio... speak clearly and wait for silence detection';
      });

      // 🎤 Usar nueva API AI.listen() completamente automático
      final response = await AI.listen();

      if (!mounted) return;
      setState(() {
        if (response?.text.isNotEmpty == true) {
          _transcribedText = response?.text;
        } else {
          _transcribedText =
              '🔇 No se detectó audio claro durante la grabación.\n\n'
              'Posibles causas:\n'
              '• El micrófono no captó suficiente audio\n'
              '• El audio fue demasiado bajo o silencioso\n'
              '• Se detuvo antes de hablar\n\n'
              'Intenta hablar más alto y cerca del micrófono.';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '✨ Audio transcribed by ${_selectedSTTProvider.toUpperCase()}!')),
      );
    } catch (e) {
      if (!mounted) return;

      if (!mounted) return;
      setState(() {
        _transcribedText =
            'Error en transcripción con ${_selectedSTTProvider.toUpperCase()}: $e\n\n'
            'Nota: La transcripción real requiere implementar la grabación de audio desde el micrófono.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('❌ Error with ${_selectedSTTProvider.toUpperCase()}: $e')),
      );
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
                  Icon(Icons.settings_rounded, color: Colors.green),
                  SizedBox(width: 8),
                  Text('AI Audio Configuration'),
                ],
              ),
              content: SizedBox(
                width: 450,
                height: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio Processing Settings',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 24),

                      // Text-to-Speech Section
                      _buildCapabilitySection(
                        context: context,
                        setDialogState: setDialogState,
                        capability: AICapability.audioGeneration,
                        title: 'Text-to-Speech (TTS)',
                        icon: Icons.record_voice_over_rounded,
                        color: Colors.blue,
                        selectedProvider: _selectedTTSProvider,
                        selectedModel: _selectedTTSModel,
                        selectedVoice: _selectedTTSVoice,
                        showVoice: true,
                        onProviderChanged: (provider) {
                          setDialogState(() {
                            _selectedTTSProvider = provider;
                            _selectedTTSModel = '';
                            _selectedTTSVoice = '';
                          });
                          _autoSelectModelAndVoiceForProvider(
                              provider,
                              AICapability.audioGeneration,
                              setDialogState,
                              true);
                        },
                        onModelChanged: (model) {
                          setDialogState(() {
                            _selectedTTSModel = model;
                          });
                        },
                        onVoiceChanged: (voice) {
                          setDialogState(() {
                            _selectedTTSVoice = voice;
                          });
                        },
                      ),

                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Speech-to-Text Section
                      _buildCapabilitySection(
                        context: context,
                        setDialogState: setDialogState,
                        capability: AICapability.audioTranscription,
                        title: 'Speech-to-Text (STT)',
                        icon: Icons.mic_rounded,
                        color: Colors.orange,
                        selectedProvider: _selectedSTTProvider,
                        selectedModel: _selectedSTTModel,
                        selectedVoice: '', // STT doesn't use voice
                        showVoice: false,
                        onProviderChanged: (provider) {
                          setDialogState(() {
                            _selectedSTTProvider = provider;
                            _selectedSTTModel = '';
                          });
                          _autoSelectModelAndVoiceForProvider(
                              provider,
                              AICapability.audioTranscription,
                              setDialogState,
                              false);
                        },
                        onModelChanged: (model) {
                          setDialogState(() {
                            _selectedSTTModel = model;
                          });
                        },
                        onVoiceChanged: (voice) {
                          // STT doesn't use voice, do nothing
                        },
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
                      // Save TTS configurations
                      if (_selectedTTSProvider.isNotEmpty &&
                          _selectedTTSModel.isNotEmpty) {
                        await AI.setModel(
                          _selectedTTSProvider,
                          _selectedTTSModel,
                          AICapability.audioGeneration,
                        );
                      }
                      if (_selectedTTSVoice.isNotEmpty &&
                          _selectedTTSProvider.isNotEmpty) {
                        await AI.setSelectedVoiceForProvider(
                          _selectedTTSProvider,
                          _selectedTTSVoice,
                        );
                      }

                      // Save STT configurations
                      if (_selectedSTTProvider.isNotEmpty &&
                          _selectedSTTModel.isNotEmpty) {
                        await AI.setModel(
                          _selectedSTTProvider,
                          _selectedSTTModel,
                          AICapability.audioTranscription,
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

  Widget _buildCapabilitySection({
    required BuildContext context,
    required StateSetter setDialogState,
    required AICapability capability,
    required String title,
    required IconData icon,
    required Color color,
    required String selectedProvider,
    required String selectedModel,
    required String selectedVoice,
    required bool showVoice,
    required Function(String) onProviderChanged,
    required Function(String) onModelChanged,
    required Function(String) onVoiceChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Provider Selection
        Builder(
          builder: (context) {
            try {
              final providersInfo = AI.getAvailableProviders(capability);

              if (providersInfo.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'No providers available for $title',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade700,
                            ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Provider',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedProvider.isNotEmpty &&
                            providersInfo.any((p) => p.id == selectedProvider)
                        ? selectedProvider
                        : null,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business_rounded, color: color),
                    ),
                    items: providersInfo.map((providerInfo) {
                      final providerId = providerInfo.id;
                      final displayName = providerInfo.displayName;
                      return DropdownMenuItem(
                        value: providerId,
                        child: Text(displayName),
                      );
                    }).toList(),
                    onChanged: (newProvider) {
                      if (newProvider != null) {
                        onProviderChanged(newProvider);
                      }
                    },
                  ),
                ],
              );
            } catch (e) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error loading providers: $e',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                      ),
                ),
              );
            }
          },
        ),

        const SizedBox(height: 16),

        // Model Selection
        if (selectedProvider.isNotEmpty)
          FutureBuilder<List<String>>(
            key: ValueKey('models_${selectedProvider}_$capability'),
            future: _getModelsForProvider(selectedProvider),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final models = snapshot.data!;
              if (models.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'No models available for this provider',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Model',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedModel.isNotEmpty &&
                            models.contains(selectedModel)
                        ? selectedModel
                        : null,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.psychology_rounded, color: color),
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
                        onModelChanged(newModel);
                      }
                    },
                  ),
                ],
              );
            },
          ),

        // Voice Selection (only for TTS)
        if (showVoice && selectedProvider.isNotEmpty) ...[
          const SizedBox(height: 16),
          FutureBuilder<List<String>>(
            key: ValueKey('voices_$selectedProvider'),
            future: _getVoicesForProvider(selectedProvider),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final voices = snapshot.data!;
              if (voices.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'No voices available for this provider',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedVoice.isNotEmpty &&
                            voices.contains(selectedVoice)
                        ? selectedVoice
                        : null,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.record_voice_over, color: color),
                      hintText: 'Select a voice...',
                    ),
                    items: voices.map((voice) {
                      return DropdownMenuItem(
                        value: voice,
                        child: Text(voice),
                      );
                    }).toList(),
                    onChanged: (newVoice) {
                      if (newVoice != null) {
                        onVoiceChanged(newVoice);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],

        const SizedBox(height: 16),

        // Current Configuration Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Configuration',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Provider: ${_formatProviderName(selectedProvider)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Model: ${selectedModel.isEmpty ? "Default" : selectedModel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (showVoice)
                Text(
                  'Voice: ${selectedVoice.isEmpty ? "Default" : selectedVoice}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _autoSelectModelAndVoiceForProvider(String providerId,
      AICapability capability, StateSetter setDialogState, bool isTTS) async {
    try {
      // Auto-select default model
      final defaultModel =
          await AI.getDefaultModelForProvider(providerId, capability);
      if (defaultModel != null) {
        setDialogState(() {
          if (isTTS) {
            _selectedTTSModel = defaultModel;
          } else {
            _selectedSTTModel = defaultModel;
          }
        });
      }

      // Auto-select default voice for TTS
      if (isTTS) {
        // First try to get saved voice for this provider
        final currentVoice = await AI.getCurrentVoiceForProvider(providerId);
        if (currentVoice != null) {
          setDialogState(() {
            _selectedTTSVoice = currentVoice;
          });
        } else {
          // Fallback to first available voice
          final voices = await _getVoicesForProvider(providerId);
          if (voices.isNotEmpty) {
            setDialogState(() {
              _selectedTTSVoice = voices.first;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error auto-selecting model and voice: $e');
    }
  }

  Future<List<String>> _getModelsForProvider(String providerId) async {
    try {
      final models = await AI.getAvailableModels(providerId);
      return models;
    } catch (e) {
      debugPrint('Error getting models for provider $providerId: $e');
      return [];
    }
  }

  Future<List<String>> _getVoicesForProvider(String providerId) async {
    try {
      // Get voices from AI SDK for specific provider
      final voicesData = await AI.getVoicesForProvider(providerId);

      if (voicesData.isNotEmpty) {
        return voicesData.map<String>((voiceData) {
          // Extract voice name/id from voice data
          return voiceData['name']?.toString() ??
              voiceData['id']?.toString() ??
              voiceData.toString();
        }).toList();
      }

      // Return empty list if no voices available
      return [];
    } catch (e) {
      debugPrint('Error getting voices for provider $providerId: $e');
      // Return empty list on error - let the UI handle the empty state
      return [];
    }
  }

  String _formatProviderName(String providerId) {
    try {
      // Try to get display name from TTS providers first
      final ttsProviders =
          AI.getAvailableProviders(AICapability.audioGeneration);
      final providerInfo = ttsProviders.firstWhere(
        (provider) => provider.id == providerId,
        orElse: () => AIProvider.empty(providerId),
      );

      if (providerInfo.enabled) {
        return providerInfo.displayName;
      }

      // If not found, try STT providers
      final sttProviders =
          AI.getAvailableProviders(AICapability.audioTranscription);
      final sttProviderInfo = sttProviders.firstWhere(
        (provider) => provider.id == providerId,
        orElse: () => AIProvider.empty(providerId),
      );

      return sttProviderInfo.displayName;
    } catch (e) {
      return providerId.isEmpty ? 'N/A' : providerId;
    }
  }

  /// Play the generated audio (file or base64)
  Future<void> _playGeneratedAudio() async {
    try {
      if (_generatedAudioFileName != null) {
        // Play audio file from cache using AI API
        try {
          // Re-synthesize and play the same text with play=true
          final audioParams = AiAudioParams(
            language: 'es-ES',
            speed: 1.0,
            // M4A automático por defecto
          );

          await AI.speak(
            _textController.text.trim(),
            audioParams,
            true, // play=true para reproducción automática
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error playing audio: $e')),
          );
        }
      } else if (_generatedAudioBase64 != null) {
        // Use AI.transcribe() to process base64 audio if needed
        // For playback, re-synthesize using AI.speak() with play=true
        try {
          final audioParams = AiAudioParams(
            language: 'es-ES',
            speed: 1.0,
            audioFormat: 'mp3', // Ejemplo de alternativa MP3
          );

          await AI.speak(
            _textController.text.trim(),
            audioParams,
            true, // play=true para reproducción automática
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error playing audio: $e')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ No audio available to play')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error playing audio: $e')),
      );
    }
  }

  /// Stop audio playback
  Future<void> _stopGeneratedAudio() async {
    try {
      final success = await AI.stopSpeak();

      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Error stopping audio')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error stopping audio: $e')),
      );
    }
  }

  /// Pause audio playback
  Future<void> _pauseGeneratedAudio() async {
    try {
      final success = await AI.pauseSpeak();

      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Error pausing audio')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error pausing audio: $e')),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _waveController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

extension on double {
  double sin() => 0.5 + 0.5 * math.sin(this * 6.28318530718);
}
