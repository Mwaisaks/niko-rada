import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/inference/hybrid_inference_channel.dart';
import 'package:niko_rada/inference/inference_service.dart';

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

  test('Galaxy A16 case: offline + no on-device model + generic UnknownException → NO_ROUTE', () async {
    mock((c) async => throw PlatformException(
          code: 'UnknownException',
          message: 'Something unexpected happened.',
          details: {'mode': 'PREFER_ON_DEVICE', 'online': false, 'onDeviceStatusBefore': 'UNAVAILABLE', 'latencyMs': 91},
        ));
    await expectLater(
      HybridInferenceChannel().generate('hi'),
      throwsA(isA<HybridInferenceException>()
          .having((e) => e.code, 'code', 'NO_ROUTE')
          .having((e) => e.sdkCode, 'sdkCode', 'UnknownException')
          .having((e) => e.detail, 'detail', contains('SDK: UnknownException'))
          .having((e) => e.toInferenceException().code, 'InferenceException code', 'NO_ROUTE')),
    );
  });

  group('classifyFailure', () {
    Map<String, Object> d(String mode, bool online, String status) =>
        {'mode': mode, 'online': online, 'onDeviceStatusBefore': status};
    final cases = <(String, Map<Object?, Object?>?), HybridFailure>{
      (('UnknownException', d('PREFER_ON_DEVICE', false, 'UNAVAILABLE'))): HybridFailure.noRoute,
      (('UnknownException', d('PREFER_ON_DEVICE', false, 'DOWNLOADABLE'))): HybridFailure.noRoute,
      (('UnknownException', d('PREFER_IN_CLOUD', false, 'UNAVAILABLE'))): HybridFailure.noRoute,
      (('UnknownException', d('ONLY_IN_CLOUD', false, 'AVAILABLE'))): HybridFailure.offline,
      (('FirebaseAIOnDeviceNotAvailableException', d('ONLY_ON_DEVICE', true, 'UNAVAILABLE'))):
          HybridFailure.onDeviceUnavailable,
      (('FirebaseAIOnDeviceNotAvailableException', d('ONLY_ON_DEVICE', false, 'UNAVAILABLE'))):
          HybridFailure.onDeviceUnavailable,
      (('FirebaseAIOnDeviceUnknownException', d('ONLY_ON_DEVICE', false, 'AVAILABLE'))): HybridFailure.onDeviceError,
      (('FirebaseAIOnDeviceUnknownException', d('PREFER_ON_DEVICE', false, 'AVAILABLE'))): HybridFailure.onDeviceError,
      (('QuotaExceededException', d('PREFER_ON_DEVICE', true, 'UNAVAILABLE'))): HybridFailure.cloudError,
      (('PermissionMissingException', d('ONLY_IN_CLOUD', true, 'UNAVAILABLE'))): HybridFailure.cloudError,
      (('FIREBASE_NOT_CONFIGURED', null)): HybridFailure.notConfigured,
      (('BAD_ARGS', null)): HybridFailure.badRequest,
      (('UnknownException', null)): HybridFailure.unknown, // no diagnostics: do not guess
      (('UnknownException', {'mode': 'PREFER_ON_DEVICE'})): HybridFailure.unknown, // network state unknown
    };
    cases.forEach((input, expected) {
      test('${input.$1} ${input.$2} → ${expected.code}', () => expect(classifyFailure(input.$1, input.$2), expected));
    });
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
