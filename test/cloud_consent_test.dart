import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/inference/cloud_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default is not granted, before and after load', () async {
    SharedPreferences.setMockInitialValues({});
    final c = CloudConsentStore();
    expect(c.granted, isFalse);
    await c.load();
    expect(c.granted, isFalse);
    expect(c.isLoaded, isTrue);
  });

  test('grant persists across instances; revoke removes it', () async {
    SharedPreferences.setMockInitialValues({});
    final at = DateTime.utc(2026, 11, 25, 12);
    await CloudConsentStore().grant(now: at);

    final reloaded = CloudConsentStore();
    await reloaded.load();
    expect(reloaded.granted, isTrue);
    expect(reloaded.grantedAt, at);

    await reloaded.revoke();
    final again = CloudConsentStore();
    await again.load();
    expect(again.granted, isFalse);
  });

  test('revoke is immediate on the same instance and notifies listeners', () async {
    SharedPreferences.setMockInitialValues({});
    final c = CloudConsentStore();
    var notified = 0;
    c.addListener(() => notified++);
    await c.grant();
    expect(c.granted, isTrue);
    await c.revoke();
    expect(c.granted, isFalse);
    expect(notified, 2);
  });

  test('consent given for an older consent text, or malformed, does not count', () async {
    for (final stored in ['v0|2026-11-25T12:00:00.000Z', 'yes', 'v1|not-a-date', '']) {
      SharedPreferences.setMockInitialValues({'cloud_consent': stored});
      final c = CloudConsentStore();
      await c.load();
      expect(c.granted, isFalse, reason: stored);
    }
  });
}
