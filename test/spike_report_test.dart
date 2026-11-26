import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/spike/hybrid_debug_screen.dart';
import 'package:niko_rada/inference/hybrid_inference_channel.dart';
import 'package:niko_rada/spike/spike_report.dart';
import 'package:niko_rada/agent/triage.dart';
import 'package:niko_rada/services/rag.dart';

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

  test('report shows triage raw reply exactly (newlines visible) and the parser verdict', () {
    final text = SpikeReport.build(device: device, now: t, steps: [
      SpikeStep(
        at: t,
        kind: SpikeStepKind.triage,
        mode: 'PREFER_ON_DEVICE',
        promptLabel: 'Triage SW',
        online: false,
        route: 'ON_DEVICE',
        latencyMs: 900,
        rawReply: 'tear_gas|high|yes\nStay safe.',
        parseResult: 'REJECTED: more than one line',
      ),
    ]);
    expect(text, contains('#1 TRIAGE'));
    expect(text, contains('prompt: preset Triage SW'));
    expect(text, contains(r'raw reply: "tear_gas|high|yes\nStay safe."'));
    expect(text, contains('parser: REJECTED: more than one line'));
    expect(text, contains('answered by: ON DEVICE'));
  });

  test('all three triage situations pass the out-of-corpus gate (so they are actually sent)', () async {
    final rag = RagService();
    await rag.loadCards();
    for (final e in HybridDebugScreenTestHooks.triageSituations.entries) {
      expect(rag.passesGate(e.value), isTrue, reason: e.key);
    }
  });

  testWidgets('Triage test sends three single-turn prompts and reports accepted / rejected / failed', (tester) async {
    const channel = MethodChannel(HybridInferenceChannel.channelName);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final prompts = <String>[];
    final replies = <Object>[
      'abduction|critical|yes',
      'Hii ni hali ya hatari: tear_gas|high|yes',
      PlatformException(
          code: 'UnknownException',
          message: 'Something unexpected happened.',
          details: {'mode': 'PREFER_ON_DEVICE', 'online': false, 'onDeviceStatusBefore': 'UNAVAILABLE'}),
    ];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'deviceInfo') return {'manufacturer': 'Acme', 'model': 'Phone 4'};
      if (call.method != 'generate') return null;
      final args = call.arguments as Map;
      prompts.add(args['prompt'] as String);
      expect(args['maxOutputTokens'], Triage.maxOutputTokens);
      final next = replies.removeAt(0);
      if (next is PlatformException) throw next;
      return {'text': next, 'route': 'ON_DEVICE', 'mode': 'PREFER_ON_DEVICE', 'online': true, 'latencyMs': 10};
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
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HybridDebugScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triage test (EN · SW · Sheng)'));
    await tester.pumpAndSettle();

    expect(prompts, hasLength(3));
    expect(prompts.every((p) => p.contains('type|severity|active')), isTrue);
    expect(find.textContaining('ACCEPTED abduction|critical|yes'), findsOneWidget);
    expect(find.textContaining('REJECTED'), findsOneWidget);
    expect(find.textContaining('NO REPLY: NO_ROUTE (limited mode)'), findsOneWidget);

    await tester.tap(find.textContaining('Copy results ('));
    await tester.pumpAndSettle();
    expect(copied, contains('prompt: preset Triage EN'));
    expect(copied, contains('parser: ACCEPTED abduction|critical|yes'));
    expect(copied, contains('raw reply: "Hii ni hali ya hatari: tear_gas|high|yes"'));
    expect(copied, contains('parser: REJECTED'));
    expect(copied, contains('ERROR: NO_ROUTE'));
    expect(copied, contains('SDK: UnknownException'));
  });
}
