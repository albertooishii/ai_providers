# Registro de Cambios

## [1.3.0] - 28 de septiembre de 2025 🖼️ AI.IMAGE PULIDO

### ✨ Nuevas Características
- **`AiImageParams` tipado**: `AI.image()` ahora expone un tercer argumento opcional con constantes (`AiImageAspectRatio`, `AiImageFormat`, `AiImageQuality`, etc.) para configurar formato, fondo, fidelidad y seeds sin strings mágicos.
- **Enriquecimiento automático de prompts**: Los proveedores basados exclusivamente en texto (Gemini) convierten los parámetros en instrucciones legibles, manteniendo un comportamiento consistente.

### 🤖 Proveedores
- **OpenAI**: El `aspectRatio` se mapea internamente a los tamaños recomendados (`1024x1024`, `1024x1536`, `1536x1024`) y el `seed` reutiliza respuestas anteriores si empieza por `resp_`.
- **Gemini**: Se preserva el texto original que devuelve el modelo junto con la imagen generada.

### 📚 Documentación
- README actualizado con el nuevo parámetro de `AI.image()`.
- Documentación completa de `AiImageParams` añadida en comentarios del código fuente
- Pre-commit hook actualizado para generar documentación automáticamente

## [1.2.2] - 27 de septiembre de 2025 🎯 NUEVO MODELO AIPROVIDER - BREAKING CHANGES

### 🔥 Breaking Changes
- **API `getAvailableProviders()` actualizada**: Ahora devuelve `List<AIProvider>` en lugar de `List<Map<String, dynamic>>`
- **Acceso estructurado**: Las propiedades del proveedor ahora son `provider.id`, `provider.displayName`, `provider.description`, etc.
- **Migración requerida**: Código existente que use `provider['id']` debe cambiar a `provider.id`

### ✨ Nuevas Características
- **🎯 Modelo AIProvider**: Nueva clase simple con propiedades estructuradas para información de proveedores
- **🔧 API más limpia**: Acceso directo a propiedades sin Maps, mejor intellisense y autocompletado
- **⚡ Mejor documentación**: Todos los métodos y propiedades están documentados en el modelo
- **🛡️ Type Safety**: Mejor seguridad de tipos con el modelo estructurado

### 📋 Detalles Técnicos
- `AIProvider` class con propiedades: `id`, `displayName`, `description`, `capabilities`, `enabled`
- Factory method `AIProvider.fromConfig()` para conversión desde configuración YAML
- Factory method `AIProvider.empty()` para casos de error o fallback
- Método `supportsCapability()` para verificar soporte de capacidades
- Compatibilidad mantenida con `ProviderConfig` interno (sin breaking changes en configuración YAML)

### 🔄 Guía de Migración
**Antes (v1.2.1 y anteriores):**
```dart
final providers = AI.getAvailableProviders(AICapability.textGeneration);
for (final provider in providers) {
  print('${provider['displayName']}: ${provider['description']}');
  if (provider['enabled'] == true) {
    // usar provider['id']
  }
}
```

**Después (v1.2.2+):**
```dart
final providers = AI.getAvailableProviders(AICapability.textGeneration);
for (final provider in providers) {
  print('${provider.displayName}: ${provider.description}');
  if (provider.enabled) {
    // usar provider.id
  }
}
```

### 🧪 Testing
- Todos los tests actualizados para usar el nuevo modelo AIProvider
- Ejemplos actualizados en `/example` con la nueva API
- Zero regressions en funcionalidad existente

## [1.2.1] - 27 de septiembre de 2025 🔒 CAMBIO DE LICENCIA A MPL-2.0

### 🎯 Evolución de la Licencia
- **ACTUALIZACIÓN A MPL-2.0**: Cambio de CC BY-NC-ND 4.0 a Mozilla Public License 2.0
- **Elección Tech-Forward**: Licencia copyleft moderna diseñada para ecosistemas de componentes
- **Amigable Comercialmente**: Uso libre en aplicaciones comerciales manteniendo las modificaciones abiertas
- **Estrategia de Protección**: Asegura que las mejoras al package permanezcan públicamente disponibles

### 🌟 ¿Por qué MPL-2.0?
- **Copyleft a Nivel de Archivo**: Más granular que las licencias tradicionales estilo GPL
- **Amigable para Desarrolladores**: Diseñada por desarrolladores para componentes de software modernos
- **Protección del Ecosistema**: Las modificaciones deben compartirse permitiendo trabajos propietarios más grandes
- **Adopción en la Industria**: Usada por Firefox, ecosistema Rust y empresas tech modernas

### Documentación Mejorada
- **README Simplificado**: Nuevo formato conciso enfocado en uso rápido
- **Guía de Arquitectura**: Sección sobre arquitectura modular y extensibilidad
- **Métodos AI.* Completos**: Tablas organizadas por categoría (inicialización, generación, audio, gestión)
- **Referencias al Ejemplo**: Enlaces directos a la app demo funcional

### Detalles Técnicos
- Texto oficial de licencia MPL-2.0 de Mozilla Foundation
- Campo license actualizado en pubspec.yaml
- Compatibilidad perfecta con pub.dev mantenida
- Cero impacto en funcionalidad existente

## [1.2.0] - 27 de septiembre de 2025 🏆 PUNTAJE PERFECTO PUB.DEV (160/160)

### 🎉 Logro Mayor
- **PUNTAJE PERFECTO PUB.DEV**: Obtenido el máximo 160/160 puntos en análisis de pub.dev
- **100% de Aprobación**: Todos los criterios de puntuación de pub.dev completamente satisfechos

### 🔧 Mejoras de API y Arquitectura
- **Optimización de API**: Superficie de API pública simplificada de 16 a 10 exports esenciales
- **Exports removidos**: `ai_provider_config.dart`, `ai_provider_metadata.dart`, `retry_config.dart`
- **Mejorado**: Organización de exports optimizada para mejor experiencia del desarrollador
- **Mantenido**: Compatibilidad total hacia atrás para métodos facade `AI.*`

### 📋 Mejoras en Puntuación Pub.dev
- **Follow Dart file conventions**: 30/30 (era 10/30) - Cumplimiento perfecto
- **Pass static analysis**: 50/50 (era 40/50) - Cero advertencias/errores
- **Support up-to-date dependencies**: 40/40 (era 20/40) - Compatibilidad completa
- **Provide documentation**: 20/20 - Documentación excelente mantenida
- **Platform support**: 20/20 - Soporte completo multi-plataforma

### 🛠️ Optimizaciones Técnicas
- **Corregido**: Problemas de compatibilidad de límites inferiores de dependencias  
- **Actualizado**: Dependencias de app de ejemplo (file_picker 8.3.7 → 10.3.3)
- **Corregido**: Formato de código para coincidir con guías de estilo Dart
- **Mejorado**: Reconocimiento y cumplimiento de licencia en pub.dev

### 📊 Métricas de Calidad
- **Calidad de Código**: Cero problemas de análisis estático
- **Documentación**: 60.4% cobertura de API con ejemplos comprensivos
- **Compatibilidad**: Testing completo de downgrade/upgrade de dependencias
- **Performance**: Estructura de exports optimizada reduce overhead de compilación

## [1.1.1] - 27 de septiembre de 2025

### Corregido
- Campo license explícito agregado en pubspec.yaml
- Referencias de documentación corregidas en ai_init_config.dart
- Dependencia de test actualizada a versión compatible con Flutter
- Cumplimiento mejorado de puntuación pub.dev

## [1.1.0] - 26 de septiembre de 2025

### Agregado
- API facade unificada con `AI.text()`, `AI.image()`, `AI.speak()`, `AI.listen()`
- Soporte multi-provider: OpenAI, Google Gemini, X.AI Grok, Android Native
- Routing dinámico de providers con fallback automático
- Soporte de configuración YAML
- App de ejemplo con demos para todas las capacidades

### Características
- Generación de texto (GPT-4.1-mini, Gemini 2.5 Flash, Grok-4)
- Generación de imágenes (GPT-4.1-mini, Gemini 2.5 Flash Image Preview)
- Generación y transcripción de audio (Gemini native TTS/STT, Android native, OpenAI)
- Análisis de imágenes (Gemini 2.5 Flash, GPT-4.1-mini, Grok Vision)

## [1.0.0] - 25 de septiembre de 2025

### Agregado
- Versión inicial