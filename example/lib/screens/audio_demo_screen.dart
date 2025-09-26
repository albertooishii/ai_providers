import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

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
                      Text(
                        'Speech synthesis and transcription',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn().slideY(begin: -0.2),

            const SizedBox(height: 32),

            // Tabs
            DefaultTabController(
              length: 2,
              child: Expanded(
                child: Column(
                  children: [
                    TabBar(
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
                        children: [
                          _buildTextToSpeechTab(),
                          _buildSpeechToTextTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextToSpeechTab() {
    return Column(
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

        // Audio player placeholder
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
        ] else ...[
          Expanded(
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSpeechToTextTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Recording button
        Center(
          child: GestureDetector(
            onTapDown: (_) => _startRecording(),
            onTapUp: (_) => _stopRecording(),
            onTapCancel: () => _stopRecording(),
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
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: _isRecording ? 40 : 36,
              ),
            ),
          ).animate().scale(),
        ),

        const SizedBox(height: 24),

        Text(
          _isRecording ? 'Recording... (Release to stop)' : 'Hold to record',
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
          Expanded(
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _generateSpeech() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      // Simulate speech generation
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech generated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
    });
  }

  void _stopRecording() {
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
    });

    // Simulate transcription
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _transcribedText =
            'This is a simulated transcription of your recorded audio. '
            'The AI Providers SDK would process your actual speech here.';
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _waveController.dispose();
    super.dispose();
  }
}

extension on double {
  double sin() => 0.5 + 0.5 * math.sin(this * 6.28318530718);
}
