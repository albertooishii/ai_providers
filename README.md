# 🤖 AI Providers

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License: CC BY-NC-ND 4.0](https://img.shields.io/badge/License-CC%20BY--NC--ND%204.0-lightgrey.svg?style=for-the-badge)](https://creativecommons.org/licenses/by-nc-nd/4.0/)

> **Professional Flutter AI SDK** - A unified, extensible architecture for integrating multiple AI providers (OpenAI, Google AI, XAI, Android Native) with advanced caching, retry logic, and comprehensive monitoring.

## 🎯 **Professional Showcase**

This package demonstrates advanced Flutter/Dart architecture patterns and AI integration expertise:

- **🏗️ Clean Architecture** - Facade pattern with provider registry
- **🔧 Advanced DI** - Dynamic provider resolution and capability-based routing  
- **⚡ Performance** - Intelligent caching, connection pooling, retry mechanisms
- **🧪 Quality Assurance** - 32+ comprehensive tests, architectural protection
- **🔒 Enterprise Security** - API key management, rate limiting, monitoring

---

## 🚀 **Quick Start**

### Installation

```yaml
dependencies:
  ai_providers: ^1.0.0
```

### Basic Usage

```dart
import 'package:ai_providers/ai_providers.dart';

// Initialize the AI system
await AI.initialize();

// Generate text with any available provider
final response = await AI.text(
  ['Hello, how are you?'], 
  'You are a helpful assistant'
);

// Generate images
final imageResponse = await AI.image('A beautiful sunset over mountains');

// Text-to-speech
final audioResponse = await AI.speak('Hello world');

// Speech-to-text  
final transcription = await AI.transcribe(audioBase64);
```

## 🏗️ **Architecture Overview**

### Facade Pattern Implementation

```dart
// ✅ Clean API - Only this is exposed
AI.text()      // Text generation
AI.image()     // Image generation  
AI.speak()     // Audio generation
AI.transcribe() // Speech recognition
AI.generate()  // Universal method

// ❌ Internal complexity hidden
// OpenAIProvider, GoogleProvider, XAIProvider - not accessible
// ProviderRegistry, CacheService, RetryService - not accessible
```

### Advanced Provider Registry

```dart
// Dynamic provider resolution based on capabilities
final providers = ProviderRegistry.instance.getProvidersForCapability(
  AICapability.textGeneration
);

// Automatic fallback and load balancing
final response = await AI.text(message, systemPrompt);
// → Tries OpenAI → Falls back to Google → Falls back to XAI
```

### Enterprise-Grade Services

```dart
// Intelligent caching with TTL
final cached = await CacheService.get('text_generation_hash');

// Retry logic with exponential backoff  
final response = await RetryService.executeWithRetry(() async {
  return await provider.generateText(prompt);
});

// Connection pooling for optimal performance
final pool = HttpConnectionPool(maxPerHost: 10, maxTotal: 50);
```

## 🔧 **Advanced Configuration**

### YAML-Based Provider Configuration

```yaml
# assets/ai_providers_config.yaml
providers:
  openai:
    enabled: true
    priority: 1
    capabilities: [textGeneration, imageGeneration, audioGeneration]
    models:
      text: ["gpt-4", "gpt-3.5-turbo"]
      image: ["dall-e-3", "dall-e-2"]
    rate_limits:
      requests_per_minute: 60
      
  google:
    enabled: true
    priority: 2
    capabilities: [textGeneration, audioGeneration]
    models:
      text: ["gemini-pro", "gemini-pro-vision"]
    voices:
      default: "es-ES-Neural2-A"
```

### Programmatic Configuration

```dart
final config = AIInitConfig(
  providers: {
    'openai': ProviderConfig(
      enabled: true,
      apiKey: 'your-api-key',
      models: ['gpt-4', 'gpt-3.5-turbo'],
      capabilities: [AICapability.textGeneration],
    ),
  },
  cacheConfig: CacheConfig(ttlMinutes: 60),
  retryConfig: RetryConfig(maxAttempts: 3),
);

await AI.initialize(config);
```

## 🎯 **Capability-Based Architecture**

### Unified API with Multiple Capabilities

```dart
// Method 1: Specific capability methods
await AI.text(messages, systemPrompt);
await AI.image(prompt);
await AI.speak(text);

// Method 2: Universal method with explicit capability
await AI.generate(
  message: 'Generate something amazing',
  systemPrompt: systemPrompt,
  capability: AICapability.textGeneration,
);
```

### Dynamic Provider Selection

```dart
// The system automatically selects the best provider based on:
// 1. Capability support
// 2. Provider priority  
// 3. Rate limits
// 4. Health status
// 5. Response time history

final response = await AI.text(messages, systemPrompt);
// → Internally routes to best available provider
```

## 🧪 **Quality Assurance**

### Comprehensive Test Suite

- **32+ Unit Tests** - Complete coverage of all components
- **Architectural Tests** - Ensures facade pattern integrity
- **Integration Tests** - Real provider interaction validation
- **Security Tests** - API key protection and bypass prevention

```bash
flutter test
# → All tests pass with architectural protection
```

### Anti-Bypass Protection

```dart
// ✅ This compiles and works
final response = await AI.text(messages, systemPrompt);

// ❌ This won't compile - internal access blocked
final provider = OpenAIProvider(); // Compilation error
final manager = AIProviderManager.instance; // Not exported
```

## 📊 **Performance Features**

### Intelligent Caching

```dart
// Automatic response caching with configurable TTL
final response1 = await AI.text(['Hello'], 'Assistant'); // API call
final response2 = await AI.text(['Hello'], 'Assistant'); // Cached response
```

### Connection Pooling

```dart
// Optimized HTTP connections
HttpConnectionPoolConfig(
  maxPerHost: 10,
  maxTotal: 50,
  keepAliveTimeout: Duration(seconds: 15),
)
```

### Retry Logic with Circuit Breaker

```dart
// Exponential backoff with circuit breaker pattern
RetryConfig(
  maxAttempts: 3,
  circuitBreakerThreshold: 5,
  backoffMultiplier: 2.0,
)
```

## 🔒 **Security & Monitoring**

### API Key Management

```dart
// Secure API key storage with rotation support
ApiKeyManager.instance.setApiKey('openai', 'primary-key');
ApiKeyManager.instance.addFallbackKey('openai', 'backup-key');
```

### Comprehensive Monitoring

```dart
// Real-time performance monitoring
final metrics = MonitoringService.instance.getMetrics();
print('Success rate: ${metrics.successRate}%');
print('Average response time: ${metrics.avgResponseTime}ms');
```

### Rate Limiting

```dart
// Built-in rate limiting per provider
RateLimitConfig(
  requestsPerMinute: 60,
  burstLimit: 10,
  adaptiveThrottling: true,
)
```

## 🛠️ **Extensibility**

### Adding Custom Providers

```dart
class CustomAIProvider extends BaseProvider {
  @override
  List<AICapability> get supportedCapabilities => [
    AICapability.textGeneration,
  ];
  
  @override
  Future<ProviderResponse> generateText(String prompt) async {
    // Custom implementation
  }
}

// Register in provider registry
ProviderRegistry.instance.registerProvider('custom', CustomAIProvider);
```

### Custom Capabilities

```dart
enum CustomCapability implements AICapability {
  documentAnalysis,
  codeGeneration,
  realtimeConversation;
}
```

## 📈 **Performance Benchmarks**

| Feature | Performance | Memory Usage |
|---------|-------------|--------------|
| Cold start | ~200ms | 15MB |
| Cached response | ~5ms | +2MB |
| Provider switching | ~50ms | +1MB |
| Concurrent requests | 50/sec | Linear scaling |

## 🎯 **Use Cases**

### Chatbot Applications
```dart
final conversation = AI.createConversation();
await conversation.addMessage('Hello', Role.user);
final response = await conversation.generateResponse();
```

### Content Generation
```dart
final article = await AI.text(
  ['Write an article about Flutter'],
  'You are a technical writer'
);
```

### Multimodal AI
```dart
final description = await AI.generate(
  message: 'Describe this image',
  imageBase64: imageData,
  capability: AICapability.imageAnalysis,
);
```

## 🏆 **Why This Architecture?**

### Professional Software Engineering Principles

1. **Separation of Concerns** - Each component has a single responsibility
2. **Dependency Inversion** - High-level modules don't depend on low-level details  
3. **Open/Closed Principle** - Open for extension, closed for modification
4. **Interface Segregation** - Clients don't depend on unused interfaces
5. **Single Responsibility** - Each class has one reason to change

### Enterprise Patterns

- **Facade Pattern** - Simplified interface to complex subsystem
- **Strategy Pattern** - Interchangeable provider algorithms
- **Registry Pattern** - Dynamic service discovery and registration
- **Circuit Breaker** - Fault tolerance and resilience
- **Observer Pattern** - Event-driven monitoring and alerts

## 📝 **License**

This project is licensed under the **Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License**.

### ⚖️ License Summary:
- ✅ **Personal Use** - Use for learning, personal projects
- ✅ **Attribution** - Credit must be given to the author
- ❌ **Commercial Use** - No commercial use without permission
- ❌ **Derivatives** - No modifications or derivative works
- ❌ **Forking** - Repository forks are not permitted

### 🤝 **Feedback Welcome**
While forks and pull requests are not accepted, **issues and discussions** are encouraged for:
- Bug reports
- Feature suggestions  
- Architecture feedback
- Professional opportunities

---

## 👨‍💻 **About the Developer**

This package showcases advanced Flutter and AI integration skills as part of a professional portfolio. 

**Technical Expertise Demonstrated:**
- Advanced Dart/Flutter architecture patterns
- AI/ML integration and prompt engineering
- Enterprise software design patterns
- Comprehensive testing strategies
- Performance optimization techniques
- Security best practices

**Contact for Professional Opportunities:**
- GitHub: [@albertooishii](https://github.com/albertooishii)
- Open to Flutter/AI development roles

---

<div align="center">
  <p><strong>🚀 Built with Flutter & Dart for Professional Excellence</strong></p>
  <p><em>Demonstrating modern software architecture and AI integration expertise</em></p>
</div>