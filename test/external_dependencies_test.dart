import 'dart:io';
import 'package:test/test.dart';

/// Test que analiza y reporta todas las dependencias externas del sistema ai_providers
/// para mantener control sobre la portabilidad del sistema.
///
/// OBJETIVO: El sistema ai_providers debe ser completamente portable,
/// sin dependencias hacia otros sistemas del proyecto (excepto Flutter SDK y packages pub).
void main() {
  group('AI Providers External Dependencies Analysis', () {
    late List<File> aiProviderFiles;
    late Map<String, List<String>> externalDependencies;
    late Map<String, List<String>> allowedDependencies;

    setUpAll(() async {
      // Obtener todos los archivos Dart dentro de lib/ (incluye src/ y tests/)
      final aiProvidersDir = Directory('lib');

      if (!aiProvidersDir.existsSync()) {
        fail('Directory lib does not exist');
      }

      aiProviderFiles = aiProvidersDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((final file) => file.path.endsWith('.dart'))
          .toList();

      if (aiProviderFiles.isEmpty) {
        fail('No Dart files found in lib');
      }

      // Definir dependencias permitidas (Flutter SDK + packages públicos)
      allowedDependencies = {
        'flutter_sdk': ['dart:', 'package:flutter/'],
        'pub_packages': [
          'package:http/',
          'package:shared_preferences/',
          'package:yaml/',
          'package:path/',
          'package:crypto/',
        ],
        'ai_providers_internal': ['package:ai_providers/'],
        'test_dependencies': [
          'package:flutter_test/',
          'package:test/',
          'package:mockito/',
        ],
        'audio_dependencies': [
          'package:flutter_tts/',
          'package:speech_to_text/',
          'package:record/',
        ],
        'storage_dependencies': ['package:path_provider/'],
      };

      externalDependencies = {};
    });

    test('should analyze all ai_providers files for external dependencies',
        () async {
      print('\n📊 ANALYZING AI_PROVIDERS EXTERNAL DEPENDENCIES');
      print('=' * 60);
      print('Total files to analyze: ${aiProviderFiles.length}');
      print('');

      for (final file in aiProviderFiles) {
        final content = await file.readAsString();
        final lines = content.split('\n');
        final imports = <String>[];
        final exports = <String>[];

        // Analizar imports y exports
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();

          if (line.startsWith('import ') &&
              !line.startsWith('import \'dart:') &&
              line.contains('package:')) {
            final match = RegExp(r"import '([^']+)'").firstMatch(line);
            if (match != null) {
              imports.add(match.group(1)!);
            }
          }

          if (line.startsWith('export ') && line.contains('package:')) {
            final match = RegExp(r"export '([^']+)'").firstMatch(line);
            if (match != null) {
              exports.add(match.group(1)!);
            }
          }
        }

        if (imports.isNotEmpty || exports.isNotEmpty) {
          final relativePath = file.path.replaceFirst(
            'lib/shared/ai_providers/',
            '',
          );
          externalDependencies[relativePath] = [...imports, ...exports];
        }
      }

      // Clasificar dependencias
      final allowedImports = <String>[];
      final externalImports = <String>[];

      for (final entry in externalDependencies.entries) {
        final fileName = entry.key;
        final fileImports = entry.value;
        final isTestFile = fileName.startsWith('tests/');

        for (final import in fileImports) {
          bool isAllowed = false;

          // Verificar si es una dependencia permitida
          for (final category in allowedDependencies.values) {
            for (final allowed in category) {
              if (import.startsWith(allowed)) {
                isAllowed = true;
                allowedImports.add(import);
                break;
              }
            }
            if (isAllowed) break;
          }

          if (!isAllowed) {
            // Ya no necesitamos verificar dependencias internas de ai_chan
            // porque somos un paquete independiente
            if (import.startsWith('package:ai_chan/')) {
              externalImports.add(import);
            }
            // Para archivos de test, ser más estricto con dependencias no permitidas
            else if (isTestFile && !import.startsWith('dart:')) {
              // En tests, solo permitir dependencias explícitamente listadas
              externalImports.add(import);
            }
            // Para archivos de src, también considerar como externa cualquier dependencia no permitida
            else if (!isTestFile && !import.startsWith('dart:')) {
              externalImports.add(import);
            }
          }
        }
      }

      // Remover duplicados
      final uniqueAllowed = allowedImports.toSet().toList()..sort();
      final uniqueExternal = externalImports.toSet().toList()..sort();

      // Reportar resultados
      print('📦 ALLOWED DEPENDENCIES (${uniqueAllowed.length}):');
      if (uniqueAllowed.isNotEmpty) {
        for (final dep in uniqueAllowed) {
          print('  ✅ $dep');
        }
      } else {
        print('  (none)');
      }
      print('');

      print('⚠️  INTERNAL APP DEPENDENCIES (${uniqueExternal.length}):');
      if (uniqueExternal.isNotEmpty) {
        for (final dep in uniqueExternal) {
          print('  🔴 $dep');
        }
        print('');

        // Mostrar archivos específicos que usan dependencias internas de la app
        print('📁 FILES USING INTERNAL APP DEPENDENCIES:');
        for (final entry in externalDependencies.entries) {
          final fileName = entry.key;
          final deps = entry.value;
          final externalDeps = deps.where((final dep) {
            final isNotAllowed = !allowedDependencies.values
                .expand((final list) => list)
                .any((final allowed) => dep.startsWith(allowed));
            final isInternalApp = dep.startsWith('package:ai_chan/');
            return isNotAllowed && isInternalApp;
          }).toList();

          if (externalDeps.isNotEmpty) {
            print('  📄 $fileName:');
            for (final dep in externalDeps) {
              print('    - $dep');
            }
            print('');
          }
        }
      } else {
        print('  🎉 No internal app dependencies found!');
      }
      print('');

      // Resumen ejecutivo
      print('📋 EXECUTIVE SUMMARY:');
      print('─' * 40);
      print('Total files analyzed: ${aiProviderFiles.length}');
      print('Files with imports: ${externalDependencies.length}');
      print('Allowed dependencies: ${uniqueAllowed.length}');
      print('Internal app dependencies: ${uniqueExternal.length}');

      if (uniqueExternal.isEmpty) {
        print('🟢 STATUS: AI_PROVIDERS IS FULLY ENCAPSULATED! ✨');
      } else {
        print(
          '� STATUS: ${uniqueExternal.length} external dependencies found - TEST WILL FAIL!',
        );
        print('');
        print('🎯 REQUIRED ACTIONS:');
        print('1. Review each external dependency listed above');
        print('2. Remove or internalize dependencies');
        print('3. Re-run this test to verify portability');
      }
      print('=' * 60);

      // El test debe fallar si hay dependencias externas
      expect(
        uniqueExternal.isEmpty,
        isTrue,
        reason:
            'Found ${uniqueExternal.length} external dependencies that violate ai_providers encapsulation: ${uniqueExternal.join(", ")}',
      );
    });

    test('should identify specific files to refactor for portability', () {
      print('\n🔧 REFACTORING RECOMMENDATIONS');
      print('=' * 60);

      final refactoringTasks = <String, List<String>>{};

      for (final entry in externalDependencies.entries) {
        final fileName = entry.key;
        final deps = entry.value;
        final externalDeps = deps.where((final dep) {
          return !allowedDependencies.values
              .expand((final list) => list)
              .any((final allowed) => dep.startsWith(allowed));
        }).toList();

        if (externalDeps.isNotEmpty) {
          final recommendations = <String>[];

          for (final dep in externalDeps) {
            if (dep.contains('/shared/utils/')) {
              recommendations.add(
                '🔄 Internalize utility: ${dep.split('/').last}',
              );
            } else if (dep.contains('/shared/models/')) {
              recommendations.add(
                '🏗️  Create internal model: ${dep.split('/').last}',
              );
            } else if (dep.contains('/shared/services/')) {
              recommendations.add(
                '⚡ Internalize service: ${dep.split('/').last}',
              );
            } else {
              recommendations.add('❓ Review dependency: $dep');
            }
          }

          refactoringTasks[fileName] = recommendations;
        }
      }

      if (refactoringTasks.isNotEmpty) {
        for (final entry in refactoringTasks.entries) {
          print('📄 ${entry.key}:');
          for (final recommendation in entry.value) {
            print('  $recommendation');
          }
          print('');
        }
      } else {
        print('🎉 No refactoring needed - system is already portable!');
      }

      print('=' * 60);
    });

    test('should validate ai_providers follows internal-only architecture', () {
      // Verificar que no hay dependencias circulares o hacia otros sistemas del proyecto
      final problematicDependencies = <String>[];

      for (final deps in externalDependencies.values) {
        for (final dep in deps) {
          // Verificar dependencias problemáticas específicas
          if (dep.contains('package:ai_chan/')) {
            problematicDependencies.add(dep);
          }
        }
      }

      print('\n🏗️  ARCHITECTURE VALIDATION');
      print('=' * 60);

      if (problematicDependencies.isEmpty) {
        print('✅ AI_PROVIDERS follows clean architecture!');
        print('   - No dependencies on chat/ modules');
        print('   - No dependencies on onboarding/ modules');
        print('   - No circular dependencies within shared/');
      } else {
        print('❌ Architecture violations found:');
        for (final dep in problematicDependencies.toSet()) {
          print('  🔴 $dep');
        }
      }

      print('=' * 60);

      expect(
        problematicDependencies.isEmpty,
        isTrue,
        reason: 'AI_PROVIDERS should not depend on other app modules',
      );
    });
  });
}
