/// The single entry point for every model call in Niko Rada.
///
/// Implementations: the Firebase AI Logic hybrid bridge (Kotlin, wired in Phase 1 once the spike runs on a real
/// phone) and fakes for tests. Nothing else in the app calls a model.
///
/// Every call is single-turn: one prompt in, one text out. No chat session or history is kept between calls.
library;

/// Which path answered, from Firebase's `GenerateContentResponse.inferenceSource`.
enum InferenceRoute { onDevice, inCloud }

/// How the caller would like the request routed. Mirrors Firebase's `InferenceMode`. Consent and offline rules are
/// applied by the implementation, not by callers.
enum InferencePreference { preferOnDevice, onlyOnDevice, preferInCloud, onlyInCloud }

class InferenceResult {
  /// The model's text output, unprocessed.
  final String text;

  /// The path that actually answered.
  final InferenceRoute route;

  /// Why the request was not served by the preferred path, for the UI. Null when it was.
  final String? fallbackReason;

  const InferenceResult({required this.text, required this.route, this.fallbackReason});

  @override
  String toString() => 'InferenceResult($route, fallback: $fallbackReason, ${text.length} chars)';
}

/// A model call that failed: no path could answer (e.g. offline on a phone without an on-device model), the cloud
/// call failed, or App Check rejected the request.
class InferenceException implements Exception {
  /// Stable machine-readable code, e.g. `ON_DEVICE_UNAVAILABLE`, `OFFLINE`, `CLOUD_ERROR`.
  final String code;
  final String message;
  const InferenceException(this.code, this.message);

  @override
  String toString() => 'InferenceException($code): $message';
}

/// What can answer right now. Used for the limited-mode pre-flight check, before any model call.
class InferenceAvailability {
  final bool online;

  /// On-device model status is AVAILABLE (never inferred from a download result).
  final bool onDeviceReady;

  /// Raw on-device status, e.g. AVAILABLE / DOWNLOADABLE / UNAVAILABLE, for diagnostics.
  final String onDeviceStatus;

  /// The user has consented to cloud use of crisis text.
  final bool cloudConsent;

  /// Set when availability could not be determined (e.g. FIREBASE_NOT_CONFIGURED); then nothing is assumed usable.
  final String? error;

  const InferenceAvailability({
    required this.online,
    required this.onDeviceReady,
    required this.onDeviceStatus,
    required this.cloudConsent,
    this.error,
  });

  bool get canUseCloud => error == null && online && cloudConsent;
  bool get canUseDevice => error == null && onDeviceReady;
  bool get anyRoute => canUseCloud || canUseDevice;

  @override
  String toString() =>
      'InferenceAvailability(online: $online, onDevice: $onDeviceStatus, consent: $cloudConsent, error: $error)';
}

abstract interface class InferenceService {
  /// Current routes, without calling a model.
  Future<InferenceAvailability> availability();

  /// One single-turn generation. Throws [InferenceException] when no path can answer.
  ///
  /// Keep [prompt] small: on-device requests must stay under ~4,000 tokens, and replies should stay under ~256
  /// tokens ([maxOutputTokens]).
  Future<InferenceResult> generate(
    String prompt, {
    int maxOutputTokens = 256,
    InferencePreference preference = InferencePreference.preferOnDevice,
  });
}
