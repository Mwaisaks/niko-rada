import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:niko_rada/main.dart';
import 'package:niko_rada/providers/app_state.dart';

void main() {
  testWidgets('App builds with its AppState provider and shows the splash before init', (tester) async {
    // Same provider main() installs. init() is not called here: it starts the native model runtime,
    // which is not available in widget tests, so the app should sit on the splash screen.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const NikoRadaApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Niko Rada'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
