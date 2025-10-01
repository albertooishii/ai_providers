import 'package:test/test.dart';
import 'package:ai_providers/src/utils/json_utils.dart';

void main() {
  group('json_utils_test', () {
    test('should extract JSON from markdown block', () {
      final input = '''```json
{
  "description": "Una imagen de Yuna Tanaka",
  "response": "¡Aquí tienes un avatar!"
}
```''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result['description'], equals('Una imagen de Yuna Tanaka'));
      expect(result['response'], equals('¡Aquí tienes un avatar!'));
    });

    test('should handle escaped newlines in markdown JSON', () {
      final input = '''```json
{
  "description": "Una descripción larga que puede\\ntener múltiples líneas y caracteres especiales",
  "response": "Texto de respuesta"
}
```''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result.containsKey('description'), true);
      expect(result['description'], contains('múltiples líneas'));
    });

    test('should extract JSON without markdown delimiters', () {
      final input = '''
{
  "name": "Test",
  "value": 123,
  "nested": {"key": "value"}
}
''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result['name'], equals('Test'));
      expect(result['value'], equals(123));
      expect(result['nested'], isA<Map>());
      expect(result['nested']['key'], equals('value'));
    });

    test('should handle JSON with surrounding text', () {
      final input =
          'Some prefix text {"status": "ok", "data": [1, 2, 3]} some suffix';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result['status'], equals('ok'));
      expect(result['data'], equals([1, 2, 3]));
    });

    test('should handle markdown without json language tag', () {
      final input = '''```
{
  "field1": "value1",
  "field2": "value2"
}
```''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result['field1'], equals('value1'));
      expect(result['field2'], equals('value2'));
    });

    test('should handle nested JSON objects', () {
      final input = '''```json
{
  "user": {
    "name": "John",
    "profile": {
      "age": 30,
      "city": "Tokyo"
    }
  },
  "settings": {
    "theme": "dark"
  }
}
```''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result['user']['name'], equals('John'));
      expect(result['user']['profile']['age'], equals(30));
      expect(result['settings']['theme'], equals('dark'));
    });

    test('should handle JSON with special characters', () {
      final input = '''```json
{
  "text": "Hello 👋 world! \\n\\t\\r\\"quoted\\"",
  "emoji": "🎉🚀✨",
  "unicode": "日本語テスト"
}
```''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result['text'], contains('quoted'));
      expect(result['emoji'], equals('🎉🚀✨'));
      expect(result['unicode'], equals('日本語テスト'));
    });

    test('should handle JSON arrays', () {
      final input = '''```json
{
  "items": ["apple", "banana", "cherry"],
  "numbers": [1, 2, 3, 4, 5],
  "mixed": [1, "two", true, null, {"nested": "object"}]
}
```''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result['items'], equals(['apple', 'banana', 'cherry']));
      expect(result['numbers'], equals([1, 2, 3, 4, 5]));
      expect(result['mixed'].length, equals(5));
      expect(result['mixed'][4]['nested'], equals('object'));
    });

    test('should return raw text for invalid JSON', () {
      final input = '''```json
{
  "invalid": "json",
  missing_quotes: true
}
```''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), true);
      expect(result['raw'], contains('invalid'));
    });

    test('should handle empty JSON object', () {
      final input = '''```json
{}
```''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result.isEmpty, true);
    });

    test('should handle JSON with boolean and null values', () {
      final input = '''```json
{
  "active": true,
  "disabled": false,
  "optional": null,
  "count": 0
}
```''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result['active'], equals(true));
      expect(result['disabled'], equals(false));
      expect(result['optional'], isNull);
      expect(result['count'], equals(0));
    });

    test('should handle real Gemini API response format', () {
      final input = '''```json
{
  "description": "Una imagen de Yuna Tanaka, una mujer japonesa de 25 años, con piel cálida de porcelana, ojos almendrados grandes de color marrón oscuro con destellos dorados.",
  "response": "¡Aquí tienes un avatar de Yuna, lista para un día de trabajo creativo con su estilo geek chic!"
}
```''';

      final result = extractJsonBlock(input);

      expect(result.containsKey('raw'), false);
      expect(result.containsKey('description'), true);
      expect(result.containsKey('response'), true);
      expect(result['description'], contains('Yuna Tanaka'));
      expect(result['response'], contains('avatar'));
    });
  });
}
