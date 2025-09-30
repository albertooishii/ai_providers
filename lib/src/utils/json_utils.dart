import 'dart:convert';

/// Extrae el bloque JSON más completo de un texto, manejando markdown, texto mixto y JSON anidado.
/// Usa balanceado de llaves para encontrar JSON válido completo.
/// Si no encuentra un bloque válido, retorna {'raw': texto}.
Map<String, dynamic> extractJsonBlock(final String text) {
  final String cleaned = text.trim();

  // 1. Intentar extraer de bloques markdown (```json ... ```)
  final markdownMatch = RegExp(
    r'```(?:json)?\s*\n?({.*?})\s*\n?```',
    multiLine: true,
    dotAll: true,
  ).firstMatch(cleaned);
  if (markdownMatch != null) {
    final jsonStr = markdownMatch.group(1)!;
    final result = _tryParseJson(jsonStr);
    if (result != null) return result;
  }

  // 2. Buscar el JSON más completo usando balanceado de llaves
  final jsonBlocks = _findBalancedJsonBlocks(cleaned);

  // Intentar parsear cada bloque, empezando por el más largo
  jsonBlocks.sort((final a, final b) => b.length.compareTo(a.length));

  for (final jsonStr in jsonBlocks) {
    final result = _tryParseJson(jsonStr);
    if (result != null) return result;
  }

  // 3. Fallback: método original (compatible hacia atrás)
  final startIdx = cleaned.indexOf('{');
  final endIdx = cleaned.lastIndexOf('}');
  if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
    final jsonStr = cleaned.substring(startIdx, endIdx + 1);
    final result = _tryParseJson(jsonStr);
    if (result != null) return result;
  }

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
