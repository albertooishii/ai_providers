import 'dart:convert';
import 'dart:developer' as dev;

/// Extrae el bloque JSON más completo de un texto, manejando markdown, texto mixto y JSON anidado.
/// Usa balanceado de llaves para encontrar JSON válido completo.
/// Si no encuentra un bloque válido, retorna {'raw': texto}.
Map<String, dynamic> extractJsonBlock(final String text) {
  final String cleaned = text.trim();

  dev.log('🔍 extractJsonBlock - Input length: ${cleaned.length}');
  dev.log(
      '🔍 extractJsonBlock - First 200 chars: ${cleaned.substring(0, cleaned.length > 200 ? 200 : cleaned.length)}');

  // 1. Intentar extraer de bloques markdown (```json ... ```)
  // Usamos un enfoque manual para extraer el contenido entre ``` delimitadores
  final markdownStart = cleaned.indexOf('```');
  if (markdownStart != -1) {
    // Buscar el inicio del JSON (primera llave)
    final jsonStart = cleaned.indexOf('{', markdownStart);
    if (jsonStart != -1) {
      // Buscar el cierre de los backticks
      final markdownEnd = cleaned.indexOf('```', jsonStart);
      if (markdownEnd != -1) {
        // Extraer todo el contenido entre la llave inicial y el cierre de markdown
        final contentBetween = cleaned.substring(jsonStart, markdownEnd).trim();
        // Ahora usar balanceado de llaves para extraer el JSON completo
        final jsonStr = _extractBalancedJson(contentBetween, 0);
        if (jsonStr != null) {
          dev.log(
              '🔍 extractJsonBlock - Manual markdown extraction (${jsonStr.length} chars)');
          final result = _tryParseJson(jsonStr);
          if (result != null) {
            dev.log(
                '✅ extractJsonBlock - Parsed from markdown successfully. Keys: ${result.keys.join(", ")}');
            return result;
          }
        }
      }
    }
  }

  // Fallback al regex original por compatibilidad
  final markdownMatch = RegExp(
    r'```(?:json)?\s*(\{[\s\S]*?\})\s*```',
    multiLine: true,
  ).firstMatch(cleaned);

  dev.log(
      '🔍 extractJsonBlock - Markdown match found: ${markdownMatch != null}');

  if (markdownMatch != null) {
    final jsonStr = markdownMatch.group(1)!;
    dev.log(
        '🔍 extractJsonBlock - Extracted from markdown (${jsonStr.length} chars): ${jsonStr.substring(0, jsonStr.length > 150 ? 150 : jsonStr.length)}...');
    final result = _tryParseJson(jsonStr);
    if (result != null) {
      dev.log(
          '✅ extractJsonBlock - Parsed from markdown successfully. Keys: ${result.keys.join(", ")}');
      return result;
    }
    dev.log('⚠️ extractJsonBlock - Failed to parse markdown JSON');
  } else {
    dev.log(
        '⚠️ extractJsonBlock - Regex did not match. Trying balanced braces...');
  }

  // 2. Buscar el JSON más completo usando balanceado de llaves
  final jsonBlocks = _findBalancedJsonBlocks(cleaned);

  dev.log(
      '🔍 extractJsonBlock - Found ${jsonBlocks.length} balanced JSON blocks');

  // Intentar parsear cada bloque, empezando por el más largo
  jsonBlocks.sort((final a, final b) => b.length.compareTo(a.length));

  for (int i = 0; i < jsonBlocks.length; i++) {
    final jsonStr = jsonBlocks[i];
    dev.log(
        '🔍 extractJsonBlock - Trying block $i (${jsonStr.length} chars): ${jsonStr.substring(0, jsonStr.length > 100 ? 100 : jsonStr.length)}...');
    final result = _tryParseJson(jsonStr);
    if (result != null) {
      dev.log(
          '✅ extractJsonBlock - Parsed from balanced block $i. Keys: ${result.keys.join(", ")}');
      return result;
    }
  }

  // 3. Fallback: método original (compatible hacia atrás)
  dev.log('🔍 extractJsonBlock - Trying fallback method...');
  final startIdx = cleaned.indexOf('{');
  final endIdx = cleaned.lastIndexOf('}');
  if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
    final jsonStr = cleaned.substring(startIdx, endIdx + 1);
    dev.log(
        '🔍 extractJsonBlock - Fallback extracted (${jsonStr.length} chars): ${jsonStr.substring(0, jsonStr.length > 100 ? 100 : jsonStr.length)}...');
    final result = _tryParseJson(jsonStr);
    if (result != null) {
      dev.log(
          '✅ extractJsonBlock - Parsed from fallback. Keys: ${result.keys.join(", ")}');
      return result;
    }
  }

  dev.log('❌ extractJsonBlock - All methods failed, returning raw text');
  return {'raw': cleaned};
}

/// Encuentra todos los bloques JSON válidos usando balanceado de llaves.
List<String> _findBalancedJsonBlocks(final String text) {
  final blocks = <String>[];

  for (int i = 0; i < text.length; i++) {
    if (text[i] == '{') {
      final jsonStr = _extractBalancedJson(text, i);
      if (jsonStr != null && jsonStr.length > 10) {
        // Mínimo tamaño razonable
        blocks.add(jsonStr);
      }
    }
  }

  return blocks;
}

/// Extrae un bloque JSON balanceado comenzando desde startIndex.
String? _extractBalancedJson(final String text, final int startIndex) {
  int braceCount = 0;
  bool inString = false;
  bool escaped = false;

  for (int i = startIndex; i < text.length; i++) {
    final char = text[i];

    if (!inString) {
      if (char == '{') {
        braceCount++;
      } else if (char == '}') {
        braceCount--;
        if (braceCount == 0) {
          // JSON completo encontrado
          return text.substring(startIndex, i + 1);
        }
      } else if (char == '"') {
        inString = true;
      }
    } else {
      // Dentro de una string
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
    }
  }

  return null; // JSON incompleto
}

/// Intenta parsear una string como JSON, manejando JSON anidado.
Map<String, dynamic>? _tryParseJson(final String jsonStr) {
  try {
    final decoded = jsonDecode(jsonStr.trim());

    // Si el resultado es un string (posible JSON anidado), intenta decodificar de nuevo
    if (decoded is String) {
      try {
        final nested = jsonDecode(decoded);
        if (nested is Map<String, dynamic>) return nested;
      } on Exception catch (_) {}
      return {'raw': decoded};
    }

    // Si es un Map válido, retornarlo
    if (decoded is Map<String, dynamic>) return decoded;

    // Si es una List u otro tipo, envolver en un Map
    return {'data': decoded};
  } on Exception catch (_) {
    return null;
  }
}
