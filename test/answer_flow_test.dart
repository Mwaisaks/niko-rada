import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/agent/answer_flow.dart';
import 'package:niko_rada/inference/inference_service.dart';
import 'package:niko_rada/services/rag.dart';

import 'support/fake_inference_service.dart';

/// Limited mode (docs/LIMITED_MODE.md) and the Guide flow around it. Synthetic queries only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rag = RagService();
  setUpAll(() async => rag.loadCards());

  const tearGas = 'There is tear gas. What do I do right now?';
  const tearGasSw = 'Kuna machozi ya kutoa. Nifanye nini?';

  InferenceAvailability avail({required bool online, required bool device, required bool consent, String? error}) =>
      InferenceAvailability(
          online: online,
          onDeviceReady: device,
          onDeviceStatus: device ? 'AVAILABLE' : 'UNAVAILABLE',
          cloudConsent: consent,
          error: error);

  // The Galaxy A16 (SM-A165F) in airplane mode: no network, on-device UNAVAILABLE.
  final a16Offline = avail(online: false, device: false, consent: true);

  LimitedModeView limitedOf(AnswerOutcome o) => (o as AnswerLimited).view;

  group('limited mode: pre-flight (no model call)', () {
    test('A16 case: offline + no on-device model → limited NO_ROUTE, 2 cards, contacts, zero generate calls',
        () async {
      final fake = FakeInferenceService(const [], available: a16Offline);
      final v = limitedOf(await AnswerFlow(fake, rag).answer(tearGas));
      expect(fake.calls, isEmpty);
      expect(v.reason, LimitedReason.noRoute);
      expect(v.cards, hasLength(2));
      expect(v.cards.first.id, 'teargas-001');
      expect(v.contacts.first.id, AnswerFlow.emergencyContactsCardId);
      expect(v.banner('en'), contains("can't run the on-device AI"));
      expect(v.banner('sw'), contains('Hakuna mtandao'));
    });

    test('A16 online, no consent → limited NO_CONSENT, no model call', () async {
      final fake = FakeInferenceService(const [], available: avail(online: true, device: false, consent: false));
      final v = limitedOf(await AnswerFlow(fake, rag).answer(tearGas));
      expect(v.reason, LimitedReason.noConsent);
      expect(fake.calls, isEmpty);
    });

    test('Kiswahili without consent shows the verified Kiswahili cards even when Nano is available', () async {
      final fake = FakeInferenceService(const [], available: avail(online: true, device: true, consent: false));
      final v = limitedOf(await AnswerFlow(fake, rag).answer(tearGasSw, lang: 'sw'));
      expect(v.reason, LimitedReason.noConsent);
      expect(v.cards.first.content('sw'), contains('machozi'));
      expect(fake.calls, isEmpty);
    });

    test('Kiswahili offline on a Nano phone → limited OFFLINE (generation needs the cloud)', () async {
      final fake = FakeInferenceService(const [], available: avail(online: false, device: true, consent: true));
      expect(limitedOf(await AnswerFlow(fake, rag).answer(tearGasSw, lang: 'sw')).reason, LimitedReason.offline);
    });

    test('Firebase not configured → limited NOT_CONFIGURED', () async {
      final fake = FakeInferenceService(const [],
          available: avail(online: true, device: false, consent: true, error: 'FIREBASE_NOT_CONFIGURED'));
      expect(limitedOf(await AnswerFlow(fake, rag).answer(tearGas)).reason, LimitedReason.notConfigured);
    });
  });

  group('limited mode: backstop after the call', () {
    test('availability said OK but the call fails with NO_ROUTE → limited NO_ROUTE', () async {
      final fake = FakeInferenceService([const InferenceException('NO_ROUTE', 'offline, no on-device model')]);
      expect(limitedOf(await AnswerFlow(fake, rag).answer(tearGas)).reason, LimitedReason.noRoute);
    });

    test('cloud error → limited, not an error screen', () async {
      final fake = FakeInferenceService([const InferenceException('CLOUD_ERROR', 'quota')]);
      expect(limitedOf(await AnswerFlow(fake, rag).answer(tearGas)).reason, LimitedReason.modelUnavailable);
    });

    test('uncited model output is never shown: limited with the same cards', () async {
      final fake = FakeInferenceService(['1. Pour milk in your eyes.']);
      final v = limitedOf(await AnswerFlow(fake, rag).answer(tearGas));
      expect(v.reason, LimitedReason.modelOutputRejected);
      expect(v.cards.first.id, 'teargas-001');
    });

    test('model says NOT_COVERED → limited with the retrieved cards', () async {
      final fake = FakeInferenceService(['NOT_COVERED']);
      expect(limitedOf(await AnswerFlow(fake, rag).answer(tearGas)).reason, LimitedReason.modelNotCovered);
    });
  });

  group('guided', () {
    test('Nano phone offline (English) → one on-device call, cited answer, contacts attached', () async {
      final fake = FakeInferenceService([
        const InferenceResult(text: '1. Move upwind. [teargas-001]', route: InferenceRoute.onDevice),
      ], available: avail(online: false, device: true, consent: false));
      final out = await AnswerFlow(fake, rag).answer(tearGas) as AnswerGuided;
      expect(fake.calls, hasLength(1));
      expect(out.answer.route, InferenceRoute.onDevice);
      expect(out.contacts.first.id, AnswerFlow.emergencyContactsCardId);
    });
  });

  group('refusal and contacts', () {
    test('out-of-corpus: refused with emergency contacts, no availability check and no model call', () async {
      final fake = FakeInferenceService(const [], available: a16Offline);
      final out = await AnswerFlow(fake, rag).answer('best chapati recipe');
      expect((out as AnswerRefused).contacts.single.id, AnswerFlow.emergencyContactsCardId);
      expect(fake.availabilityCalls, 0);
      expect(fake.calls, isEmpty);
    });

    test('contacts: emergency card first, then retrieved contacts cards, no duplicates', () async {
      final fake = FakeInferenceService(const [], available: a16Offline);
      final v = limitedOf(await AnswerFlow(fake, rag).answer('Ninahitaji wakili', lang: 'sw'));
      final ids = v.contacts.map((c) => c.id).toList();
      expect(ids.first, AnswerFlow.emergencyContactsCardId);
      expect(ids, contains('contacts-lsk-001'));
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('fixed texts are bilingual', () {
      expect(AgentText.refusal('en'), contains("don't have that"));
      expect(AgentText.refusal('sheng'), contains('Sina taarifa'));
      expect(AgentText.disclaimer('sw'), contains('Mwongozo tu'));
    });
  });
}
