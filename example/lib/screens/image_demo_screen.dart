import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_providers/ai_providers.dart';
import '../utils/file_utils.dart';

class ImageDemoScreen extends StatefulWidget {
  const ImageDemoScreen({super.key});

  @override
  State<ImageDemoScreen> createState() => _ImageDemoScreenState();
}

class _ImageDemoScreenState extends State<ImageDemoScreen>
    with TickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();

  bool _isGenerating = false;
  bool _isAnalyzing = false;
  String? _generatedImageBase64;
  String? _generatedImageFileName;
  bool _hasSelectedImage = false;
  String? _analysisResult;

  // Image selection for analysis
  File? _selectedImageFile;
  String? _selectedImageBase64;
  String? _selectedImageMimeType;

  // Provider and model selection for generation and analysis
  String _selectedGenerationProvider = '';
  String _selectedGenerationModel = '';
  String _selectedAnalysisProvider = '';
  String _selectedAnalysisModel = '';

  // Tab controller to track active tab
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(() {
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
      // Load default provider and model for image generation
      final generationProvider =
          await AI.getCurrentProvider(AICapability.imageGeneration);
      if (generationProvider != null) {
        setState(() {
          _selectedGenerationProvider = generationProvider;
        });

        final generationModel =
            await AI.getCurrentModel(AICapability.imageGeneration);
        if (generationModel != null && _selectedGenerationModel.isEmpty) {
          setState(() {
            _selectedGenerationModel = generationModel;
          });
        } else {
          // Fallback: get models for provider and use first one
          final models =
              await _getModelsForProvider(_selectedGenerationProvider);
          if (models.isNotEmpty && _selectedGenerationModel.isEmpty) {
            setState(() {
              _selectedGenerationModel = models.first;
            });
          }
        }
      }

      // Load default provider and model for image analysis
      final analysisProvider =
          await AI.getCurrentProvider(AICapability.imageAnalysis);
      if (analysisProvider != null) {
        setState(() {
          _selectedAnalysisProvider = analysisProvider;
        });

        final analysisModel =
            await AI.getCurrentModel(AICapability.imageAnalysis);
        if (analysisModel != null && _selectedAnalysisModel.isEmpty) {
          setState(() {
            _selectedAnalysisModel = analysisModel;
          });
        } else {
          // Fallback: get models for provider and use first one
          final models = await _getModelsForProvider(_selectedAnalysisProvider);
          if (models.isNotEmpty && _selectedAnalysisModel.isEmpty) {
            setState(() {
              _selectedAnalysisModel = models.first;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading default configuration: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Processing'),
        backgroundColor: Colors.purple.withValues(alpha: 0.1),
        foregroundColor: Colors.purple.shade700,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: Colors.purple.shade700),
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
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.purple.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Image Processing',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      // Show info based on active tab
                      Text(
                        _tabController.index == 0
                            ? 'Provider: ${_formatProviderName(_selectedGenerationProvider)}'
                            : 'Provider: ${_formatProviderName(_selectedAnalysisProvider)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      if ((_tabController.index == 0 &&
                              _selectedGenerationModel.isNotEmpty) ||
                          (_tabController.index == 1 &&
                              _selectedAnalysisModel.isNotEmpty))
                        Text(
                          'Model: ${_tabController.index == 0 ? _selectedGenerationModel : _selectedAnalysisModel}',
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
                    labelColor: Colors.purple.shade700,
                    unselectedLabelColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    indicatorColor: Colors.purple.shade700,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.auto_awesome_rounded),
                        text: 'Generate Image',
                      ),
                      Tab(
                        icon: Icon(Icons.search_rounded),
                        text: 'Analyze Image',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildImageGenerationTab(),
                        _buildImageAnalysisTab(),
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

  Widget _buildImageGenerationTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _promptController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Describe the image you want to create',
              hintText:
                  'A beautiful sunset over mountains with reflection in water...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              prefixIcon: const Icon(Icons.palette_rounded),
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _isGenerating || _promptController.text.trim().isEmpty
                ? null
                : _generateImage,
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
            label: Text(_isGenerating ? 'Generating...' : 'Generate Image'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.purple.shade600,
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 32),

          // Generated image area - Fixed height for better display
          SizedBox(
            height: MediaQuery.of(context).size.height *
                0.6, // 60% of screen height
            child: (_generatedImageBase64 != null ||
                    _generatedImageFileName != null)
                ? Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Image container that uses fixed height
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: GestureDetector(
                              onTap: () => _showGeneratedImagePreview(context),
                              child: SizedBox(
                                width: double.infinity,
                                height: double.infinity,
                                child: _generatedImageBase64 != null
                                    ? Image.memory(
                                        base64Decode(_generatedImageBase64!),
                                        fit: BoxFit
                                            .contain, // Maintain aspect ratio but fill height
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder:
                                            (aiContext, error, stackTrace) {
                                          return _buildImageErrorWidget();
                                        },
                                      )
                                    : _generatedImageFileName != null
                                        ? FutureBuilder<File>(
                                            future: _loadImageFromCache(
                                                _generatedImageFileName!),
                                            builder: (aiContext, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data!.existsSync()) {
                                                return Image.file(
                                                  snapshot.data!,
                                                  fit: BoxFit
                                                      .contain, // Maintain aspect ratio but fill height
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorBuilder: (aiContext,
                                                      error, stackTrace) {
                                                    return _buildImageErrorWidget();
                                                  },
                                                );
                                              } else if (snapshot.hasError) {
                                                return _buildImageErrorWidget();
                                              } else {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              }
                                            },
                                          )
                                        : _buildImageErrorWidget(),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '¡Imagen generada y guardada!',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Click para vista completa • Proveedor: ${_selectedGenerationProvider.isNotEmpty ? _formatProviderName(_selectedGenerationProvider) : "Por defecto"} • Disponible en base64 y caché',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scale()
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Generated image will appear here',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
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
      ),
    );
  }

  Widget _buildImageAnalysisTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image selection area
        Card(
          child: InkWell(
            onTap: _selectImage,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 200,
              padding: const EdgeInsets.all(24),
              child: _hasSelectedImage && _selectedImageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // Image preview
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () => _showImagePreview(context),
                              child: Image.file(
                                _selectedImageFile!,
                                fit: BoxFit.cover,
                                errorBuilder: (aiContext, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.purple.shade200,
                                          Colors.purple.shade400,
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 48,
                                            color: Colors.white,
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Error loading image',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Dark overlay for text visibility
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.7),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Image info overlay
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedImageFile!.path.split('/').last,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    FutureBuilder<int>(
                                      future: _selectedImageFile!.length(),
                                      builder: (aiContext, snapshot) {
                                        if (snapshot.hasData) {
                                          return Text(
                                            FileUtils.formatFileSize(
                                                snapshot.data!),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                    const Text(
                                      ' • ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const Text(
                                      'Tap to change • Click to preview',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Change icon in top-right corner
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: Colors.purple.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select an image to analyze',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap here to choose from gallery or camera',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ),
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 24),

        FilledButton.icon(
          onPressed: _isAnalyzing || !_hasSelectedImage ? null : _analyzeImage,
          icon: _isAnalyzing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.search_rounded),
          label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Image'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.purple.shade600,
          ),
        ).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 32),

        // Analysis results
        Expanded(
          child: _analysisResult != null
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics_rounded,
                              color: Colors.purple.shade600,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Image Analysis',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _analysisResult!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    height: 1.6,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: 0.2)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Image analysis will appear here',
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
    );
  }

  Future<void> _generateImage() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      // Create system prompt for image generation
      final aiContext = AIContext(
        context:
            'You are an expert AI image generator. Create high-quality, detailed images based on user prompts.',
        dateTime: DateTime.now(),
        instructions: {
          'provider': _selectedGenerationProvider.isNotEmpty
              ? _selectedGenerationProvider
              : null,
          'model': _selectedGenerationModel.isNotEmpty
              ? _selectedGenerationModel
              : null,
        },
      );

      // Set the selected provider and model if specified
      if (_selectedGenerationProvider.isNotEmpty &&
          _selectedGenerationModel.isNotEmpty) {
        await AI.setModel(
          _selectedGenerationProvider,
          _selectedGenerationModel,
          AICapability.imageGeneration,
        );
      }

      // Use AI.image for real image generation
      final response = await AI.image(
        _promptController.text.trim(),
        aiContext,
      );

      if (!mounted) return;

      // Nueva lógica simplificada: siempre disponible en ambos formatos
      if (response.imageFileName.isNotEmpty ||
          (response.imageBase64 != null && response.imageBase64!.isNotEmpty)) {
        setState(() {
          // Guardar ambos formatos - el usuario puede elegir cuál usar
          _generatedImageFileName =
              response.imageFileName.isNotEmpty ? response.imageFileName : null;
          _generatedImageBase64 = response.imageBase64?.isNotEmpty == true
              ? response.imageBase64
              : null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('¡Imagen generada y guardada en caché!')),
        );
      } else if (response.text.isNotEmpty) {
        // Fallback: mostrar respuesta de texto si no hay imagen
        setState(() {
          _generatedImageBase64 = null;
          _generatedImageFileName = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Respuesta: ${response.text.substring(0, 100)}...')),
        );
      } else {
        throw Exception('No se recibieron datos de imagen del proveedor');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _generatedImageBase64 = null;
        _generatedImageFileName = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating image: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _selectImage() async {
    try {
      final imageFile = await FileUtils.pickImageFile();

      if (imageFile == null) {
        // User cancelled selection
        return;
      }

      // Get complete image information
      final imageInfo = await FileUtils.getImageInfo(imageFile);

      if (!imageInfo.isValid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid image file')),
        );
        return;
      }

      setState(() {
        _selectedImageFile = imageInfo.file;
        _selectedImageBase64 = imageInfo.base64;
        _selectedImageMimeType = imageInfo.mimeType;
        _hasSelectedImage = true;
        _analysisResult = null; // Reset previous analysis
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Image selected: ${imageInfo.fileName} (${imageInfo.formattedSize})'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _analyzeImage() async {
    // Check if we have a selected image
    if (_selectedImageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Create system prompt for image analysis
      final aiContext = AIContext(
        context:
            'You are an expert image analysis AI. Provide detailed, accurate analysis of images.',
        dateTime: DateTime.now(),
        instructions: {
          'provider': _selectedAnalysisProvider.isNotEmpty
              ? _selectedAnalysisProvider
              : null,
          'model':
              _selectedAnalysisModel.isNotEmpty ? _selectedAnalysisModel : null,
        },
      );

      // Set the selected provider and model if specified
      if (_selectedAnalysisProvider.isNotEmpty &&
          _selectedAnalysisModel.isNotEmpty) {
        await AI.setModel(
          _selectedAnalysisProvider,
          _selectedAnalysisModel,
          AICapability.imageAnalysis,
        );
      }

      // Use AI.vision for real image analysis
      final response = await AI.vision(
        _selectedImageBase64!,
        'Analyze this image in detail. Provide information about:\n'
        '- What you see in the image (objects, scenes, people, etc.)\n'
        '- Visual properties (colors, lighting, composition, style)\n'
        '- Technical aspects (quality, estimated resolution)\n'
        '- Any interesting details or insights\n\n'
        'Format your response in a clear, structured way with sections and bullet points.',
        aiContext,
        _selectedImageMimeType,
      );

      if (!mounted) return;

      setState(() {
        _analysisResult = response.text;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image analysis completed!')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _analysisResult = 'Error during image analysis: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
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
                  Icon(Icons.settings_rounded, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('AI Configuration'),
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
                        'Image Processing Settings',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 24),

                      // Image Generation Section
                      _buildCapabilitySection(
                        context: context,
                        setDialogState: setDialogState,
                        capability: AICapability.imageGeneration,
                        title: 'Image Generation',
                        icon: Icons.image_outlined,
                        color: Colors.green,
                        selectedProvider: _selectedGenerationProvider,
                        selectedModel: _selectedGenerationModel,
                        onProviderChanged: (provider) {
                          setDialogState(() {
                            _selectedGenerationProvider = provider;
                            _selectedGenerationModel = '';
                          });
                          _autoSelectModelForProvider(
                              provider,
                              AICapability.imageGeneration,
                              setDialogState,
                              true);
                        },
                        onModelChanged: (model) {
                          setDialogState(() {
                            _selectedGenerationModel = model;
                          });
                        },
                      ),

                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Image Analysis Section
                      _buildCapabilitySection(
                        context: context,
                        setDialogState: setDialogState,
                        capability: AICapability.imageAnalysis,
                        title: 'Image Analysis',
                        icon: Icons.analytics_outlined,
                        color: Colors.blue,
                        selectedProvider: _selectedAnalysisProvider,
                        selectedModel: _selectedAnalysisModel,
                        onProviderChanged: (provider) {
                          setDialogState(() {
                            _selectedAnalysisProvider = provider;
                            _selectedAnalysisModel = '';
                          });
                          _autoSelectModelForProvider(
                              provider,
                              AICapability.imageAnalysis,
                              setDialogState,
                              false);
                        },
                        onModelChanged: (model) {
                          setDialogState(() {
                            _selectedAnalysisModel = model;
                          });
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
                  onPressed: () {
                    setState(() {
                      // Update main state with dialog selections
                    });
                    Navigator.of(context).pop();
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
    required Function(String) onProviderChanged,
    required Function(String) onModelChanged,
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
                    initialValue:
                        providersInfo.any((p) => p.id == selectedProvider)
                            ? selectedProvider
                            : (providersInfo.isNotEmpty
                                ? providersInfo.first.id
                                : null),
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
            builder: (aiContext, snapshot) {
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
                    initialValue:
                        models.contains(selectedModel) ? selectedModel : null,
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
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _autoSelectModelForProvider(
      String providerId,
      AICapability capability,
      StateSetter setDialogState,
      bool isGeneration) async {
    try {
      final defaultModel =
          await AI.getDefaultModelForProvider(providerId, capability);
      if (defaultModel != null) {
        setDialogState(() {
          if (isGeneration) {
            _selectedGenerationModel = defaultModel;
          } else {
            _selectedAnalysisModel = defaultModel;
          }
        });
      }
    } catch (e) {
      debugPrint('Error auto-selecting model: $e');
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

  String _formatProviderName(String providerId) {
    try {
      // Try to get display name from image generation providers first
      final generationProviders =
          AI.getAvailableProviders(AICapability.imageGeneration);
      final providerInfo = generationProviders.firstWhere(
        (provider) => provider.id == providerId,
        orElse: () => AIProvider.empty(providerId),
      );

      if (providerInfo.enabled) {
        return providerInfo.displayName;
      }

      // If not found, try image analysis providers
      final analysisProviders =
          AI.getAvailableProviders(AICapability.imageAnalysis);
      final analysisProviderInfo = analysisProviders.firstWhere(
        (provider) => provider.id == providerId,
        orElse: () => AIProvider.empty(providerId),
      );

      return analysisProviderInfo.displayName;
    } catch (e) {
      return providerId;
    }
  }

  void _showImagePreview(BuildContext context) {
    if (_selectedImageFile == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Background tap to close
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Image preview
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedImageFile!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGeneratedImagePreview(BuildContext context) {
    if (_generatedImageBase64 == null && _generatedImageFileName == null) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Background tap to close
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Image preview
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _generatedImageBase64 != null
                        ? Image.memory(
                            base64Decode(_generatedImageBase64!),
                            fit: BoxFit.contain,
                          )
                        : _generatedImageFileName != null
                            ? FutureBuilder<File>(
                                future: _loadImageFromCache(
                                    _generatedImageFileName!),
                                builder: (aiContext, snapshot) {
                                  if (snapshot.hasData &&
                                      snapshot.data!.existsSync()) {
                                    return Image.file(
                                      snapshot.data!,
                                      fit: BoxFit.contain,
                                    );
                                  } else {
                                    return Container(
                                      padding: const EdgeInsets.all(20),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                },
                              )
                            : Container(),
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade300,
            Colors.red.shade500,
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Error displaying image',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap to retry',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<File> _loadImageFromCache(String filePath) async {
    // filePath now comes as complete path from MediaPersistenceService
    return File(filePath);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
