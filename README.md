# 🤖 AI Providers para Flutter

> 🇪🇸 **¿No hablas español?** Usa la IA para traducir esta documentación a tu idioma. Después de todo, este es un paquete de IA 😉  
> 🇬🇧 **Don't speak Spanish?** Use AI to translate this documentation to your language. After all, this is an AI package 😉

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License: CC BY-NC-ND 4.0](https://img.shields.io/badge/License-CC%20BY--NC--ND%204.0-lightgrey.svg?style=for-the-badge)](https://creativecommons.org/licenses/by-nc-nd/4.0/)

> **SDK Profesional de IA para Flutter** - Una arquitectura unificada y extensible para integrar múltiples proveedores de IA (OpenAI, Google AI, XAI, Android Nativo) con caché avanzado, lógica de reintentos y monitoreo integral.

## 🎯 **Demostración Profesional**

Este paquete demuestra patrones arquitectónicos avanzados de Flutter/Dart y expertise en integración de IA:

- **🏗️ Arquitectura Limpia** - Patrón Facade con Services especializados
- **🔧 DI Avanzado** - Resolución dinámica de proveedores y enrutamiento basado en capacidades  
- **⚡ Rendimiento** - Caché inteligente, pool de conexiones, mecanismos de reintento
- **🧪 Aseguramiento de Calidad** - 35+ pruebas integrales, protección arquitectónica
- **🔒 Seguridad Empresarial** - Gestión de claves API, limitación de velocidad, monitoreo

---

## 🚀 **Inicio Ultra-Rápido**

### Instalación

```yaml
dependencies:
  ai_providers: ^1.0.0
```

### API Súper Simple

```dart
import 'package:ai_providers/ai_providers.dart';

// Inicializar el sistema de IA
await AI.initialize();

// 💬 Generar texto - ¡Sin parámetros complicados!
final respuesta = await AI.text('Explícame qué es Flutter');

// 🖼️ Generar imágenes - ¡Un solo parámetro!
final imagen = await AI.image('Un gato programador escribiendo código');

// 👁️ Analizar imágenes - ¡Completamente automático!
final analisis = await AI.vision(imagenBase64);

// 🎤 Texto a voz - ¡Directo con controles!
final audio = await AI.speak('¡Hola, soy tu asistente de IA!');

// 🎧 Voz a texto - ¡Múltiples opciones!
final transcripcion = await AI.listen();   // Grabar y transcribir (detección automática de silencio)
```

## 🏗️ **Arquitectura Revolucionaria**

### Patrón Facade con Services Especializados

```dart
// ═══════════════════════════════════════════════════════════════════════════════
// 🎮 MÉTODOS DIRECTOS (Capability Automático - Súper Fácil)
// ═══════════════════════════════════════════════════════════════════════════════
AI.text()     // 💬 Generación de texto y chat
AI.image()    // 🖼️ Generación de imágenes (DALL-E, Stable Diffusion, etc.)
AI.vision()   // 👁️ Análisis de imágenes y OCR
AI.speak()    // 🎤 Síntesis de voz (TTS)
AI.listen()   // 🎧 Grabar y transcribir con detección automática de silencio

// ═══════════════════════════════════════════════════════════════════════════════
// 🎛️ CONTROL Y UTILIDADES (Métodos de Control y Funciones Avanzadas)
// ═══════════════════════════════════════════════════════════════════════════════
AI.stopSpeak()     // 🛑 Detener reproducción de audio/TTS
AI.pauseSpeak()    // ⏸️ Pausar reproducción de audio/TTS
AI.stopListen()    // 🛑 Detener grabación en curso
AI.transcribe()    // 🎧 Transcribir audio existente/STT
AI.createConversation() // 💬 Crear conversaciones híbridas con streams

// ═══════════════════════════════════════════════════════════════════════════════
// 🗂️ GESTIÓN DE CACHÉ Y SISTEMA (Administración y Monitoreo)
// ═══════════════════════════════════════════════════════════════════════════════
AI.clearTextCache()      // 🧹 Limpiar respuestas de texto en memoria
AI.clearAudioCache()     // 🧹 Limpiar archivos de audio guardados
AI.clearImageCache()     // 🧹 Limpiar imágenes generadas guardadas
AI.clearModelsCache()    // 🧹 Limpiar listas de modelos persistidos

// ═══════════════════════════════════════════════════════════════════════════════
// ⚙️ CONFIGURACIÓN Y INFORMACIÓN (Gestión de Proveedores y Modelos)
// ═══════════════════════════════════════════════════════════════════════════════
AI.getAvailableModels()        // 🎯 Obtener modelos de un proveedor específico
AI.getAvailableProviders()     // 🎛️ Obtener proveedores para una capability
AI.getCurrentProvider()        // 🎛️ Proveedor activo para una capability
AI.getCurrentModel()           // 🎯 Modelo actual para una capability
AI.setModel()                  // 🎯 Cambiar modelo para proveedor/capability
AI.getVoicesForProvider()      // 🗣️ Obtener voces disponibles de un proveedor
AI.getCurrentVoiceForProvider() // 🎤 Voz configurada para un proveedor
AI.setSelectedVoiceForProvider() // 🎤 Establecer voz para un proveedor
AI.isInitialized              // ✅ Estado de inicialización del sistema
AI.debugInfo                  // 🐛 Información técnica detallada del SDK

// ═══════════════════════════════════════════════════════════════════════════════
// 🔧 MÉTODO UNIVERSAL (Capability Manual - Casos Complejos)
// ═══════════════════════════════════════════════════════════════════════════════
AI.generate()      // 🔧 Método universal con control total

// ❌ Complejidad interna completamente oculta
// TextGenerationService, ImageGenerationService, etc. - disponibles para uso avanzado
```

### Arquitectura en Capas

```
🎮 AI.* (API Pública)
    ↓ delega a
🔧 Services Especializados
    ↓ llaman a  
⚙️ AIProviderManager
    ↓ comunica con
🌐 Providers (OpenAI, Google, XAI, etc.)
```

### Registro Avanzado de Proveedores

```dart
// Resolución dinámica basada en capacidades
final proveedores = AI.getAvailableProviders(AICapability.textGeneration);

// Fallback automático y balanceo de carga
final respuesta = await AI.text('Tu mensaje');
// → Intenta Google → Si falla, OpenAI → Si falla, XAI (según capability_preferences)
```

### Services de Grado Empresarial

```dart
// Caché inteligente con TTL (interno - usado automáticamente)
// CompleteCacheService.instance - gestión automática de caché

// Lógica de reintentos con backoff exponencial (interno)
// IntelligentRetryService - reintentos automáticos en fallos

// Pool de conexiones HTTP optimizado (interno)
// HttpConnectionPool - gestión automática de conexiones
```

## 🎯 **Arquitectura Basada en Capacidades**

### API Unificada con Múltiples Capacidades

```dart
// ═══════════════════════════════════════════════════════════════════════════════
// 🎮 MÉTODOS DIRECTOS (99% de casos - súper simple)
// ═══════════════════════════════════════════════════════════════════════════════
await AI.text('¿Cómo está el clima?');
await AI.image('Un paisaje montañoso');
await AI.vision(imagenBase64); // prompt opcional como segundo parámetro
await AI.speak('Bienvenido a la aplicación');
final transcripcion = await AI.listen(); // Graba automáticamente hasta silencio

// ═══════════════════════════════════════════════════════════════════════════════
// 🎛️ CONTROL Y UTILIDADES
// ═══════════════════════════════════════════════════════════════════════════════
// Control de reproducción de audio
await AI.pauseSpeak(); // Pausar TTS en cualquier momento
await AI.stopSpeak();  // Parar TTS completamente

// Control de grabación y transcripción
final transcrito = await AI.transcribe(audioBase64);   // Transcripción directa
await AI.stopListen(); // Parar grabación en curso

// Conversaciones avanzadas
final conversacion = AI.createConversation();

// ═══════════════════════════════════════════════════════════════════════════════
// 🔧 MÉTODO UNIVERSAL (1% de casos - control total)
// ═══════════════════════════════════════════════════════════════════════════════
await AI.generate(
  message: 'Analiza este documento complejo',
  systemPrompt: AISystemPrompt(...),
  capability: AICapability.textGeneration,
  imageBase64: documentoEscaneado,
);
```

### Selección Dinámica de Proveedores

```dart
// El sistema selecciona automáticamente el mejor proveedor basándose en:
// 1. Soporte de capacidad
// 2. Prioridad del proveedor
// 3. Límites de velocidad
// 4. Estado de salud
// 5. Historial de tiempo de respuesta
// 6. Preferencias del usuario

final respuesta = await AI.text('Tu mensaje');
// → Enruta internamente al mejor proveedor disponible según capability_preferences
```

## 🔧 **Configuración Avanzada**

### Configuración Basada en YAML

```yaml
# assets/ai_providers_config.yaml
version: "1.0"

# Global settings
global_settings:
  max_retries: 3
  retry_delay_seconds: 1
  tts_cache_enabled: true
  tts_cache_duration_hours: 24
  log_level: "debug"

# AI Providers Configuration
ai_providers:
  openai:
    enabled: true
    display_name: "OpenAI GPT"
    description: "OpenAI models with advanced text generation, image analysis, and creation"
    
    capabilities:
      - text_generation
      - image_generation
      - image_analysis
      - audio_generation
      - audio_transcription
      - realtime_conversation
      - function_calling
    
    defaults:
      text_generation: "gpt-4.1-mini"
      image_generation: "gpt-4.1-mini"
      image_analysis: "gpt-4.1-mini"
      audio_generation: "gpt-4o-mini-tts"
      audio_transcription: "gpt-4o-mini-transcribe"
      realtime_conversation: "gpt-realtime"
    
    voices:
      default: "marin"
      tts_default: "marin"
    
    rate_limits:
      requests_per_minute: 3500
      tokens_per_minute: 350000
      
  google:
    enabled: true
    display_name: "Google Gemini"
    description: "Google Gemini models with advanced multimodal capabilities including native TTS/STT"
    
    capabilities:
      - text_generation
      - image_generation
      - image_analysis
      - audio_generation
      - audio_transcription
      - realtime_conversation
      - function_calling
    
    defaults:
      text_generation: "gemini-2.5-flash"
      image_generation: "gemini-2.5-flash-image-preview"
      image_analysis: "gemini-2.5-flash"
      audio_generation: "gemini-2.5-flash-tts"
      audio_transcription: "gemini-2.5-flash"
      realtime_conversation: "gemini-2.5-flash"
    
    voices:
      default: "Puck"
      tts_default: "Puck"

# Capability-specific provider preferences
capability_preferences:
  text_generation:
    primary: "google"
    fallbacks:
      - "openai"
      - "xai"
  
  image_generation:
    primary: "openai"
    fallbacks:
      - "google"
  
  audio_generation:
    primary: "google"
    fallbacks:
      - "android_native"
      - "openai"
```

### Configuración Programática

```dart
// Configuración simple con claves API
final config = AIInitConfig(
  apiKeys: {
    'openai': ['tu-clave-openai-1', 'tu-clave-openai-2'],
    'google': ['tu-clave-google'],
    'xai': ['tu-clave-xai'],
  },
);

await AI.initialize(config);

// O usar configuración vacía (carga desde .env automáticamente)
await AI.initialize(AIInitConfig.empty());

// La configuración de proveedores, capacidades y fallbacks
// se maneja através del archivo ai_providers_config.yaml
```

## 💎 **Simplicidad Ultra-Avanzada**

### SystemPrompts Inteligentes Automáticos

```dart
// 😍 Súper Simple - SystemPrompts automáticos optimizados
await AI.text('Explica la relatividad');
// → Usa SystemPrompt optimizado para explicaciones

await AI.image('Un robot amigable');  
// → Usa SystemPrompt optimizado para generación de imágenes

await AI.vision(fotoBase64);
// → Usa SystemPrompt "Describe esta imagen detalladamente"

// 🔧 Control Total - Cuando necesites personalización
await AI.text(
  'Explica como si tuviera 5 años',
  AISystemPrompt(
    context: {'user': 'niño de 5 años', 'nivel': 'principiante'},
    dateTime: DateTime.now(),
    instructions: {
      'rol': 'Maestro de primaria experto en explicaciones simples',
      'estilo': 'Usa analogías y ejemplos divertidos',
      'idioma': 'español',
      'formato': 'Respuestas cortas y claras'
    },
  )
);
```

### Uso Avanzado con Services

```dart
// Para casos donde necesitas control total sobre la funcionalidad
import 'package:ai_providers/ai_providers.dart';

// Generación de texto con historial de conversación
final servicio = TextGenerationService.instance;
final respuesta = await servicio.generateWithHistory(
  'Continúa la historia',
  systemPrompt: AISystemPrompt(
    context: {'task': 'story_continuation'},
    dateTime: DateTime.now(),
    instructions: {'role': 'Narrador creativo'},
  ),
  conversationHistory: conversacionPrevia,
);

// Generación de imagen con guardado automático
final servicioImagen = ImageGenerationService.instance;
final resultado = await servicioImagen.generateAndSave(
  'Logo futurista para empresa tech',
  type: ImageType.general,
  quality: ImageQuality.high,
);

// Audio con reproducción automática
final servicioAudio = AudioGenerationService.instance;
await servicioAudio.synthesizeAndPlay(
  'Notificación importante',
);

// Análisis de imagen con configuración avanzada  
final servicioAnalisis = ImageAnalysisService.instance;
final analisis = await servicioAnalisis.analyze(
  imagenBase64,
  'Identifica todos los objetos y sus posiciones',
  AISystemPrompt(
    context: {'task': 'object_detection'},
    dateTime: DateTime.now(),
    instructions: {'style': 'Detallado y preciso'},
  ),
  'image/jpeg',
);
```

## 🧪 **Aseguramiento de Calidad**

### Suite de Pruebas Integral

- **35+ Pruebas Unitarias** - Cobertura completa de todos los componentes
- **Pruebas Arquitectónicas** - Garantiza integridad del patrón facade
- **Pruebas de Integración** - Validación de interacción real con proveedores
- **Pruebas de Seguridad** - Protección de claves API y prevención de bypass

```bash
flutter test
# → Todas las pruebas pasan con protección arquitectónica
```

### Protección Anti-Bypass

```dart
// ✅ Esto compila y funciona - API autorizada
final respuesta = await AI.text('Hola mundo');
final imagen = await AI.image('Un paisaje');

// ❌ Esto NO compila - acceso interno bloqueado
final manager = AIProviderManager.instance; // Error de compilación
final proveedor = OpenAIProvider(); // Error de compilación
final registro = ProviderRegistry.instance; // No exportado
```

## 📊 **Características de Rendimiento**

### Caché Inteligente

```dart
// Caché automático de respuestas con TTL configurable
final respuesta1 = await AI.text('¿Qué es Flutter?'); // Llamada a API
final respuesta2 = await AI.text('¿Qué es Flutter?'); // Respuesta en caché
print('Segunda respuesta en ~5ms desde caché');
```

### Pool de Conexiones

```dart
// Pool de conexiones HTTP (interno - automático)
// HttpConnectionPool gestiona conexiones automáticamente
// Configuración optimizada para múltiples proveedores simultáneos
```

### Lógica de Reintentos con Circuit Breaker

```dart
// Reintentos automáticos con backoff exponencial (interno)
// IntelligentRetryService maneja reintentos automáticamente
// Configurado en global_settings.max_retries del YAML
```

## 🔒 **Seguridad y Monitoreo**

### Gestión Automática de Claves API

```dart
// Configuración segura de múltiples claves por proveedor
final config = AIInitConfig(
  apiKeys: {
    'openai': ['clave-principal', 'clave-respaldo-1', 'clave-respaldo-2'],
    'google': ['clave-gemini-1', 'clave-gemini-2'],
  },
);

// Rotación automática en caso de fallos o límites de velocidad
// ApiKeyManager maneja la rotación internamente sin intervención manual
```

### Monitoreo de Rendimiento

```dart
// Información del sistema disponible
final debugInfo = AI.debugInfo;
print('Estado del sistema: $debugInfo');

// Verificación de estado de inicialización
if (AI.isInitialized) {
  print('✅ Sistema AI listo');
} else {
  print('⚠️ Sistema AI no inicializado');
}
```

### Limitación de Velocidad Automática

```yaml
# Configuración en ai_providers_config.yaml
ai_providers:
  openai:
    rate_limits:
      requests_per_minute: 3500
      tokens_per_minute: 350000
  google:
    rate_limits:
      requests_per_minute: 2000
      tokens_per_minute: 1000000
```

## 🛠️ **Extensibilidad**

### Agregar Proveedores via Configuración

```yaml
# En ai_providers_config.yaml - agregar nuevos proveedores
ai_providers:
  mi_proveedor_custom:
    enabled: true
    display_name: "Mi Proveedor IA"
    description: "Proveedor personalizado para casos específicos"
    
    capabilities:
      - text_generation
      - image_analysis
    
    api_settings:
      base_url: "https://mi-api.com"
      version: "v1"
      authentication_type: "bearer_token"
      required_env_keys:
        - "MI_API_KEY"
    
    defaults:
      text_generation: "mi-modelo-1"
      image_analysis: "mi-modelo-vision"

# Configurar preferencias para usar tu proveedor
capability_preferences:
  text_generation:
    primary: "mi_proveedor_custom"
    fallbacks:
      - "google"
      - "openai"
```

### Capacidades del Sistema

```dart
// Capacidades disponibles actualmente
enum AICapability {
  textGeneration,      // Generación de texto/chat
  imageGeneration,     // Creación de imágenes
  imageAnalysis,       // Análisis/visión de imágenes  
  audioGeneration,     // Síntesis de voz (TTS)
  audioTranscription,  // Transcripción de voz (STT)
  realtimeConversation,// Conversaciones en tiempo real (ver ROADMAP)
  // ... más capacidades según necesidad
}
```

## 🎯 **Casos de Uso**

### Aplicaciones de Chatbot

```dart
// Conversación híbrida con TTS/STT automático
final conversacion = AI.createConversation();
await conversacion.startConversation(
  AISystemPrompt(...),
  initialMessage: '¡Hola! ¿En qué puedo ayudarte?'
);
await conversacion.sendTextMessage('Hola, ¿cómo estás?');

// Conversación con historial persistente
final servicio = TextGenerationService.instance;
final respuesta = await servicio.generateWithHistory(
  'Continúa nuestra conversación anterior',
  systemPrompt: AISystemPrompt(
    context: {'conversation_mode': true},
    dateTime: DateTime.now(),
    instructions: {'role': 'Asistente conversacional'},
  ),
  conversationHistory: historialGuardado,
);
```

### Generación de Contenido

```dart
// Artículo completo
final articulo = await AI.text(
  'Escribe un artículo de 1000 palabras sobre las ventajas de Flutter para desarrollo móvil'
);

// Imagen para el artículo
final imagenArticulo = await AI.image(
  'Ilustración moderna y profesional mostrando desarrollo móvil con Flutter'
);

// Narración del artículo
final narracion = await AI.speak(articulo.text);
```

### IA Multimodal

```dart
// Análisis completo de imagen con descripción
final descripcion = await AI.vision(
  imagenBase64,
  'Analiza este documento e identifica todos los elementos importantes'
);

// Generación de contenido basado en la imagen
final contenido = await AI.generate(
  message: 'Crea una historia basada en lo que ves en esta imagen',
  systemPrompt: AISystemPrompt(...),
  capability: AICapability.textGeneration,
  imageBase64: imagenBase64,
);

// Conversación sobre la imagen usando el texto previo como contexto
final conversacion = await AI.text(
  'Basándote en esta descripción: "${descripcion.text}", explícame más detalles'
);
```

### Ejemplos Completos

Para ver implementaciones completas y casos de uso reales, revisa la **carpeta `example/`** que incluye:

- **🖥️ Aplicación Demo Completa** - Interfaz Flutter funcional
- **💬 Chat/Texto** - `text_demo_screen.dart` - Ejemplos de AI.text() con diferentes proveedores
- **🖼️ Generación de Imágenes** - `image_demo_screen.dart` - AI.image() y AI.vision()
- **🎤 Audio/TTS/STT** - `audio_demo_screen.dart` - AI.speak() y AI.listen()
- **🔧 Gestión Avanzada** - `advanced_demo_screen.dart` - Administración del sistema y caché
- **⚙️ Configuración Real** - `assets/ai_providers_config.yaml` - YAML de configuración completo

```bash
# Configurar tus claves API
cd example/
cp .env.example .env
# Edita .env con tus claves API reales

# Ejecutar la aplicación demo
flutter run
```

## 🏆 **¿Por Qué Esta Arquitectura?**

### Principios de Ingeniería de Software Profesional

1. **Separación de Responsabilidades** - Cada componente tiene una responsabilidad única
2. **Inversión de Dependencias** - Los módulos de alto nivel no dependen de detalles de bajo nivel  
3. **Principio Abierto/Cerrado** - Abierto para extensión, cerrado para modificación
4. **Segregación de Interfaces** - Los clientes no dependen de interfaces no utilizadas
5. **Responsabilidad Única** - Cada clase tiene una sola razón para cambiar

### Patrones Empresariales Implementados

- **Patrón Facade** - Interfaz simplificada para subsistema complejo
- **Patrón Strategy** - Algoritmos de proveedores intercambiables
- **Patrón Registry** - Descubrimiento y registro dinámico de servicios
- **Circuit Breaker** - Tolerancia a fallos y resiliencia
- **Observer Pattern** - Monitoreo y alertas dirigidas por eventos
- **Singleton Pattern** - Gestión de instancias únicas de servicios

### Ventajas Arquitectónicas

- ✅ **API Ultra-Simple** - Una línea para cada operación común
- ✅ **Escalabilidad** - Agregar nuevos proveedores sin cambiar código existente
- ✅ **Mantenibilidad** - Responsabilidades claras y código organizado
- ✅ **Testabilidad** - Cada capa se puede probar independientemente
- ✅ **Flexibilidad** - Uso básico simple, uso avanzado con control total
- ✅ **Robustez** - Fallbacks automáticos, reintentos, circuit breakers

## 🔄 **Migración desde Otras Librerías**

### Desde OpenAI Dart

```dart
// ❌ Antes (OpenAI Dart)
final client = OpenAI.instance.build(token: 'tu-token');
final request = ChatCompleteText(
  model: GptTurbo0301ChatModel(), 
  messages: [Messages(role: Role.user, content: 'Hola')],
);
final response = await client.onChatCompletion(request: request);

// ✅ Ahora (AI Providers)
await AI.initialize(); // Una sola vez
final response = await AI.text('Hola');
```

### Desde Google AI Dart

```dart
// ❌ Antes (Google AI)
final model = GenerativeModel(model: 'gemini-pro', apiKey: 'tu-key');
final content = [Content.text('Hola')];
final response = await model.generateContent(content);

// ✅ Ahora (AI Providers)
final response = await AI.text('Hola');
// Automáticamente usa Google si OpenAI falla
```

### Ventajas de Migrar

- 🎯 **API Unificada** - Un solo código para múltiples proveedores
- 🔄 **Fallbacks Automáticos** - Sin interrupciones si un proveedor falla
- 💰 **Optimización de Costos** - Distribución inteligente de peticiones
- 🚀 **Simplicidad** - 90% menos líneas de código
- 🔧 **Flexibilidad** - Cambiar proveedores sin cambiar código

## 📱 **Compatibilidad de Plataformas**

| Plataforma | Estado | Notas |
|-----------|--------|-------|
| 📱 Android | ✅ Completo | Soporte nativo incluido |
| 🍎 iOS | ✅ Completo | Optimizado para Metal Performance |
| 💻 Windows | ✅ Completo | DirectML y ONNX support |
| 🐧 Linux | ✅ Completo | CUDA y OpenCL support |
| 🌐 Web | ⚠️ Parcial | Solo proveedores basados en API |
| 🍎 macOS | ✅ Completo | Core ML integration |

## 📝 **Licencia**

Este proyecto está licenciado bajo la **Licencia Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 Internacional**.

### ⚖️ Resumen de la Licencia:
- ✅ **Uso Personal** - Utilizar para aprendizaje, proyectos personales
- ✅ **Atribución** - Se debe dar crédito al autor
- ❌ **Uso Comercial** - No se permite uso comercial sin permiso
- ❌ **Trabajos Derivados** - No se permiten modificaciones o trabajos derivados
- ❌ **Forking** - No se permiten forks del repositorio

### 📄 Texto Completo
Para el texto completo de la licencia, visita: [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)

### 🤝 **Colaboraciones Bienvenidas**
Aunque no se aceptan forks ni pull requests, se alientan **issues y discusiones** para:
- Reportes de bugs
- Sugerencias de características  
- Feedback arquitectónico
- Oportunidades profesionales

## 📊 **Roadmap**

### ✅ Completado (v1.0)
- [x] API Facade ultra-simple
- [x] Arquitectura de Services especializados
- [x] Soporte multi-proveedor (OpenAI, Google, XAI)
- [x] Sistema de fallbacks automático
- [x] Caché básico y optimización de rendimiento

### 🚧 Próximas Mejoras
- [ ] Soporte para Anthropic (Claude)
- [ ] Implementación completa de AI.call()
- [ ] Mejoras en el manejo de errores

---

### **Contacto:**
- 🐙 **GitHub**: [@albertooishii](https://github.com/albertooishii)
- 💼 **LinkedIn**: [Perfil Profesional](https://linkedin.com/in/albertooishii)
- 📧 **Email**: albertooishii@gmail.com

---

<div align="center">
  
  <p>
    <a href="https://flutter.dev">
      <img src="https://img.shields.io/badge/Hecho%20con-Flutter-02569B?style=flat-square&logo=flutter" alt="Hecho con Flutter">
    </a>
    <a href="https://dart.dev">
      <img src="https://img.shields.io/badge/Powered%20by-Dart-0175C2?style=flat-square&logo=dart" alt="Powered by Dart">
    </a>
    <a href="https://github.com/albertooishii">
      <img src="https://img.shields.io/badge/Sígueme-GitHub-181717?style=flat-square&logo=github" alt="Sígueme en GitHub">
    </a>
  </p>
</div>

---

### **💡 ¿Te Gusta Este Proyecto?**

Si este SDK te ha resultado útil o impresionante, ¡me encantaría saber de ti!

- ⭐ **Dale una estrella** al repositorio
- 🐛 **Reporta bugs** o sugiere mejoras
- 💼 **Contáctame** para oportunidades profesionales
- 🗣️ **Comparte** con otros desarrolladores Flutter

**¡Gracias por tu interés en AI Providers!** 🙏

---

<div align="center">
  <sub>© 2025 Alberto Oishii. Licenciado bajo CC BY-NC-ND 4.0</sub>
</div>