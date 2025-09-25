import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Provider Hardcoded Fallbacks Tests', () {
    test('should detect hardcoded fallbacks in provider files', () {
      final providerDir = Directory('lib/src/providers');

      if (!providerDir.existsSync()) {
        fail('Provider directory not found: ${providerDir.path}');
      }

      final violations = <String>[];

      providerDir
          .listSync()
          .whereType<File>()
          .where((final file) => file.path.endsWith('.dart'))
          .forEach((final file) {
        final content = file.readAsStringSync();
        final fileName = file.path.split('/').last;

        // Buscar patrones de fallback hardcodeado simples
        if (content.contains("?? 'marin'")) {
          violations.add('$fileName: hardcoded voice fallback "marin"');
        }

        if (content.contains("?? 'gpt-4o-mini-tts'")) {
          violations.add(
            '$fileName: hardcoded model fallback "gpt-4o-mini-tts"',
          );
        }

        if (content.contains("?? 'gemini-2.5-flash'")) {
          violations.add(
            '$fileName: hardcoded model fallback "gemini-2.5-flash"',
          );
        }

        if (content.contains("?? 'grok-beta'")) {
          violations.add('$fileName: hardcoded model fallback "grok-beta"');
        }

        // Hardcoded voice fallbacks in getDefaultVoice are allowed for OpenAI (voices are hardcoded by design)
        // but should be detected for other providers
        if (content.contains("return 'marin';") &&
            content.contains('getDefaultVoice') &&
            !fileName.contains('openai')) {
          violations.add(
            '$fileName: hardcoded return value "marin" in getDefaultVoice',
          );
        }

        if (content.contains("return 'alloy';") &&
            content.contains('getDefaultVoice') &&
            !fileName.contains('openai')) {
          violations.add(
            '$fileName: hardcoded return value "alloy" in getDefaultVoice',
          );
        }
      });

      if (violations.isNotEmpty) {
        fail(
          'Found hardcoded fallbacks in providers:\n${violations.join('\n')}',
        );
      }
    });
  });
}
