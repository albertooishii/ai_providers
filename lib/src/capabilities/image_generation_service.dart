import 'package:ai_providers/ai_providers.dart';
import '../core/ai_provider_manager.dart';
import '../models/additional_params.dart';
import '../utils/logger.dart';

/// 🖼️ ImageGenerationService - Servicio completo de generación de imágenes
///
/// Consolida TODA la funcionalidad de generación de imágenes:
/// - Generación usando AI.image()
/// - Guardado automático con MediaPersistenceService
/// - Diferentes tipos de prompts (general, avatar, artístico)
/// - Gestión de archivos y persistencia
///
/// Reemplaza múltiples servicios con funcionalidad consolidada
class ImageGenerationService {
  ImageGenerationService._();
  static final ImageGenerationService _instance = ImageGenerationService._();
  static ImageGenerationService get instance => _instance;

  /// 🎯 MÉTODO UNIFICADO - usado por AI.image() y casos avanzados
  ///
  /// Versión unificada que combina simplicidad y funcionalidad avanzada.
  /// Acepta parámetros opcionales para casos avanzados pero mantiene simplicidad.
  Future<AIResponse> generateImage(
    final String prompt, [
    final AISystemPrompt? systemPrompt,
    final bool saveToCache = true,
    final AiImageParams? imageParams,
  ]) async {
    try {
      AILogger.d(
        '[ImageGenerationService] 🖼️ Generando imagen: ${prompt.substring(0, prompt.length.clamp(0, 50))}... (saveToCache: $saveToCache)',
      );

      // Crear Context respetando el original y fusionando parámetros de imagen
      final finalContext = _buildFinalContext(systemPrompt, imageParams);

      // Llamar directamente a AIProviderManager con todos los parámetros
      return await AIProviderManager.instance.sendMessage(
        message: prompt,
        systemPrompt: finalContext,
        capability: AICapability.imageGeneration,
        saveToCache: saveToCache,
        additionalParams:
            imageParams != null ? AdditionalParams.image(imageParams) : null,
      );
    } catch (e) {
      AILogger.e('[ImageGenerationService] ❌ Error generando imagen: $e');
      rethrow;
    }
  }

  // === MÉTODOS PRIVADOS ===

  /// 🔄 Construye Context final respetando el original y fusionando parámetros de imagen
  AISystemPrompt _buildFinalContext(
    final AISystemPrompt? originalContext,
    final AiImageParams? imageParams,
  ) {
    // Si no hay context original, crear uno desde parámetros
    if (originalContext == null) {
      return _createContextFromParams(imageParams);
    }

    // Si no hay parámetros de imagen, usar el original sin cambios
    if (imageParams == null) {
      return originalContext;
    }

    // 🔥 FUSIONAR: Respetar original + añadir parámetros de imagen
    final mergedInstructions = <String, dynamic>{
      ...originalContext.instructions,
    };

    // Agregar descripción textual de parámetros de imagen
    final imageRequirements = _buildImageRequirementsText(imageParams);
    if (imageRequirements.isNotEmpty) {
      mergedInstructions['image_parameters'] = imageRequirements;
    }

    // Mantener parámetros estructurados para compatibilidad con providers nativos
    if (imageParams.format != null) {
      mergedInstructions['image_format'] = imageParams.format;
    }
    if (imageParams.background != null) {
      mergedInstructions['background'] = imageParams.background;
    }
    if (imageParams.fidelity != null) {
      mergedInstructions['fidelity'] = imageParams.fidelity;
    }

    return AISystemPrompt(
      context: originalContext.context,
      dateTime: originalContext.dateTime,
      history: originalContext.history,
      instructions: mergedInstructions,
    );
  }

  /// Crea Context desde AiImageParams o valores por defecto
  /// Respeta el context original y concatena parámetros de imagen
  AISystemPrompt _createContextFromParams(final AiImageParams? params) {
    final context = <String, dynamic>{
      'task': 'image_generation',
    };

    final instructions = <String, dynamic>{
      'quality': params?.quality ?? 'high',
      'style': 'Generate high-quality images based on the provided prompt.',
      'format': 'Create visually appealing and accurate representations.',
    };

    // ✨ Convertir AiImageParams a descripción textual para providers basados en prompt
    if (params != null) {
      final imageRequirements = _buildImageRequirementsText(params);
      if (imageRequirements.isNotEmpty) {
        instructions['image_parameters'] = imageRequirements;
      }

      // Mantener parámetros estructurados para compatibilidad
      if (params.format != null) instructions['image_format'] = params.format;
      if (params.background != null) {
        instructions['background'] = params.background;
      }
      if (params.fidelity != null) instructions['fidelity'] = params.fidelity;
    }

    return AISystemPrompt(
      context: context,
      dateTime: DateTime.now(),
      instructions: instructions,
    );
  }

  /// 🖼️ Convierte AiImageParams a descripción textual para providers basados en prompt
  String _buildImageRequirementsText(final AiImageParams params) {
    final requirements = <String>[];

    // Aspect Ratio -> Descripción natural
    if (params.aspectRatio != null) {
      final aspectRatioDesc = _getAspectRatioDescription(params.aspectRatio!);
      if (aspectRatioDesc.isNotEmpty) {
        requirements.add('Generate with $aspectRatioDesc aspect ratio');
      }
    }

    // Format -> Descripción de calidad de output
    if (params.format != null) {
      requirements
          .add('Output format should be ${params.format!.toUpperCase()}');
    }

    // Quality -> Descripción de nivel de detalle
    if (params.quality != null) {
      final qualityDesc = _getQualityDescription(params.quality!);
      if (qualityDesc.isNotEmpty) {
        requirements.add(qualityDesc);
      }
    }

    // Background -> Descripción de fondo
    if (params.background != null) {
      requirements.add('Background should be ${params.background}');
    }

    // Fidelity -> Descripción de adherencia al prompt
    if (params.fidelity != null) {
      final fidelityDesc = _getFidelityDescription(params.fidelity!);
      if (fidelityDesc.isNotEmpty) {
        requirements.add(fidelityDesc);
      }
    }

    return requirements.isEmpty ? '' : '${requirements.join('. ')}.';
  }

  /// Convierte aspectRatio a descripción legible
  String _getAspectRatioDescription(final String aspectRatio) {
    switch (aspectRatio) {
      case AiImageAspectRatio.square:
        return 'square (1:1)';
      case AiImageAspectRatio.portrait:
        return 'portrait (3:4)';
      case AiImageAspectRatio.landscape:
        return 'landscape (4:3)';
      case AiImageAspectRatio.auto:
        return 'automatic aspect ratio';
      default:
        return aspectRatio;
    }
  }

  /// Convierte quality a descripción de detalle
  String _getQualityDescription(final String quality) {
    switch (quality) {
      case AiImageQuality.standard:
        return 'Generate with standard quality and good detail';
      case AiImageQuality.high:
        return 'Generate with high quality, rich detail, and professional appearance';
      case AiImageQuality.ultra:
        return 'Generate with ultra-high quality, maximum detail, and photorealistic precision';
      // Compatibilidad con valores no estándar
      case 'low':
        return 'Generate with basic quality and moderate detail';
      default:
        return 'Generate with $quality quality';
    }
  }

  /// Convierte fidelity a descripción de adherencia
  String _getFidelityDescription(final String fidelity) {
    switch (fidelity) {
      case AiImageFidelity.low:
        return 'Allow creative interpretation with loose adherence to the prompt';
      case AiImageFidelity.medium:
        return 'Balance creative interpretation with moderate prompt adherence';
      case AiImageFidelity.high:
        return 'Maintain strict adherence to the prompt with minimal creative deviation';
      default:
        return 'Maintain $fidelity fidelity to the prompt';
    }
  }
}

/// Tipos de imagen soportados (mantenidos para compatibilidad futura)
enum ImageType {
  general,
  avatar,
  artistic,
  photorealistic,
}

/// Calidades de imagen soportadas (mantenidos para compatibilidad futura)
enum ImageQuality {
  standard,
  high,
  ultra,
}
