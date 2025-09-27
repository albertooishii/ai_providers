/// 🔍 Test de Análisis de Código No Utilizado
///
/// Este test analiza todo el proyecto para identificar:
/// - Funciones/métodos públicos no utilizados
/// - Clases no utilizadas
/// - Archivos no referenciados
/// - Exports innecesarios
///
/// Ayuda a mantener el código limpio antes de publicar
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('🔍 Análisis de Código No Utilizado', () {
    late Directory projectRoot;
    late Directory libDir;
    late Directory exampleDir;
    late Directory testDir;

    setUpAll(() {
      // Obtener directorios del proyecto
      projectRoot = Directory.current;
      libDir = Directory(path.join(projectRoot.path, 'lib'));
      exampleDir = Directory(path.join(projectRoot.path, 'example'));
      testDir = Directory(path.join(projectRoot.path, 'test'));
    });

    test('📁 Identificar archivos no referenciados', () async {
      print('\n🔍 Analizando archivos no referenciados...\n');

      final allDartFiles = await _getAllDartFiles(libDir);
      final referencedFiles = <String>{};
      final unusedFiles = <String>[];

      // Buscar todas las referencias import/export/part
      for (final file in allDartFiles) {
        final content = await file.readAsString();
        final imports = _extractImports(content);

        for (final import in imports) {
          final referencedPath =
              _resolveImportPath(import, file.path, libDir.path);
          if (referencedPath != null) {
            referencedFiles.add(referencedPath);
          }
        }
      }

      // Identificar archivos no referenciados (excepto puntos de entrada)
      final entryPoints = {
        path.join(libDir.path, 'ai_providers.dart'), // Export principal
      };

      for (final file in allDartFiles) {
        final relativePath = path.relative(file.path, from: libDir.path);
        if (!referencedFiles.contains(file.path) &&
            !entryPoints.contains(file.path) &&
            !relativePath.startsWith('test/')) {
          unusedFiles.add(relativePath);
        }
      }

      // Reportar resultados
      if (unusedFiles.isNotEmpty) {
        print('⚠️  Archivos potencialmente no utilizados:');
        for (final file in unusedFiles) {
          print('   📄 $file');
        }
        print('');
      } else {
        print('✅ Todos los archivos están referenciados\n');
      }

      // No fallar el test, solo informar
      print('📊 Resumen archivos:');
      print('   • Total archivos: ${allDartFiles.length}');
      print('   • Referenciados: ${referencedFiles.length}');
      print('   • Potencialmente no utilizados: ${unusedFiles.length}\n');
    });

    test('🔧 Identificar funciones/métodos públicos no utilizados', () async {
      print('🔍 Analizando funciones públicas no utilizadas...\n');

      final allDartFiles = await _getAllDartFiles(libDir);
      final exampleFiles = await _getAllDartFiles(exampleDir);
      final testFiles = await _getAllDartFiles(testDir);

      // Combinar todos los archivos para análisis completo
      final allFiles = [...allDartFiles, ...exampleFiles, ...testFiles];

      final publicFunctions = <String, String>{}; // function name -> file path
      final usedFunctions = <String>{};

      // Funciones útiles para la API pública que no necesariamente se usan en examples
      final utilityFunctions = {
        'getProviderStats',
        'getSystemStats',
        'resetProviderStats',
        'resetStats',
        'getCircuitBreakerStatus',
        'openCircuitBreaker',
        'closeCircuitBreaker',
        'canExecute',
        'clearAllModelsCache',
        'getHostStats',
        'setCompressionEnabled',
        'setDefaultHeaders',
        'getClient',
        'releaseClient',
        'reset',
        'clearHistory',
        'sendAudioMessage',
        'speakPredefinedMessage',
        'pausePlayback',
        'stopPlayback',
        'hasPermissions',
        'requestPermissions',
        'transcribeBytes',
        'deleteMediaFile',
        'recordError',
        'registerInstance',
        'initializeKnownProviders',
        'filterModelsForProvider',
        'getAllModelPrefixes',
        'loadDefault',
        'getTtsProviderDescription',
        'getTtsProviderDisplayName',
        'getTtsProviderNotConfiguredSubtitle',
        'getTtsProviderSubtitleTemplate',
        'hasContextKey',
        'supportsModel',
        'getProvidersByCapability'
      };

      // 1. Extraer todas las funciones/métodos públicos de lib/
      for (final file in allDartFiles) {
        final content = await file.readAsString();
        final functions = _extractPublicFunctions(content);

        for (final func in functions) {
          final relativePath = path.relative(file.path, from: projectRoot.path);
          publicFunctions[func] = relativePath;
        }
      }

      // 2. Buscar uso de estas funciones en todo el código
      for (final file in allFiles) {
        final content = await file.readAsString();

        for (final func in publicFunctions.keys) {
          if (_isFunctionUsed(content, func, file.path)) {
            usedFunctions.add(func);
          }
        }
      }

      // 3. Categorizar funciones no utilizadas
      final unusedFunctions = publicFunctions.keys
          .where((func) => !usedFunctions.contains(func))
          .toList()
        ..sort();

      final utilityNotUsed = unusedFunctions
          .where((func) => utilityFunctions.contains(func))
          .toList();

      final actuallyUnused = unusedFunctions
          .where((func) => !utilityFunctions.contains(func))
          .toList();

      // Reportar resultados
      if (utilityNotUsed.isNotEmpty) {
        print('🔧 Funciones útiles (API pública) no usadas en examples:');
        for (final func in utilityNotUsed) {
          final file = publicFunctions[func]!;
          print('   ✅ $func (en $file)');
        }
        print('');
      }

      if (actuallyUnused.isNotEmpty) {
        print('⚠️  Funciones posiblemente innecesarias:');
        for (final func in actuallyUnused) {
          final file = publicFunctions[func]!;
          print('   �️ $func (en $file)');
        }
        print('');
      }

      if (actuallyUnused.isEmpty && utilityNotUsed.isEmpty) {
        print(
            '✅ Todas las funciones públicas están categorizadas correctamente\n');
      }

      print('📊 Resumen funciones:');
      print('   • Funciones públicas: ${publicFunctions.length}');
      print('   • Utilizadas: ${usedFunctions.length}');
      print('   • Útiles no usadas: ${utilityNotUsed.length}');
      print('   • Posiblemente innecesarias: ${actuallyUnused.length}\n');
    });

    test('📦 Identificar exports innecesarios', () async {
      print('🔍 Analizando exports innecesarios...\n');

      // Analizar el archivo principal de exports
      final mainExportFile = File(path.join(libDir.path, 'ai_providers.dart'));

      if (!await mainExportFile.exists()) {
        print('⚠️  No se encontró ai_providers.dart\n');
        return;
      }

      final content = await mainExportFile.readAsString();
      final exports = _extractExports(content);
      final exampleFiles = await _getAllDartFiles(exampleDir);
      final usedExports = <String>{};

      // Verificar qué exports se usan en los examples
      for (final export in exports) {
        for (final exampleFile in exampleFiles) {
          final exampleContent = await exampleFile.readAsString();

          // Buscar uso del export en examples
          if (exampleContent.contains(export) &&
                  exampleContent.contains('AI.') ||
              exampleContent.contains('import \'package:ai_providers/')) {
            usedExports.add(export);
            break;
          }
        }
      }

      final unusedExports =
          exports.where((e) => !usedExports.contains(e)).toList();

      if (unusedExports.isNotEmpty) {
        print('⚠️  Exports potencialmente innecesarios:');
        for (final export in unusedExports) {
          print('   📤 $export');
        }
        print('');
      } else {
        print('✅ Todos los exports están siendo utilizados\n');
      }

      print('📊 Resumen exports:');
      print('   • Total exports: ${exports.length}');
      print('   • Utilizados en examples: ${usedExports.length}');
      print('   • Potencialmente innecesarios: ${unusedExports.length}\n');
    });

    test('📋 Resumen general de limpieza', () {
      print('=' * 60);
      print('📋 RESUMEN DE ANÁLISIS DE CÓDIGO');
      print('=' * 60);
      print('');
      print('Este análisis identifica código potencialmente no utilizado.');
      print('Revisar manualmente antes de eliminar cualquier código.');
      print('');
      print('Criterios de análisis:');
      print('• Archivos: Busca imports/exports faltantes');
      print('• Funciones: Busca llamadas directas en todo el proyecto');
      print('• Exports: Verifica uso en examples/tests');
      print('');
      print('⚠️  IMPORTANTE: Algunos elementos pueden ser:');
      print('• APIs públicas para usuarios externos');
      print('• Código usado vía reflection/dynamic');
      print('• Funciones de utilidad para futuras funciones');
      print('');
      print('=' * 60);
    });
  });
}

/// Obtiene todos los archivos .dart de un directorio recursivamente
Future<List<File>> _getAllDartFiles(Directory dir) async {
  final files = <File>[];

  if (!await dir.exists()) return files;

  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }

  return files;
}

/// Extrae imports/exports de un archivo
List<String> _extractImports(String content) {
  final imports = <String>[];
  final importRegex = RegExp(r'''(import|export)\s+['"]([^'"]+)['"]''');

  for (final match in importRegex.allMatches(content)) {
    final importPath = match.group(2);
    if (importPath != null && !importPath.startsWith('dart:')) {
      imports.add(importPath);
    }
  }

  return imports;
}

/// Resuelve la ruta de un import relativo
String? _resolveImportPath(String import, String currentFile, String libRoot) {
  if (import.startsWith('package:')) {
    // Convert package import to file path
    if (import.startsWith('package:ai_providers/')) {
      final relativePath = import.replaceFirst('package:ai_providers/', '');
      return path.join(libRoot, relativePath);
    }
    return null;
  }

  // Relative import
  final currentDir = path.dirname(currentFile);
  return path.normalize(path.join(currentDir, import));
}

/// Extrae funciones/métodos públicos de un archivo
List<String> _extractPublicFunctions(String content) {
  final functions = <String>[];

  // Palabras reservadas de Dart que deben ignorarse
  const dartReservedWords = {
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'extends',
    'false',
    'final',
    'finally',
    'for',
    'get',
    'if',
    'implements',
    'import',
    'in',
    'is',
    'library',
    'new',
    'null',
    'operator',
    'part',
    'return',
    'set',
    'static',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'var',
    'void',
    'while',
    'with',
    'yield'
  };

  // Regex mejorado para funciones públicas
  final functionRegex = RegExp(
      r'''(?:static\s+)?(?:Future<[^>]*>|[A-Za-z][A-Za-z0-9_<>]*)\s+([a-zA-Z][a-zA-Z0-9_]*)\s*\(''',
      multiLine: true);

  for (final match in functionRegex.allMatches(content)) {
    final funcName = match.group(1);
    if (funcName != null &&
        !funcName.startsWith('_') && // No privadas
        !funcName.startsWith('test') && // No tests
        !dartReservedWords.contains(funcName) && // No palabras reservadas
        funcName != 'main' && // No main
        funcName != 'build' && // No build de widgets
        funcName != 'toString' && // No toString override
        funcName != 'hashCode' && // No hashCode override
        funcName != 'noSuchMethod' && // No noSuchMethod override
        funcName.length > 1) {
      // Al menos 2 caracteres
      functions.add(funcName);
    }
  }

  return functions;
}

/// Verifica si una función se usa en el contenido
bool _isFunctionUsed(String content, String functionName, String filePath) {
  // No contar la definición de la función como uso
  final definitionRegex =
      RegExp(r'\b' + functionName + r'\s*\(.*?\)\s*(?:async\s*)?{');
  if (definitionRegex.hasMatch(content)) {
    // Es una definición, buscar si también se usa
    final withoutDefinitions = content.replaceAll(definitionRegex, '');
    return withoutDefinitions.contains('$functionName(') ||
        withoutDefinitions.contains('$functionName (') ||
        withoutDefinitions.contains('.$functionName');
  }

  // Buscar uso normal
  return content.contains('$functionName(') ||
      content.contains('$functionName (') ||
      content.contains('.$functionName');
}

/// Extrae exports de un archivo
List<String> _extractExports(String content) {
  final exports = <String>[];

  // Buscar exports tipo "export 'file.dart';"
  final exportRegex = RegExp(r'''export\s+['"]([^'"]+)['"]''');
  for (final match in exportRegex.allMatches(content)) {
    final exportPath = match.group(1);
    if (exportPath != null) {
      exports.add(path.basename(exportPath));
    }
  }

  // Buscar exports con show/hide
  final namedExportRegex =
      RegExp(r'''export\s+['"][^'"]+['"]\s+show\s+([^;]+);''');
  for (final match in namedExportRegex.allMatches(content)) {
    final showList = match.group(1);
    if (showList != null) {
      // Extraer nombres individuales
      final names =
          showList.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
      exports.addAll(names);
    }
  }

  return exports;
}
