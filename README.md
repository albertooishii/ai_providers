# 🤖 AI Providers para Flutter

> 🇬🇧 **Don't speak Spanish?** Use AI to translate this documentation to your language. After all, this is an AI package 😉

[![pub package](https://img.shields.io/pub/v/ai_providers.svg)](https://pub.dev/packages/ai_providers)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://www.mozilla.org/MPL/2.0/)

AI Providers ofrece un único facade `AI.*` para conectar tu app Flutter con múltiples proveedores de IA (OpenAI, Google Gemini, xAI Grok y Android Native TTS) usando una sola API.

## ✨ Características clave
- API unificada con métodos `AI.text()`, `AI.image()`, `AI.vision()`, `AI.speak()`, `AI.listen()` y `AI.transcribe()`.
- Fallback automático entre proveedores configurados en `ai_providers_config.yaml`.
- Configuración declarativa (YAML + `.env`) con soporte para múltiples claves API por proveedor.
- Utilidades integradas para depuración (`AI.debugInfo`) y limpieza de caché (`AI.clearTextCache()`, `AI.clearAudioCache()`, `AI.clearImageCache()`).

## 🚀 Instalación rápida
1. **Agregar dependencia**
   ```bash
   dart pub add ai_providers
   ```

2. **Registrar el archivo de configuración** (usa el ejemplo en `example/assets/ai_providers_config.yaml`)
   ```yaml
   # pubspec.yaml
   flutter:
     assets:
       - assets/ai_providers_config.yaml
   ```

3. **Definir tus claves API** en `.env` (formato JSON Array)
   ```env
   OPENAI_API_KEYS=["sk-proj-..."]
   GEMINI_API_KEYS=["AIza...", "AIza..."]
   GROK_API_KEYS=["xai-..."]
   ```
   > El SDK rota automáticamente entre las claves incluidas en cada arreglo.

## 🧪 Uso esencial
```dart
import 'package:flutter/material.dart';
import 'package:ai_providers/ai_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AI.initialize(); // Carga configuración YAML + claves de .env

  final text = await AI.text('Resume el estado del arte en IA generativa');
  final image = await AI.image('Robot pintando un mural retro futurista');
  final audio = await AI.speak('Hola, este es un ejemplo de TTS');
  final transcript = await AI.listen();

  debugPrint('Texto: ${text.text}');
  debugPrint('Imagen URL: ${image.image?.url}');
  debugPrint('Imagen base64: ${image.image?.base64?.substring(0, 32)}...');
  debugPrint('Transcripción: ${transcript.text}');

  runApp(const MyApp());
}
```

¿Quieres explorar una app completa? Visita la carpeta [`example/`](example/) para una demo funcional con pantallas de texto, imagen, audio y herramientas avanzadas.

```bash
cd example
cp .env.example .env
flutter run
```

## ⚙️ Configuración avanzada
- Seleccionar modelo o proveedor preferido:
  ```dart
  await AI.setModel('openai', 'gpt-4.1-mini', AICapability.textGeneration);
  final providers = AI.getAvailableProviders(AICapability.audioGeneration);
  // providers es ahora List<AIProvider> con propiedades id, displayName, description, etc.
  for (final provider in providers) {
    print('${provider.displayName}: ${provider.description}');
  }
  ```
- Inspeccionar estado y capacidades:
  ```dart
  debugPrint(AI.debugInfo);
  ```
- Limpiar caches persistentes cuando lo necesites:
  ```dart
  await AI.clearTextCache();
  await AI.clearAudioCache();
  await AI.clearImageCache();
  ```

## 📘 Métodos `AI.*`

### Inicialización y estado
| Método | Descripción | Retorno |
|--------|-------------|---------|
| `AI.initialize({AIInitConfig? config})` | Inicializa el sistema, carga `ai_providers_config.yaml` y las claves de `.env`. | `Future<void>` |
| `AI.debugInfo` | Cadena con estado interno (providers cargados, capabilities, etc.). | `String` |
| `AI.isInitialized` | Indica si el sistema ya fue inicializado. | `bool` |

### Generación y análisis
| Método | Descripción | Retorno |
|--------|-------------|---------|
| `AI.text(String message, [AIContext? aiContext])` | Genera texto o respuestas conversacionales. | `Future<AIResponse>` |
| `AI.image(String prompt, [AIContext? aiContext, AiImageParams? imageParams])` | Crea imágenes y devuelve objeto `AiImage` con metadatos completos. | `Future<AIResponse>` |
| `AI.vision(String imageBase64, [String? prompt, AIContext? aiContext, String? imageMimeType])` | Analiza imágenes o realiza visión computacional. | `Future<AIResponse>` |
| `AI.generate({required String message, required AIContext aiContext, required AICapability capability, String? imageBase64, String? imageMimeType})` | Método avanzado para elegir capability manualmente. | `Future<AIResponse>` |

### Audio (TTS/STT)
| Método | Descripción | Retorno |
|--------|-------------|---------|
| `AI.speak(String text, [AiAudioParams? audioParams, bool play = false])` | Genera audio TTS y opcionalmente lo reproduce. | `Future<AIResponse>` |
| `AI.listen({Duration? duration, Duration silenceTimeout = const Duration(seconds: 2), bool autoStop = true, AIContext? aiContext})` | Graba audio con detección de silencio y devuelve transcripción. | `Future<AIResponse>` |
| `AI.transcribe(String audioBase64, [AIContext? aiContext])` | Transcribe audio existente en base64. | `Future<AIResponse>` |
| `AI.stopSpeak()` / `AI.pauseSpeak()` | Controla la reproducción de audio en curso. | `Future<bool>` |
| `AI.stopListen()` | Detiene la grabación activa y devuelve la transcripción parcial. | `Future<String?>` |

### Gestión avanzada y utilidades
| Método | Descripción | Retorno |
|--------|-------------|---------|
| `AI.createConversation()` | Crea un `HybridConversationService` para conversaciones en streaming. | `HybridConversationService` |
| `AI.setModel(String providerId, String modelId, AICapability capability)` | Sobrescribe proveedor/modelo preferido para una capability. | `Future<void>` |
| `AI.getAvailableProviders(AICapability capability)` | Lista proveedores disponibles con metadatos. | `List<AIProvider>` |
| `AI.getAvailableModels(String providerId)` | Obtiene modelos disponibles para un proveedor. | `Future<List<String>>` |
| `AI.getCurrentModel(AICapability capability)` | Devuelve el modelo activo para una capability. | `Future<String?>` |
| `AI.clearTextCache()` / `AI.clearAudioCache()` / `AI.clearImageCache()` / `AI.clearModelsCache()` | Limpia las diferentes cachés persistentes. | `Future<int>` |

### 🧱 Arquitectura modular (fácil de extender)
- **Servicios por capability** → Cada archivo dentro de `lib/src/capabilities/` encapsula una capacidad concreta (`TextGenerationService`, `ImageGenerationService`, `AudioGenerationService`, etc.). Funcionan como singletons (`Service.instance`) y empaquetan defaults + lógica especializada, de modo que la fachada `AI.*` se mantiene mínima.
- **Proveedores aislados** → `lib/src/providers/` contiene un archivo por proveedor (`openai_provider.dart`, `google_provider.dart`, ...). Todos heredan de `BaseProvider`, sobrescriben únicamente los métodos que necesitan y exponen un `static register()` que inscribe la clase en el `ProviderRegistry`.
- **Autodiscovery real** → Al iniciar (`AI.initialize()`), el `AIProviderManager` lee `ai_providers_config.yaml` y pide al `ProviderRegistry` crear los proveedores declarados. No hay listas hardcodeadas: basta con añadir un entry al YAML para que el proveedor entre en la rotación y respete los fallbacks definidos.
- **Extender sin tocar la fachada** → Para sumar un proveedor nuevo solo necesitas crear su archivo, llamar a `ProviderRegistry.instance.registerConstructor(...)` desde `registerAllProviders()` y declararlo en el YAML. Lo mismo aplica a nuevas capabilities: añade un service en `lib/src/capabilities/`, expórtalo internamente y la fachada puede delegar en él sin cambios invasivos.
- **Fallbacks configurables** → Las prioridades se controlan en `capability_preferences` dentro del YAML. Cambia el primario o añade fallbacks y la resolución se actualiza sin modificar código Dart.

## 🧩 Plataformas soportadas
| Plataforma | Estado |
|-----------|--------|
| Android   | ✅ Completo |
| iOS       | ✅ Completo |
| macOS     | ✅ Completo |
| Windows   | ✅ Completo |
| Linux     | ✅ Completo |
| Web       | ✅ Completo |

## 🧑‍💻 Desarrollo
Para contribuidores al paquete, instala los hooks de Git automáticos:
```bash
./scripts/install-hooks.sh
```
Los hooks ejecutan automáticamente `dart fix`, `dart format` y `dart doc` en cada commit.

## 📚 Recursos útiles
- Ejemplo completo listo para correr: [`example/`](example/)
- Configuración de referencia: [`example/assets/ai_providers_config.yaml`](example/assets/ai_providers_config.yaml)
- Documentación generada: [`doc/api/index.html`](doc/api/index.html)

## 📬 Contacto
- 🐙 **GitHub**: [@albertooishii](https://github.com/albertooishii)
- 💼 **LinkedIn**: [Perfil Profesional](https://linkedin.com/in/albertooishii)
- 📧 **Email**: albertooishii@gmail.com

## 📄 Licencia
Distribuido bajo la [Mozilla Public License 2.0](https://www.mozilla.org/MPL/2.0/).
