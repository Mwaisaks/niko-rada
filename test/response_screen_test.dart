import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/inference/cloud_consent.dart';
import 'package:niko_rada/inference/inference_service.dart';
import 'package:niko_rada/providers/app_state.dart';
import 'package:niko_rada/services/rag.dart';
import 'package:niko_rada/ui/response_screen.dart';
import 'package:niko_rada/ui/route_status.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_inference_service.dart';

/// The answer screen on top of AnswerFlow: route badge, limited mode, consent, refusal. Synthetic queries only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RagService().loadCards());
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const tearGas = 'There is tear gas. What do I do right now?';

  InferenceAvailability avail({required bool online, required bool device, required bool consent}) =>
      InferenceAvailability(
          online: online,
          onDeviceReady: device,
          onDeviceStatus: device ? 'AVAILABLE' : 'UNAVAILABLE',
          cloudConsent: consent);

  Future<AppState> pumpScreen(WidgetTester tester, FakeInferenceService fake,
      {String query = tearGas, CloudConsentStore? consent}) async {
    final state = AppState(inference: fake, consent: consent ?? CloudConsentStore());
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(home: ResponseScreen(query: query, title: 'Test', lang: 'en')),
    ));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('on-device answer shows the route badge, numbered citations, sources and verified contacts',
      (tester) async {
    final fake = FakeInferenceService.always('1. Move upwind, away from the gas. [teargas-001]');
    await pumpScreen(tester, fake);

    expect(find.text('Answered on this phone'), findsOneWidget);
    expect(find.textContaining('[1]'), findsWidgets);
    expect(find.textContaining('[teargas-001]'), findsNothing);
    expect(find.byKey(const Key('contacts-contacts-001')), findsOneWidget);
    expect(find.byKey(const Key('limited-banner')), findsNothing);
    expect(fake.calls, hasLength(1));
  });

  testWidgets('cloud answer shows the cloud badge and the fallback reason', (tester) async {
    final fake = FakeInferenceService.always('1. Rinse your eyes with clean water. [teargas-001]',
        route: InferenceRoute.inCloud, fallbackReason: 'On-device model not ready on this phone (UNAVAILABLE).');
    await pumpScreen(tester, fake);

    expect(find.text('Answered by cloud AI'), findsOneWidget);
    expect(find.text('On-device model not ready on this phone (UNAVAILABLE).'), findsOneWidget);
  });

  testWidgets('A16 offline: limited mode, verified cards, contacts, no model call, no consent button',
      (tester) async {
    final fake = FakeInferenceService(const [], available: avail(online: false, device: false, consent: false));
    await pumpScreen(tester, fake);

    expect(find.byKey(const Key('limited-banner')), findsOneWidget);
    expect(find.textContaining("can't run the on-device AI"), findsOneWidget);
    expect(find.byKey(const Key('allow-cloud')), findsNothing);
    expect(find.text('Offline · verified library only'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('contacts-contacts-001')), 300,
        scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    expect(find.byKey(const Key('contacts-contacts-001')), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('no consent: Allow cloud AI → consent sheet → granted → answered by cloud', (tester) async {
    final consent = CloudConsentStore();
    final fake = FakeInferenceService(
      [const InferenceResult(text: '1. Move upwind. [teargas-001]', route: InferenceRoute.inCloud)],
      available: avail(online: true, device: false, consent: false),
    );
    // The real service reads consent on every call; mirror that in the fake.
    consent.addListener(() => fake.available = avail(online: true, device: false, consent: consent.granted));
    await pumpScreen(tester, fake, consent: consent);

    expect(find.byKey(const Key('allow-cloud')), findsOneWidget);
    expect(fake.calls, isEmpty);

    await tester.tap(find.byKey(const Key('allow-cloud')));
    await tester.pumpAndSettle();
    expect(find.text('Allow cloud AI?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('consent-allow')));
    await tester.pumpAndSettle();

    expect(consent.granted, isTrue);
    expect(find.text('Answered by cloud AI'), findsOneWidget);
    expect(fake.calls, hasLength(1));
  });

  testWidgets('declining consent keeps it off and makes no model call', (tester) async {
    final consent = CloudConsentStore();
    final fake = FakeInferenceService(const [], available: avail(online: true, device: false, consent: false));
    await pumpScreen(tester, fake, consent: consent);

    await tester.tap(find.byKey(const Key('allow-cloud')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consent-decline')));
    await tester.pumpAndSettle();

    expect(consent.granted, isFalse);
    expect(find.byKey(const Key('limited-banner')), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('off-topic input is refused before any model call, with the emergency contacts', (tester) async {
    final fake = FakeInferenceService.always('should never be called');
    await pumpScreen(tester, fake, query: 'Write me a poem about football');

    expect(find.byKey(const Key('refusal')), findsOneWidget);
    expect(find.byKey(const Key('contacts-contacts-001')), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  group('RouteStatusText', () {
    test('states', () {
      expect(RouteStatusText.of(null, 'en').label, 'Checking AI…');
      expect(RouteStatusText.of(avail(online: false, device: true, consent: false), 'en').label,
          'On-device AI ready · works offline');
      expect(RouteStatusText.of(avail(online: true, device: false, consent: true), 'en').label,
          'Cloud AI · with your permission');
      final off = RouteStatusText.of(avail(online: true, device: false, consent: false), 'en');
      expect(off.offersConsent, isTrue);
      expect(RouteStatusText.of(avail(online: false, device: false, consent: true), 'en').label,
          'Offline · verified library only');
      expect(
          RouteStatusText.of(
                  const InferenceAvailability(
                      online: true,
                      onDeviceReady: false,
                      onDeviceStatus: 'UNKNOWN',
                      cloudConsent: true,
                      error: 'FIREBASE_NOT_CONFIGURED'),
                  'en')
              .label,
          'AI not set up · verified library only');
    });
  });
}
