import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_providers/ai_providers.dart';

import 'screens/home_screen.dart';
import 'screens/text_demo_screen.dart';
import 'screens/image_demo_screen.dart';
import 'screens/audio_demo_screen.dart';
import 'screens/advanced_demo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");
  debugPrint('🚀 Environment variables loaded successfully!');

  // Debug: Print loaded environment variables
  debugPrint('📋 Loaded environment variables:');
  debugPrint(
      '  - OPENAI_API_KEYS: ${dotenv.env['OPENAI_API_KEYS']?.isNotEmpty == true ? '✅ Present' : '❌ Missing'}');
  debugPrint(
      '  - GEMINI_API_KEYS: ${dotenv.env['GEMINI_API_KEYS']?.isNotEmpty == true ? '✅ Present' : '❌ Missing'}');
  debugPrint(
      '  - GROK_API_KEYS: ${dotenv.env['GROK_API_KEYS']?.isNotEmpty == true ? '✅ Present' : '❌ Missing'}');

  // Initialize AI Providers SDK with API keys (AI_chan pattern)
  debugPrint('🤖 Initializing AI Providers SDK...');
  try {
    await _initializeAIProviders();
    debugPrint('✅ AI Providers SDK initialized successfully!');
  } catch (e) {
    debugPrint('❌ Failed to initialize AI Providers SDK: $e');
  }

  runApp(const ProviderScope(child: AIProvidersDemo()));
}

/// Initialize AI providers - ¡Súper simple! Carga automática desde .env
Future<void> _initializeAIProviders() async {
  // 🎉 FORMA SIMPLE: Carga automática desde .env (¡SIN CONFIG!)
  await AI.initialize();

  // 🔧 FORMA MANUAL (opcional): Sobreescritura específica
  // final config = AIInitConfig(
  //   apiKeys: {
  //     'openai': ['sk-manual-override-key'],  // Sobreescribe la del .env
  //   },
  //   appDirectoryName: 'ai_providers_demo',
  // );
  // await AI.initialize(config: config);

  // 📁 SOLO DIRECTORIO (opcional): Cambiar directorio pero usar .env para API keys
  // await AI.initialize(
  //   config: AIInitConfig(
  //     appDirectoryName: 'mi_app_personalizada',
  //   ),
  // );
}

class AIProvidersDemo extends ConsumerWidget {
  const AIProvidersDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'AI Providers SDK Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.grey.shade700,
              width: 1,
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/text',
      name: 'text',
      builder: (context, state) => const TextDemoScreen(),
    ),
    GoRoute(
      path: '/image',
      name: 'image',
      builder: (context, state) => const ImageDemoScreen(),
    ),
    GoRoute(
      path: '/audio',
      name: 'audio',
      builder: (context, state) => const AudioDemoScreen(),
    ),
    GoRoute(
      path: '/advanced',
      name: 'advanced',
      builder: (context, state) => const AdvancedDemoScreen(),
    ),
  ],
);
