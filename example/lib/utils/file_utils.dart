import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// 🛠️ Utilidades para manejo de archivos en la app de ejemplo
class FileUtils {
  /// 📁 Selecciona una imagen desde el dispositivo
  /// Retorna null si el usuario cancela la selección
  static Future<File?> pickImageFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }

      return null;
    } catch (e) {
      throw Exception('Error selecting image: $e');
    }
  }

  /// 🔄 Convierte un archivo de imagen a base64
  static Future<String> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      throw Exception('Error converting file to base64: $e');
    }
  }

  /// 🏷️ Obtiene el MIME type de una imagen basado en la extensión
  static String getImageMimeType(File file) {
    final extension = file.path.split('.').last.toLowerCase();

    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  /// 📊 Información completa de una imagen seleccionada
  static Future<ImageInfo> getImageInfo(File file) async {
    final base64 = await fileToBase64(file);
    final mimeType = getImageMimeType(file);
    final sizeBytes = await file.length();

    return ImageInfo(
      file: file,
      base64: base64,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      fileName: file.path.split('/').last,
    );
  }

  /// 📏 Formatea el tamaño de archivo a texto legible
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// ✅ Valida si un archivo es una imagen válida
  static bool isValidImageFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    const validExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'];
    return validExtensions.contains(extension);
  }

  /// 📐 Obtiene las dimensiones estimadas de una imagen (solo para mostrar, no preciso)
  static String getEstimatedDimensions(int sizeBytes) {
    // Estimación muy básica basada en el tamaño del archivo
    if (sizeBytes < 100000) return '~800x600';
    if (sizeBytes < 500000) return '~1280x720';
    if (sizeBytes < 2000000) return '~1920x1080';
    return '~2560x1440 or higher';
  }
}

/// 📋 Información completa de una imagen
class ImageInfo {
  final File file;
  final String base64;
  final String mimeType;
  final int sizeBytes;
  final String fileName;

  const ImageInfo({
    required this.file,
    required this.base64,
    required this.mimeType,
    required this.sizeBytes,
    required this.fileName,
  });

  /// 📏 Tamaño formateado del archivo
  String get formattedSize => FileUtils.formatFileSize(sizeBytes);

  /// 📐 Dimensiones estimadas
  String get estimatedDimensions => FileUtils.getEstimatedDimensions(sizeBytes);

  /// ✅ Es una imagen válida
  bool get isValid => FileUtils.isValidImageFile(file);
}
