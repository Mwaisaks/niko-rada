import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/inference/cloud_consent.dart';
import 'package:niko_rada/inference/hybrid_inference_channel.dart';
import 'package:niko_rada/inference/hybrid_inference_service.dart';
import 'package:niko_rada/inference/inference_service.dart';

class _Consent implements CloudConsent {
  _Consent(this.granted);
  @override
  bool granted;
}

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

  group('resolveMode (consent applied)', () {
    const p = InferencePreference.values;
    final withConsent = {for (final x in p) x: resolveMode(x, cloudConsent: true)};
    final without = {for (final x in p) x: resolveMode(x, cloudConsent: false)};
    test('with consent: preference passes through', () {
      expect(withConsent[InferencePreference.preferOnDevice], HybridMode.preferOnDevice);
      expect(withConsent[InferencePreference.onlyOnDevice], HybridMode.onlyOnDevice);
      expect(withConsent[InferencePreference.preferInCloud], HybridMode.preferInCloud);
      expect(withConsent[InferencePreference.onlyInCloud], HybridMode.onlyInCloud);
    });
    test('without consent: never a cloud-capable mode', () {
      expect(without[InferencePreference.preferOnDevice], HybridMode.onlyOnDevice);
      expect(without[InferencePreference.onlyOnDevice], HybridMode.onlyOnDevice);
      expect(without[InferencePreference.preferInCloud], HybridMode.onlyOnDevice);
      expect(without[InferencePreference.onlyInCloud], isNull);
    });
  });

  group('generate', () {
    Map<String, Object?> ok(String route) => {
          'text': 'abduction|high|yes',
          'route': route,
          'mode': 'PREFER_ON_DEVICE',
          'online': true,
          'onDeviceStatusBefore': 'UNAVAILABLE',
          'latencyMs': 1000,
          'fallbackReason': route == 'IN_CLOUD' ? 'On-device model not ready on this phone (UNAVAILABLE).' : null,
        };

    test('consent on: sends PREFER_ON_DEVICE and returns text, route and fallback reason (A16 online case)', () async {
      mock((c) async => ok('IN_CLOUD'));
      final r = await HybridInferenceService(consent: _Consent(true)).generate('p', maxOutputTokens: 16);
      expect(calls.single.method, 'generate');
      final args = calls.single.arguments as Map;
      expect(args['mode'], 'PREFER_ON_DEVICE');
      expect(args['maxOutputTokens'], 16);
      expect(args['cloudModel'], HybridInferenceService.defaultCloudModel);
      expect(r.text, 'abduction|high|yes');
      expect(r.route, InferenceRoute.inCloud);
      expect(r.fallbackReason, contains('UNAVAILABLE'));
    });

    test('consent off: the same request is sent ONLY_ON_DEVICE', () async {
      mock((c) async => ok('ON_DEVICE'));
      await HybridInferenceService(consent: _Consent(false)).generate('p');
      expect((calls.single.arguments as Map)['mode'], 'ONLY_ON_DEVICE');
    });

    test('revoking consent takes effect on the next request', () async {
      mock((c) async => ok('ON_DEVICE'));
      final consent = _Consent(true);
      final s = HybridInferenceService(consent: consent);
      await s.generate('p');
      consent.granted = false;
      await s.generate('p');
      expect(calls.map((c) => (c.arguments as Map)['mode']), ['PREFER_ON_DEVICE', 'ONLY_ON_DEVICE']);
    });

    test('cloud-only without consent: NO_CONSENT and the channel is never called', () async {
      mock((c) async => ok('IN_CLOUD'));
      await expectLater(
        HybridInferenceService(consent: _Consent(false)).generate('p', preference: InferencePreference.onlyInCloud),
        throwsA(isA<InferenceException>().having((e) => e.code, 'code', 'NO_CONSENT')),
      );
      expect(calls, isEmpty);
    });

    test('A16 offline case surfaces as InferenceException NO_ROUTE', () async {
      mock((c) async => throw PlatformException(
            code: 'UnknownException',
            message: 'Something unexpected happened.',
            details: {'mode': 'PREFER_ON_DEVICE', 'online': false, 'onDeviceStatusBefore': 'UNAVAILABLE'},
          ));
      await expectLater(
        HybridInferenceService(consent: _Consent(true)).generate('p'),
        throwsA(isA<InferenceException>()
            .having((e) => e.code, 'code', 'NO_ROUTE')
            .having((e) => e.message, 'message', contains('UnknownException'))),
      );
    });

    test('an answer without a reported route is not returned', () async {
      mock((c) async => {'text': 'x', 'mode': 'PREFER_ON_DEVICE', 'online': true});
      await expectLater(
        HybridInferenceService(consent: _Consent(true)).generate('p'),
        throwsA(isA<InferenceException>().having((e) => e.code, 'code', 'UNKNOWN_ROUTE')),
      );
    });
  });

  group('availability', () {
    test('A16 offline: no device, no network → no route', () async {
      mock((c) async => {'firebaseConfigured': true, 'onDeviceStatus': 'UNAVAILABLE', 'online': false});
      final a = await HybridInferenceService(consent: _Consent(true)).availability();
      expect(a.canUseDevice, isFalse);
      expect(a.canUseCloud, isFalse);
      expect(a.anyRoute, isFalse);
    });

    test('A16 online without consent → no route; with consent → cloud', () async {
      mock((c) async => {'firebaseConfigured': true, 'onDeviceStatus': 'UNAVAILABLE', 'online': true});
      expect((await HybridInferenceService(consent: _Consent(false)).availability()).anyRoute, isFalse);
      expect((await HybridInferenceService(consent: _Consent(true)).availability()).canUseCloud, isTrue);
    });

    test('Nano phone offline → device route', () async {
      mock((c) async => {'firebaseConfigured': true, 'onDeviceStatus': 'AVAILABLE', 'online': false});
      final a = await HybridInferenceService(consent: _Consent(false)).availability();
      expect(a.canUseDevice, isTrue);
      expect(a.anyRoute, isTrue);
    });

    test('Firebase not configured → error, nothing usable', () async {
      mock((c) async => throw PlatformException(code: 'FIREBASE_NOT_CONFIGURED', message: 'no app'));
      final a = await HybridInferenceService(consent: _Consent(true)).availability();
      expect(a.error, 'FIREBASE_NOT_CONFIGURED');
      expect(a.anyRoute, isFalse);
    });
  });
}
