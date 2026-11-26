import 'cloud_consent.dart';
import 'hybrid_inference_channel.dart';
import 'inference_service.dart';

/// Maps the caller's preference to the Firebase inference mode actually sent, applying cloud consent.
/// Returns null when no allowed route exists (cloud-only request without consent).
///
/// | preference       | consent | mode sent        |
/// |------------------|---------|------------------|
/// | preferOnDevice   | yes     | PREFER_ON_DEVICE |
/// | preferOnDevice   | no      | ONLY_ON_DEVICE   |
/// | onlyOnDevice     | any     | ONLY_ON_DEVICE   |
/// | preferInCloud    | yes     | PREFER_IN_CLOUD  |
/// | preferInCloud    | no      | ONLY_ON_DEVICE   |
/// | onlyInCloud      | yes     | ONLY_IN_CLOUD    |
/// | onlyInCloud      | no      | null (NO_CONSENT)|
HybridMode? resolveMode(InferencePreference preference, {required bool cloudConsent}) {
  if (!cloudConsent) {
    return preference == InferencePreference.onlyInCloud ? null : HybridMode.onlyOnDevice;
  }
  return switch (preference) {
    InferencePreference.preferOnDevice => HybridMode.preferOnDevice,
    InferencePreference.onlyOnDevice => HybridMode.onlyOnDevice,
    InferencePreference.preferInCloud => HybridMode.preferInCloud,
    InferencePreference.onlyInCloud => HybridMode.onlyInCloud,
  };
}

/// [InferenceService] backed by Firebase AI Logic hybrid inference through the Kotlin bridge
/// (android/app/src/main/kotlin/.../HybridInferencePlugin.kt). Routing between on-device and cloud is done by the
/// Firebase SDK; this class only applies consent and maps results and errors.
class HybridInferenceService implements InferenceService {
  HybridInferenceService({
    required this.consent,
    HybridInferenceChannel? channel,
    this.cloudModel = defaultCloudModel,
  }) : _channel = channel ?? HybridInferenceChannel();

  /// Stable, "billing not required" per https://firebase.google.com/docs/ai-logic/models (checked 23 Nov 2026).
  static const defaultCloudModel = 'gemini-3.5-flash-lite';

  /// Read on every request, so revoking consent applies to the next call.
  final CloudConsent consent;
  final HybridInferenceChannel _channel;
  final String cloudModel;

  @override
  Future<InferenceAvailability> availability() async {
    final granted = consent.granted;
    try {
      final s = await _channel.status(cloudModel: cloudModel);
      return InferenceAvailability(
        online: s.online,
        onDeviceReady: s.onDeviceStatus == 'AVAILABLE',
        onDeviceStatus: s.onDeviceStatus,
        cloudConsent: granted,
      );
    } on HybridInferenceException catch (e) {
      return InferenceAvailability(
          online: false, onDeviceReady: false, onDeviceStatus: 'UNKNOWN', cloudConsent: granted, error: e.code);
    }
  }

  @override
  Future<InferenceResult> generate(
    String prompt, {
    int maxOutputTokens = 256,
    InferencePreference preference = InferencePreference.preferOnDevice,
  }) async {
    final mode = resolveMode(preference, cloudConsent: consent.granted);
    if (mode == null) {
      throw const InferenceException('NO_CONSENT', 'This request needs the cloud, and cloud use is not allowed.');
    }
    final HybridResult r;
    try {
      r = await _channel.generate(prompt, mode: mode, cloudModel: cloudModel, maxOutputTokens: maxOutputTokens);
    } on HybridInferenceException catch (e) {
      throw e.toInferenceException();
    }
    final route = r.route;
    if (route == null) {
      // The UI must show which route answered; an answer without one is not shown.
      throw const InferenceException('UNKNOWN_ROUTE', 'The model answered but the route was not reported.');
    }
    return InferenceResult(text: r.text, route: route, fallbackReason: r.fallbackReason);
  }
}
