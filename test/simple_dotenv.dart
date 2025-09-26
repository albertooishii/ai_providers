import 'dart:io';

/// Cargador simple de archivos .env sin dependencias de Flutter
class SimpleDotEnv {
  static final Map<String, String> _env = {};

  /// Carga variables desde un archivo .env
  static Future<void> load([String fileName = '.env']) async {
    try {
      final file = File(fileName);
      if (await file.exists()) {
        final lines = await file.readAsLines();

        for (final line in lines) {
          final trimmedLine = line.trim();

          // Ignorar líneas vacías y comentarios
          if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
            continue;
          }

          // Parsear líneas con formato KEY=VALUE
          final equalIndex = trimmedLine.indexOf('=');
          if (equalIndex > 0) {
            final key = trimmedLine.substring(0, equalIndex).trim();
            var value = trimmedLine.substring(equalIndex + 1).trim();

            // Remover comillas si existen
            if ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'"))) {
              value = value.substring(1, value.length - 1);
            }

            _env[key] = value;
          }
        }

        print('✅ Loaded ${_env.length} variables from $fileName');
      } else {
        print('⚠️  File $fileName not found, using system environment only');
      }
    } catch (e) {
      print('⚠️  Error loading $fileName: $e');
    }
  }

  /// Obtiene una variable, priorizando .env sobre system environment
  static String? get(String key) {
    return _env[key] ?? Platform.environment[key];
  }

  /// Todas las variables cargadas
  static Map<String, String> get env => Map.unmodifiable(_env);

  /// Limpia las variables cargadas
  static void clear() => _env.clear();
}
