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

abstract interface class InferenceService {
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
