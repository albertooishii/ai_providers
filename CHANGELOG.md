# Registro de Cambios

## [1.4.2] - 30 de septiembre de 2025 🔧 FIX: Corrección Message History Context

### 🐛 Bug Fixes Críticos
- **Message Context Fix**: El mensaje del usuario ahora se agrega correctamente al `aiContext.history`
- **Historial completo**: Los providers reciben el contexto completo incluyendo el mensaje actual
- **API consistency**: Flujo completo desde `AI.text()` hasta provider funciona correctamente

### 🔧 Mejoras Técnicas
- **AIProviderManager**: Agregado mensaje de usuario al historial antes de enviar al provider
- **Type Safety**: Corrección de tipos en `List<Map<String, dynamic>>` para history

### ✅ Impacto
- **Conversaciones funcionales**: Los mensajes del usuario ahora aparecen en las requests
- **Mejor UX**: Las respuestas de IA tienen el contexto completo del mensaje
- **Sin breaking changes**: API pública permanece inalterada

## [1.4.1] - 30 de septiembre de 2025 ⚡ OPTIMIZACIÓN: Eliminación de History Duplicado

### ⚡ Optimizaciones de Performance
- **History unificado**: Eliminado parámetro `history` duplicado en providers
- **Menos memoria**: Los providers ahora usan únicamente `aiContext.history`
- **API más limpia**: Interface simplificada sin parámetros redundantes
- **Cache optimizado**: Keys de cache usan `aiContext.history` directamente

### 🔧 Mejoras Técnicas
- **Providers actualizados**: OpenAI, Google, XAI y Android Native providers simplificados
- **BaseProvider mejorado**: Signatura `sendMessage` sin parámetro `history` duplicado
- **AIProviderManager optimizado**: Eliminada construcción de history redundante
- **Mejor eficiencia**: Una sola fuente de verdad para el historial de conversación

### ✅ Compatibilidad
- **Sin breaking changes**: La API pública permanece igual
- **Tests completos**: 16/16 tests ai_providers + 63/63 tests ai_chan pasando
- **Análisis limpio**: 0 errores de analyzer en ambos proyectos

## [1.4.0] - 30 de septiembre de 2025 🔄 REFACTOR BREAKING: AISystemPrompt → AIContext

### 💥 Breaking Changes
- **Modelo renombrado**: `AISystemPrompt` → `AIContext` para mayor claridad conceptual
- **Archivo renombrado**: `ai_system_prompt.dart` → `ai_context.dart`
- **Parámetros actualizados**: `systemPrompt` → `aiContext` en APIs de funciones
- **Import actualizado**: `import 'package:ai_providers/ai_providers.dart'` sigue funcionando (re-exportado)

### 🚀 Mejoras Arquitecturales
- **Concepto más claro**: AIContext representa el contexto completo de conversación, no solo system prompt
- **History real**: AIProviderManager ahora usa `aiContext.history` directamente en lugar de generar historia falsa
- **Naming consistency**: Separación clara entre `context` (propiedad del modelo) y `aiContext` (parámetro de función)
- **Flutter compatibility**: Evita conflictos de nombres con `BuildContext` de Flutter

### 🔧 Mejoras Técnicas
- **Mejor abstracción**: AIContext encapsula contexto completo: historia, instrucciones, metadatos y contexto de aplicación
- **API más intuitiva**: Los nombres reflejan mejor la funcionalidad real del modelo
- **Retrocompatibilidad**: Aunque breaking, la migración es simple (find & replace)

### 📚 Migración Requerida
```dart
// ANTES (v1.3.x)
final systemPrompt = AISystemPrompt(context: profile, ...);
await AI.text(prompt, systemPrompt);

// AHORA (v1.4.0+)
final aiContext = AIContext(context: profile, ...);  
await AI.text(prompt, aiContext);
```

## [1.3.3] - 29 de septiembre de 2025 🧹 LIMPIEZA DE DEPENDENCIAS + 🚀 OPTIMIZACIÓN APIKEY

### 🚀 Optimizaciones de Performance
- **ApiKeyManager inteligente**: Elimina rotación inútil de API keys cuando solo hay una configurada
- **Failover más rápido**: Reduce tiempo de fallback de ~3-4 segundos a inmediato en casos de una sola key
- **Mejor manejo de errores**: Excepciones específicas cuando se agotan todas las API keys
- **Control de flujo mejorado**: `markCurrentKeyFailed()` y `markCurrentKeyExhausted()` ahora devuelven `bool`

### 🔧 Mejoras Técnicas
- **base_provider.handleApiError()**: Actualizado para manejar nuevos valores de retorno booleanos
- **Providers actualizados**: OpenAI, Google y XAI providers con mejor manejo de errores
- **Logging mejorado**: Mensajes más específicos para debugging de API key exhaustion

### 🗑️ Dependencias Removidas
- **`flutter_secure_storage`**: Eliminada dependencia innecesaria que no se usaba en el código
- **Compilación mejorada**: Resueltos problemas de compilación en Linux por dependencias no utilizadas
- **Tamaño reducido**: Menos dependencias = instalación más rápida y menor tamaño

### 🔧 Correcciones
- **Example compilando**: El proyecto example ahora compila sin problemas en todas las plataformas
- **Dependencias limpias**: Solo dependencias realmente necesarias

## [1.3.2] - 28 de septiembre de 2025 ✨ AIAUDIOPARAMS MEJORADO - PCM POR DEFECTO

### 🔧 Mejoras en API
- **`AiAudioParams.audioFormat` con valor por defecto**: Ahora es `String` (no nullable) con valor por defecto `'pcm'`
- **Uso simplificado**: `AiAudioParams()` sin parámetros funciona perfectamente para casos comunes
- **PCM universal**: Formato recomendado compatible con todos los proveedores

### ⚡ Breaking Changes Menores
- `audioFormat` cambió de `String?` a `String` con valor por defecto `'pcm'`
- Eliminadas verificaciones de null innecesarias en providers

### 📚 Documentación
- Comentarios actualizados para reflejar el comportamiento por defecto
- Ejemplos simplificados sin especificar formato cuando no es necesario

## [1.3.1] - 28 de septiembre de 2025 🎙️ SIMPLIFICACIÓN AUDIO - TRANSCRIPTION CLEANUP

### 🧹 Simplificación y Mejoras
- **Eliminado `TranscribeInstructions`**: Simplificamos la arquitectura de audio eliminando la clase `TranscribeInstructions` que tenía características no utilizadas (anti-hallucination). Ahora `AI.listen()` usa directamente `AIContext`.
- **`AiAudioParams` clarificado**: La documentación ahora especifica claramente que `AiAudioParams` es exclusivamente para **síntesis de voz (TTS)** con `AI.speak()`, no para transcripción.
- **Demo actualizado**: El ejemplo `audio_demo_screen.dart` ahora usa `AiAudioParams` en lugar de las obsoletas `SynthesizeInstructions`.

### 🔧 Cambios Técnicos
- **API transcripción simplificada**: `AI.listen()` y `AI.transcribe()` ahora reciben solo `AIContext`
- **Proveedores actualizados**: OpenAI y Google providers ajustados para usar `AIContext` directamente en transcripción
- **Documentación mejorada**: `AiAudioParams` ahora documenta correctamente solo parámetros TTS reales soportados por cada proveedor

### 📚 Documentación
- README actualizado para reflejar el uso correcto de `AiAudioParams` vs `AIContext`
- Comentarios de código clarificados para distinguir entre TTS y STT
- Eliminadas referencias confusas a STT en `AiAudioParams`

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