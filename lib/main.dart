import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/download_screen.dart';
import 'ui/panic_grid.dart';
import 'ui/chat_screen.dart';
import 'ui/logger_screen.dart';
import 'ui/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const NikoRadaApp(),
    ),
  );
}

class NikoRadaApp extends StatelessWidget {
  const NikoRadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Niko Rada',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Show splash while initialising
    if (!state.initialised) {
      return const _SplashScreen();
    }

    // Show download screen if model not ready
    if (!state.modelReady) {
      return DownloadScreen(
        onComplete: () => state.setModelReady(true),
      );
    }

    return const _MainShell();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🛡️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text('Niko Rada',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: AppTheme.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 32),
          const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ]),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  static const _screens = [
    PanicGrid(),
    ChatScreen(),
    LoggerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.warning_amber_rounded),
            selectedIcon: const Icon(Icons.warning_amber_rounded,
                color: AppTheme.primary),
            label: lang == 'sw' ? 'Hatua' : 'Actions',
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: const Icon(Icons.chat_bubble_rounded,
                color: AppTheme.primary),
            label: lang == 'sw' ? 'Uliza' : 'Ask',
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment_rounded,
                color: AppTheme.primary),
            label: lang == 'sw' ? 'Logi' : 'Log',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded,
                color: AppTheme.primary),
            label: lang == 'sw' ? 'Zaidi' : 'More',
          ),
        ],
      ),
    );
  }
}
