// Phase 0 spike entrypoint. Runs only the hybrid-inference debug screen, bypassing the old Gemma
// model-download gate in main.dart.
//   flutter run -t lib/main_spike.dart
//   flutter build apk --debug -t lib/main_spike.dart --target-platform android-arm64
import 'package:flutter/material.dart';
import 'spike/hybrid_debug_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    title: 'Niko Rada — hybrid spike',
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true, brightness: Brightness.dark),
    debugShowCheckedModeBanner: false,
    home: const HybridDebugScreen(),
  ));
}
