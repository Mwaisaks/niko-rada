import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/spike/hybrid_inference_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(HybridInferenceChannel.channelName);
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  void mock(Future<Object?> Function(MethodCall) handler) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (c) {
      calls.add(c);
      return handler(c);
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('generate sends mode on the wire and parses an on-device result', () async {
    mock((c) async => {
          'text': 'step 1',
          'route': 'ON_DEVICE',
          'mode': 'PREFER_ON_DEVICE',
          'cloudModel': 'm',
          'onDeviceStatusBefore': 'AVAILABLE',
          'online': false,
          'latencyMs': 42,
        });
    final r = await HybridInferenceChannel().generate('hi', mode: HybridMode.preferOnDevice);
    expect(calls.single.method, 'generate');
    expect((calls.single.arguments as Map)['mode'], 'PREFER_ON_DEVICE');
    expect(r.route, InferenceRoute.onDevice);
    expect(r.online, isFalse);
    expect(r.latencyMs, 42);
    expect(r.fallbackReason, isNull);
  });

  test('cloud fallback carries the reason', () async {
    mock((c) async => {
          'text': 'x',
          'route': 'IN_CLOUD',
          'onDeviceStatusBefore': 'UNAVAILABLE',
          'online': true,
          'fallbackReason': 'On-device model not ready on this phone (UNAVAILABLE).',
        });
    final r = await HybridInferenceChannel().generate('hi');
    expect(r.route, InferenceRoute.inCloud);
    expect(r.fallbackReason, contains('UNAVAILABLE'));
  });

  test('native errors surface as HybridInferenceException with diagnostics', () async {
    mock((c) async => throw PlatformException(
          code: 'FirebaseAIOnDeviceNotAvailableException',
          message: 'not available',
          details: {'online': false, 'onDeviceStatusBefore': 'UNAVAILABLE'},
        ));
    await expectLater(
      HybridInferenceChannel().generate('hi', mode: HybridMode.onlyOnDevice),
      throwsA(isA<HybridInferenceException>()
          .having((e) => e.code, 'code', 'FirebaseAIOnDeviceNotAvailableException')
          .having((e) => e.diagnostics?['online'], 'online', false)),
    );
  });

  test('missing Firebase config is reported, not thrown as a crash', () async {
    mock((c) async => throw PlatformException(code: 'FIREBASE_NOT_CONFIGURED', message: 'no app'));
    await expectLater(
      HybridInferenceChannel().status(),
      throwsA(isA<HybridInferenceException>().having((e) => e.code, 'code', 'FIREBASE_NOT_CONFIGURED')),
    );
  });

  test('no platform implementation (non-Android) maps to NO_PLATFORM', () async {
    await expectLater(
      HybridInferenceChannel().status(),
      throwsA(isA<HybridInferenceException>().having((e) => e.code, 'code', 'NO_PLATFORM')),
    );
  });
}
