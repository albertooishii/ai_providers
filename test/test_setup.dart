/// Test setup específico para tests de ai_providers
/// Proporciona configuración de entorno aislada para tests
library;

import 'package:ai_providers/src/core/config_loader.dart';

/// Inicializa el entorno de test para ai_providers con configuración mockeada
Future<void> initializeTestEnvironment() async {
  // Configurar el sistema para saltar la validación de variables de entorno
  // Esto permite que los tests funcionen sin archivos .env reales
  AIProviderConfigLoader.skipEnvironmentValidation = true;
}
