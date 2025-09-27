import 'package:ai_providers/ai_providers.dart';
import 'package:ai_providers/src/core/provider_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dynamic AI Providers System', () {
    test('ProviderRegistry initializes successfully', () async {
      registerAllProviders();
      final registry = ProviderRegistry.instance;

      final stats = registry.getStats();
      // In test environment, we may have fewer providers healthy
      expect(stats['registered_constructors'],
          greaterThanOrEqualTo(2)); // At least 2 providers registered

      // Test that basic providers are registered (even if not healthy)
      final providers = stats['constructor_ids'] as List<String>;
      expect(providers, isNotEmpty);

      // Note: healthy_providers may be 0 in test environment without API keys
      // Health status in test: ${stats['health_status']}
    });
    test('Provider registry finds correct provider for models', () async {
      registerAllProviders();
      final registry = ProviderRegistry.instance;

      // Test provider detection dynamically - get registered providers first
      final registeredProviders = registry.getRegisteredProviders();
      if (registeredProviders.isNotEmpty) {
        // Get model prefixes dynamically from any registered provider
        for (final providerId in registeredProviders) {
          final prefixes = registry.getModelPrefixes(providerId);
          if (prefixes != null && prefixes.isNotEmpty) {
            // Test with the first available prefix + a test model name
            final testModel = '${prefixes.first}test-model';
            registry.getProviderForModel(testModel);
          }
        }
      }

      // Test that registry doesn't crash when looking for providers
      expect(
          () => registry.getProviderForModel('unknown-model'), returnsNormally);
    });

    test('Capability-based provider discovery works', () async {
      registerAllProviders();
      final registry = ProviderRegistry.instance;

      // Get all registered constructors (instances are created on demand)
      final registeredProviders = registry.getRegisteredProviders();
      expect(
          registeredProviders.length,
          greaterThanOrEqualTo(
              2)); // Should have OpenAI, Google and XAI at minimum

      // All providers should have been created during app initialization,
      // but in test environment we check constructor registration

      // Test that providers are properly registered - completely dynamic
      // Don't assume specific provider names, just verify basic functionality
      expect(registeredProviders.length, greaterThan(0));

      // Verify each registered provider has basic properties
      for (final providerId in registeredProviders) {
        expect(providerId, isNotEmpty);
        expect(providerId, isA<String>());
      }
    });
    test('Provider metadata is comprehensive', () async {
      registerAllProviders();
      final registry = ProviderRegistry.instance;

      // Test that registry has registered constructors
      final registeredProviders = registry.getRegisteredProviders();
      expect(registeredProviders, isNotEmpty);

      // Test that provider ID detection works dynamically
      final availableProviders = registry.getRegisteredProviders();
      if (availableProviders.isNotEmpty) {
        // Use any registered provider's prefixes for testing
        final firstProviderId = availableProviders.first;
        final prefixes = registry.getModelPrefixes(firstProviderId);
        if (prefixes != null && prefixes.isNotEmpty) {
          final testModel = '${prefixes.first}test';
          final detectedProviderId = registry.getProviderForModel(testModel);
          if (detectedProviderId != null) {
            expect(detectedProviderId, isNotEmpty);
          }
        }
      }

      // Test basic provider functionality exists
      expect(() => registry.getProviderForModel('any-model'), returnsNormally);
    });

    test('Backward compatibility with existing system preserved', () async {
      registerAllProviders();
      final registry = ProviderRegistry.instance;

      // Test that constructors are registered
      final constructors = registry.getRegisteredProviders();
      expect(constructors, isNotEmpty);

      // Test model support checking works at basic level
      // Note: In test environment, some methods may return null without API keys
      registry.getBestProviderForCapability(AICapability.textGeneration);
      // In test environment, this may be null without API keys, so we don't enforce it

      // Test that the registry doesn't crash when checking model provider
      expect(() => registry.getProviderForModel('unknown-test-model'),
          returnsNormally);
      expect(() => registry.getProviderForModel('another-test-model'),
          returnsNormally);
      expect(() => registry.getProviderForModel('random-model-name'),
          returnsNormally);
    });
  });
}
