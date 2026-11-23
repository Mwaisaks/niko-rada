import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/spike/hybrid_debug_screen.dart';
import 'package:niko_rada/spike/hybrid_inference_channel.dart';
import 'package:niko_rada/spike/spike_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const device = SpikeDeviceInfo(
    manufacturer: 'Acme',
    model: 'Phone 4',
    androidVersion: '15',
    sdkInt: 35,
    totalRamGb: 3.7,
    firebaseConfigured: true,
    appCheckBuildToken: true,
  );
  final t = DateTime(2026, 11, 24, 10, 0, 0);

  group('SpikeReport', () {
    test('includes device, status, route, fallback reason, latency and errors', () {
      final text = SpikeReport.build(device: device, now: t, steps: [
        SpikeStep(at: t, kind: SpikeStepKind.status, online: true, onDeviceStatus: 'UNAVAILABLE'),
        SpikeStep(
          at: t,
          kind: SpikeStepKind.generate,
          mode: 'PREFER_ON_DEVICE',
          promptLabel: 'EN',
          online: true,
          onDeviceStatus: 'UNAVAILABLE',
          route: 'IN_CLOUD',
          fallbackReason: 'On-device model not ready on this phone (UNAVAILABLE).',
          latencyMs: 1234,
          output: '1. Move upwind.',
        ),
        SpikeStep(
          at: t,
          kind: SpikeStepKind.generate,
          mode: 'PREFER_ON_DEVICE',
          promptLabel: 'EN',
          online: false,
          onDeviceStatus: 'UNAVAILABLE',
          errorCode: 'FirebaseAIOnDeviceNotAvailableException',
          errorMessage: 'not available',
        ),
      ]);
      expect(text, contains('Device: Acme Phone 4'));
      expect(text, contains('Android: 15 (API 35) · RAM 3.7 GB'));
      expect(text, contains('on-device model status: UNAVAILABLE'));
      expect(text, contains('answered by: IN THE CLOUD'));
      expect(text, contains('fallback reason: On-device model not ready'));
      expect(text, contains('latency: 1234 ms'));
      expect(text, contains('network: OFFLINE'));
      expect(text, contains('ERROR: FirebaseAIOnDeviceNotAvailableException — not available'));
      expect(text, contains('output: 1. Move upwind.'));
    });

    test('never includes custom prompt text or its output', () {
      final text = SpikeReport.build(device: device, now: t, steps: [
        SpikeStep(
          at: t,
          kind: SpikeStepKind.generate,
          mode: 'ONLY_IN_CLOUD',
          promptLabel: null,
          online: true,
          route: 'IN_CLOUD',
          output: 'answer about something private',
        ),
      ]);
      expect(text, contains('prompt: custom (text omitted)'));
      expect(text, isNot(contains('something private')));
    });

    test('works without device info', () {
      expect(SpikeReport.build(device: null, steps: const []), contains('device info unavailable'));
    });
  });

  testWidgets('debug screen shows the checklist and copies a report after a step', (tester) async {
    const channel = MethodChannel(HybridInferenceChannel.channelName);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => switch (call.method) {
          'deviceInfo' => {
              'manufacturer': 'Acme',
              'model': 'Phone 4',
              'androidVersion': '15',
              'sdkInt': 35,
              'totalRamGb': 3.7,
              'firebaseConfigured': true,
              'appCheckBuildToken': false,
            },
          'status' => {'firebaseConfigured': true, 'onDeviceStatus': 'UNAVAILABLE', 'online': true},
          _ => null,
        });
    String? copied;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    tester.view.physicalSize = const Size(1080, 4000); // tall phone-like viewport: whole screen fits
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HybridDebugScreen()));
    await tester.pumpAndSettle();
    expect(find.text('1. Check status'), findsOneWidget);
    expect(find.text('3. Send a prompt in airplane mode'), findsOneWidget);

    await tester.tap(find.text('1 · Check status'));
    await tester.pumpAndSettle();
    expect(find.textContaining('On-device model: UNAVAILABLE'), findsOneWidget);
    expect(find.text('Copy results (1 steps)'), findsOneWidget);
    await tester.tap(find.text('Copy results (1 steps)'));
    await tester.pumpAndSettle();

    expect(copied, isNotNull);
    expect(copied, contains('Device: Acme Phone 4'));
    expect(copied, contains('CHECK STATUS'));
    expect(copied, contains('on-device model status: UNAVAILABLE'));
  });
}
