# 📋 ANÁLISIS COMPLETO DE MÉTODOS AI.* PARA LIMPIEZA

> **Fecha de Análisis:** 26 de septiembre de 2025  
> **Estado del TODO:** ✅ Resuelto - getCurrentVoiceForProvider() implementado  
> **Última Actualización:** ✅ Signatures reales corregidos + saveToCache en AI.image() + getVoicesForProvider()  
> **Objetivo:** Identificar métodos no utilizados para optimizar la API pública

---

## 🎯 MÉTODOS ACTUALMENTE UTILIZADOS (MANTENER)

### **🔥 Métodos Principales (Core Functionality)**

#### `AI.initialize({AIInitConfig? config})`
- **Parámetros:** `config` (opcional) - Configuración de inicialización
- **Retorna:** `Future<void>`
- **Descripción:** Inicializa el sistema AI Provider Manager
- **Capability:** Sistema Core
- **Estado:** ✅ **USADO** - main.dart línea 43

#### `AI.text(String message, AISystemPrompt systemPrompt)`
- **Parámetros:** `message` (String), `systemPrompt` (AISystemPrompt)
- **Retorna:** `Future<AIResponse>`
- **Descripción:** Genera texto usando capability textGeneration
- **Capability:** Text Generation
- **Estado:** ✅ **USADO** - text_demo_screen.dart línea 325

#### `AI.image(String prompt, AISystemPrompt systemPrompt, {bool saveToCache = false})`
- **Parámetros:** `prompt` (String), `systemPrompt` (AISystemPrompt), `saveToCache` (bool, opcional, default: false)
- **Retorna:** `Future<AIResponse>`
- **Descripción:** Genera imágenes usando capability imageGeneration. Con saveToCache=true guarda en caché local
- **Capability:** Image Generation
- **Estado:** ✅ **USADO** - image_demo_screen.dart línea 787 (con saveToCache)

#### `AI.vision(String imageBase64, String prompt, AISystemPrompt systemPrompt, {String? imageMimeType})`
- **Parámetros:** `imageBase64` (String), `prompt` (String), `systemPrompt` (AISystemPrompt), `imageMimeType` (String, opcional)
- **Retorna:** `Future<AIResponse>`
- **Descripción:** Analiza imágenes usando capability imageAnalysis
- **Capability:** Image Analysis
- **Estado:** ✅ **USADO** - image_demo_screen.dart línea 947

#### `AI.speak(String text, [SynthesizeInstructions? instructions, bool saveToCache = false])`
- **Parámetros:** `text` (String), `instructions` (SynthesizeInstructions, opcional), `saveToCache` (bool, opcional, default: false)
- **Retorna:** `Future<AIResponse>`
- **Descripción:** Genera audio TTS usando capability audioGeneration. Con saveToCache=true guarda en caché local
- **Capability:** Audio Generation (TTS)
- **Estado:** ✅ **USADO** - audio_demo_screen.dart línea 485

#### `AI.listen(String audioBase64, [TranscribeInstructions? instructions])`
- **Parámetros:** `audioBase64` (String), `instructions` (TranscribeInstructions, opcional)
- **Retorna:** `Future<AIResponse>`
- **Descripción:** Transcribe audio a texto usando capability audioTranscription
- **Capability:** Audio Transcription (STT)
- **Estado:** ✅ **USADO** - audio_demo_screen.dart línea 555

#### `AI.generate({required AICapability capability, required String prompt, ...})`
- **Parámetros:** `capability` (AICapability), `prompt` (String), múltiples opcionales
- **Retorna:** `Future<AIResponse>`
- **Descripción:** Método universal para casos complejos con capability manual
- **Capability:** Universal
- **Estado:** ✅ **CORE** - Método universal principal

#### `AI.createConversation()`
- **Parámetros:** Ninguno
- **Retorna:** `HybridConversationService`
- **Descripción:** Crea servicio de conversación híbrida
- **Capability:** Conversational
- **Estado:** ✅ **CORE** - Funcionalidad de conversaciones

---

### **⚙️ Métodos de Configuración y Gestión (Utilizados)**

#### `AI.getCurrentProvider(AICapability capability)`
- **Parámetros:** `capability` (AICapability)
- **Retorna:** `Future<String?>`
- **Descripción:** Obtiene el proveedor actual para una capability específica
- **Capability:** Sistema
- **Estado:** ✅ **USADO** - Múltiples demos (text: línea 36; image: líneas 63, 89; audio: líneas 59, 91)

#### `AI.getCurrentModel(AICapability capability)`
- **Parámetros:** `capability` (AICapability)
- **Retorna:** `Future<String?>`
- **Descripción:** Obtiene el modelo actual para una capability específica
- **Capability:** Sistema
- **Estado:** ✅ **USADO** - Múltiples demos (text: línea 46; image: líneas 70, 96; audio: líneas 65, 98)

#### `AI.setSelectedModel(String model, AICapability capability)`
- **Parámetros:** `model` (String), `capability` (AICapability, **obligatorio**)
- **Retorna:** `Future<void>`
- **Descripción:** Establece el modelo seleccionado para una capability específica
- **Capability:** Sistema
- **Estado:** ✅ **USADO** - Múltiples demos (text: línea 635; image: líneas 780, 940; audio: líneas 469, 537, 711, 726)

#### `AI.getAvailableProviders(AICapability capability)`
- **Parámetros:** `capability` (AICapability)
- **Retorna:** `List<Map<String, dynamic>>`
- **Descripción:** Obtiene información rica de proveedores disponibles para una capability
- **Capability:** Sistema
- **Estado:** ✅ **USADO** - Múltiples demos (text: líneas 414, 426, 689; image: líneas 1136, 1354, 1366; audio: líneas 797, 1147, 1159)

#### `AI.getAvailableModels(String providerId)`
- **Parámetros:** `providerId` (String)
- **Retorna:** `Future<List<String>>`
- **Descripción:** Obtiene todos los modelos disponibles de un proveedor específico
- **Capability:** Sistema
- **Estado:** ✅ **USADO** - Múltiples demos (text: línea 673; image: línea 1342; audio: línea 1095)

#### `AI.getDefaultModelForProvider(String providerId, AICapability capability)`
- **Parámetros:** `providerId` (String), `capability` (AICapability)
- **Retorna:** `Future<String?>`
- **Descripción:** Obtiene el modelo por defecto de un proveedor para una capability
- **Capability:** Sistema
- **Estado:** ✅ **USADO** - Múltiples demos (text: línea 485; image: línea 1325; audio: línea 1059)

#### `AI.getCurrentVoiceForProvider(String providerId)`
- **Parámetros:** `providerId` (String)
- **Retorna:** `Future<String?>`
- **Descripción:** Obtiene la voz configurada para un proveedor específico
- **Capability:** Audio
- **Estado:** ✅ **USADO** - audio_demo_screen.dart líneas 73, 1073

#### `AI.setSelectedVoiceForProvider(String providerId, String voice)`
- **Parámetros:** `providerId` (String), `voice` (String)
- **Retorna:** `Future<void>`
- **Descripción:** Establece la voz seleccionada para un proveedor específico
- **Capability:** Audio
- **Estado:** ✅ **USADO** - audio_demo_screen.dart línea 718

#### `AI.getVoicesForProvider(String providerId)`
- **Parámetros:** `providerId` (String)
- **Retorna:** `Future<List<Map<String, dynamic>>>`
- **Descripción:** Obtiene las voces disponibles para un proveedor específico
- **Capability:** Audio
- **Estado:** ✅ **USADO** - audio_demo_screen.dart línea 1105

---

### **🔧 Getters del Sistema (Core)**

#### `AI.isInitialized`
- **Parámetros:** Getter (ninguno)
- **Retorna:** `bool`
- **Descripción:** Indica si el sistema está inicializado
- **Capability:** Sistema Core
- **Estado:** ✅ **USADO** - text_demo_screen.dart línea 410 (debug), Getter importante para verificación

#### `AI._manager`
- **Parámetros:** Getter privado (ninguno)
- **Retorna:** `AIProviderManager`
- **Descripción:** Acceso interno al manager de proveedores
- **Capability:** Sistema Core
- **Estado:** ✅ **CORE** - Getter interno esencial

#### `AI.debugInfo`
- **Parámetros:** Getter (ninguno)
- **Retorna:** `String`
- **Descripción:** Obtiene información de debug del sistema
- **Capability:** Debug
- **Estado:** ✅ **USADO** - text_demo_screen.dart línea 411 (debug logging)

---

## 🗑️ MÉTODOS NO UTILIZADOS (CANDIDATOS PARA ELIMINAR)

### **💾 Grupo 1: Cache Management (6 métodos)**

#### `AI.getCachedAudioFile({String? providerId, String? model})`
- **Parámetros:** `providerId` (String, opcional), `model` (String, opcional)
- **Retorna:** `Future<File?>`
- **Descripción:** Obtiene archivo de audio desde caché
- **Capability:** Cache Audio
- **Estado:** ⚠️ **NO USADO** - Funcionalidad de caché no utilizada

#### `AI.getCachedModels({String? providerId})`
- **Parámetros:** `providerId` (String, opcional)
- **Retorna:** `Future<List<String>?>`
- **Descripción:** Obtiene lista de modelos desde caché
- **Capability:** Cache Models
- **Estado:** ⚠️ **NO USADO** - Caché de modelos no utilizado

#### `AI.saveModelsToCache(String providerId, List<String> models)`
- **Parámetros:** `providerId` (String), `models` (List<String>)
- **Retorna:** `Future<void>`
- **Descripción:** Guarda modelos en caché
- **Capability:** Cache Models
- **Estado:** ⚠️ **NO USADO** - Guardado de caché no utilizado

#### `AI.clearModelCache()`
- **Parámetros:** Ninguno
- **Retorna:** `Future<void>`
- **Descripción:** Limpia todo el caché de modelos
- **Capability:** Cache Management
- **Estado:** ⚠️ **NO USADO** - Limpieza de caché no utilizada

#### `AI.getCacheSize()`
- **Parámetros:** Ninguno
- **Retorna:** `Future<int>`
- **Descripción:** Obtiene el tamaño actual del caché
- **Capability:** Cache Info
- **Estado:** ⚠️ **NO USADO** - Información de caché no utilizada

#### `AI.formatCacheSize(int bytes)`
- **Parámetros:** `bytes` (int)
- **Retorna:** `String`
- **Descripción:** Formatea tamaño de bytes a formato legible
- **Capability:** Cache Utils
- **Estado:** ⚠️ **NO USADO** - Utility no utilizada

---

### **🎵 Grupo 2: Métodos Legacy/Específicos Audio (10 métodos)**

#### `AI.getSelectedModel()`
- **Parámetros:** Ninguno
- **Retorna:** `Future<String?>`
- **Descripción:** ⚠️ **DEPRECADO** - Obtiene modelo sin capability específica
- **Capability:** Legacy (Sin Capability)
- **Estado:** ⚠️ **NO USADO** - Reemplazado por getCurrentModel() con capability

#### `AI.setSelectedAudioProvider(String provider)`
- **Parámetros:** `provider` (String)
- **Retorna:** `Future<void>`
- **Descripción:** Establece proveedor específicamente para audio
- **Capability:** Audio Legacy
- **Estado:** ⚠️ **NO USADO** - Funcionalidad específica no utilizada

#### `AI.getDefaultAudioProvider()`
- **Parámetros:** Ninguno
- **Retorna:** `String`
- **Descripción:** Obtiene proveedor de audio por defecto hardcodeado
- **Capability:** Audio Legacy
- **Estado:** ⚠️ **NO USADO** - Lógica hardcodeada no utilizada

#### `AI.getTtsProviderDisplayName(String providerId)`
- **Parámetros:** `providerId` (String)
- **Retorna:** `String`
- **Descripción:** Obtiene nombre de display de proveedor TTS
- **Capability:** TTS Info
- **Estado:** ⚠️ **NO USADO** - Información específica TTS no utilizada

#### `AI.getTtsProviderDescription(String providerId)`
- **Parámetros:** `providerId` (String)
- **Retorna:** `String`
- **Descripción:** Obtiene descripción de proveedor TTS
- **Capability:** TTS Info
- **Estado:** ⚠️ **NO USADO** - Información específica TTS no utilizada

#### `AI.getTtsProviderSubtitleTemplate(String providerId)`
- **Parámetros:** `providerId` (String)
- **Retorna:** `String`
- **Descripción:** Obtiene template de subtítulo para proveedor TTS
- **Capability:** TTS UI
- **Estado:** ⚠️ **NO USADO** - Templates UI no utilizados

#### `AI.getTtsProviderNotConfiguredSubtitle(String providerId)`
- **Parámetros:** `providerId` (String)
- **Retorna:** `String`
- **Descripción:** Obtiene subtítulo para proveedor TTS no configurado
- **Capability:** TTS UI
- **Estado:** ⚠️ **NO USADO** - Templates UI no utilizados

#### `AI.getDefaultVoiceForProvider(String providerId)`
- **Parámetros:** `providerId` (String)
- **Retorna:** `String?`
- **Descripción:** Obtiene voz por defecto estática de configuración YAML
- **Capability:** Voice Config
- **Estado:** ⚠️ **NO USADO** - Reemplazado por getCurrentVoiceForProvider()

#### `AI.getCurrentVoice()`
- **Parámetros:** Ninguno
- **Retorna:** `Future<String?>`
- **Descripción:** Obtiene voz actual sin proveedor específico
- **Capability:** Voice Legacy
- **Estado:** ⚠️ **NO USADO** - Reemplazado por getCurrentVoiceForProvider()

#### `AI.getAvailableVoices()`
- **Parámetros:** Ninguno
- **Retorna:** `Future<List<Map<String, dynamic>>>`
- **Descripción:** Obtiene voces disponibles sin organización por proveedor
- **Capability:** Voice Legacy
- **Estado:** ⚠️ **NO USADO** - Reemplazado por getVoicesForProvider()

---

### **🏥 Grupo 3: Provider Info/Health (4 métodos)**

#### `AI.getAvailableAudioProviders()`
- **Parámetros:** Ninguno
- **Retorna:** `List<String>`
- **Descripción:** Obtiene lista simple de proveedores de audio
- **Capability:** Provider Info
- **Estado:** ⚠️ **NO USADO** - Reemplazado por getAvailableProviders() con capability

#### `AI.getCurrentAudioProvider()`
- **Parámetros:** Ninguno
- **Retorna:** `Future<String?>`
- **Descripción:** Obtiene proveedor de audio actual
- **Capability:** Audio Legacy
- **Estado:** ⚠️ **NO USADO** - Reemplazado por getCurrentProvider() con capability

#### `AI.isProviderHealthy(String providerId)`
- **Parámetros:** `providerId` (String)
- **Retorna:** `Future<bool>`
- **Descripción:** Verifica si un proveedor está operativo
- **Capability:** Provider Health
- **Estado:** ⚠️ **NO USADO** - Funcionalidad de health check no utilizada

#### `AI.providerSupportsCapability(String providerId, AICapability capability)`
- **Parámetros:** `providerId` (String), `capability` (AICapability)
- **Retorna:** `bool`
- **Descripción:** Verifica si proveedor soporta una capability
- **Capability:** Provider Info
- **Estado:** ⚠️ **NO USADO** - Verificación no utilizada en demos

---

---

## 📊 RESUMEN ESTADÍSTICO

### **Distribución por Estado:**
- ✅ **Métodos Utilizados:** 20 métodos (50%)
- ⚠️ **Candidatos a Eliminar:** 20 métodos (50%)
- **Total Métodos Analizados:** 40 métodos

### **Distribución por Capability (Utilizados):**
- **Sistema Core:** 5 métodos (initialize, generate, createConversation, getters, debugInfo)
- **Capabilities Principales:** 5 métodos (text, image, vision, speak, transcribe)
- **Configuración Sistema:** 6 métodos (getCurrentProvider/Model, setSelectedModel, etc.)
- **Provider Management:** 4 métodos (getAvailableProviders/Models, getDefaultModel)

### **Distribución por Capability (No Utilizados):**
- **Cache Management:** 6 métodos (30% de no utilizados)
- **Legacy/Audio Específico:** 10 métodos (50% de no utilizados)
- **Provider Info/Health:** 4 métodos (20% de no utilizados)

### **Recomendaciones de Limpieza:**

1. **🔥 PRIORIDAD ALTA - Grupo 1 (Cache Management):**
   - Métodos claramente no utilizados
   - Funcionalidad de caché no implementada en demos
   - **Reducción:** 6 métodos

2. **⚟️ PRIORIDAD MEDIA - Grupo 2 (Legacy Audio):**
   - Métodos reemplazados por versiones mejoradas
   - Funcionalidad específica de audio obsoleta
   - **Reducción:** 10 métodos

3. **📊 PRIORIDAD BAJA - Grupo 3:**
   - Funcionalidad de health check
   - Podrían ser útiles en el futuro
   - **Reducción:** 4 métodos

### **Impacto de la Limpieza:**
- **Reducción de Código:** ~50% de métodos públicos
- **Simplicidad de API:** Eliminación de métodos redundantes y legacy
- **Mantenibilidad:** Menor superficie de API para mantener
- **Claridad:** API más enfocada y coherente

---

> **Nota:** Este análisis se basa en el uso actual en los demos. Algunos métodos podrían tener uso en código externo no analizado.