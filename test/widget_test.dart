import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:niko_rada/main.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const NikoRadaApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
