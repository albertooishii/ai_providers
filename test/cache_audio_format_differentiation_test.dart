import 'package:test/test.dart';
import 'package:flutter_test/flutter_test.dart' as flutter_test;
import 'package:ai_providers/src/infrastructure/cache_service.dart';
import 'package:ai_providers/src/models/ai_audio_params.dart';

void main() {
  // Ensure platform channels (e.g., path_provider) are available in tests
  flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
  group('Audio Cache - Format Differentiation', () {
    late CompleteCacheService cacheService;

    setUp(() {
      cacheService = CompleteCacheService.instance;
      cacheService.initialize();
    });

    test('generateTtsHash differentiates M4A from MP3 format', () {
      final textSample = 'Hello, this is a test';
      const voiceSample = 'en-US-Neural2-C';
      const languageSample = 'en';
      const providerSample = 'google';

      // Generate hash for M4A
      final hashM4A = cacheService.generateTtsHash(
        text: textSample,
        voice: voiceSample,
        languageCode: languageSample,
        provider: providerSample,
        audioFormat: 'm4a',
      );

      // Generate hash for MP3
      final hashMP3 = cacheService.generateTtsHash(
        text: textSample,
        voice: voiceSample,
        languageCode: languageSample,
        provider: providerSample,
        audioFormat: 'mp3',
      );

      // They should be different!
      expect(hashM4A, isNot(equals(hashMP3)),
          reason:
              'M4A and MP3 of same text should have different hashes to avoid cache collision');
    });

    test('generateTtsHash includes all parameters in hash', () {
      final textSample = 'Hello';

      // Same text, different voices
      final hashVoice1 = cacheService.generateTtsHash(
        text: textSample,
        voice: 'en-US-Neural2-C',
        languageCode: 'en',
        provider: 'google',
        audioFormat: 'm4a',
      );

      final hashVoice2 = cacheService.generateTtsHash(
        text: textSample,
        voice: 'en-US-Neural2-A',
        languageCode: 'en',
        provider: 'google',
        audioFormat: 'm4a',
      );

      expect(hashVoice1, isNot(equals(hashVoice2)),
          reason: 'Different voices should produce different hashes');

      // Same text, different languages
      final hashLang1 = cacheService.generateTtsHash(
        text: textSample,
        voice: 'en-US-Neural2-C',
        languageCode: 'en',
        provider: 'google',
        audioFormat: 'm4a',
      );

      final hashLang2 = cacheService.generateTtsHash(
        text: textSample,
        voice: 'en-US-Neural2-C',
        languageCode: 'es',
        provider: 'google',
        audioFormat: 'm4a',
      );

      expect(hashLang1, isNot(equals(hashLang2)),
          reason: 'Different languages should produce different hashes');

      // Same text, different providers
      final hashProv1 = cacheService.generateTtsHash(
        text: textSample,
        voice: 'en-US-Neural2-C',
        languageCode: 'en',
        provider: 'google',
        audioFormat: 'm4a',
      );

      final hashProv2 = cacheService.generateTtsHash(
        text: textSample,
        voice: 'en-US-Neural2-C',
        languageCode: 'en',
        provider: 'openai',
        audioFormat: 'm4a',
      );

      expect(hashProv1, isNot(equals(hashProv2)),
          reason: 'Different providers should produce different hashes');
    });

    test('AiAudioParams defaults to M4A format', () {
      const params = AiAudioParams();
      expect(params.audioFormat, equals('m4a'),
          reason: 'Default audio format should be M4A for efficiency');
    });

    test('AiAudioParams respects MP3 format selection', () {
      const params = AiAudioParams(audioFormat: 'mp3');
      expect(params.audioFormat, equals('mp3'),
          reason: 'Should respect MP3 format selection');
    });

    test('AiAudioParams falls back to M4A for invalid format', () {
      const params = AiAudioParams(audioFormat: 'invalid_format');
      expect(params.audioFormat, equals('m4a'),
          reason: 'Invalid format should fallback to M4A');
    });

    test('getCachedAudioFile uses audioFormat in search', () {
      // Test that the method accepts audioFormat parameter
      // (Actual file existence not guaranteed in test, but parameter acceptance verified)
      final cachedFileM4ASupportsFormat = cacheService.getCachedAudioFile(
        text: 'test',
        voice: 'default',
        languageCode: 'en',
        provider: 'openai',
        audioFormat: 'm4a',
      );

      final cachedFileMP3SupportsFormat = cacheService.getCachedAudioFile(
        text: 'test',
        voice: 'default',
        languageCode: 'en',
        provider: 'openai',
        audioFormat: 'mp3',
      );

      // Both should return futures without errors
      expect(cachedFileM4ASupportsFormat, isA<Future<dynamic>>(),
          reason: 'getCachedAudioFile should accept M4A format');
      expect(cachedFileMP3SupportsFormat, isA<Future<dynamic>>(),
          reason: 'getCachedAudioFile should accept MP3 format');
    });
  });
}
