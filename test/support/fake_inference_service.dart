import 'package:niko_rada/inference/inference_service.dart';

/// Test double for [InferenceService]. Scripted replies are consumed in order; each call is recorded.
/// A scripted [InferenceException] is thrown instead of returned.
class FakeInferenceService implements InferenceService {
  FakeInferenceService(List<Object> script)
      : _script = List.of(script),
        _always = null;

  /// Always returns [text] from the given [route].
  FakeInferenceService.always(String text, {InferenceRoute route = InferenceRoute.onDevice, String? fallbackReason})
      : _script = const [],
        _always = InferenceResult(text: text, route: route, fallbackReason: fallbackReason);

  final List<Object> _script; // InferenceResult | InferenceException | String (on-device text)
  final InferenceResult? _always;
  final List<FakeCall> calls = [];

  @override
  Future<InferenceResult> generate(
    String prompt, {
    int maxOutputTokens = 256,
    InferencePreference preference = InferencePreference.preferOnDevice,
  }) async {
    calls.add(FakeCall(prompt, maxOutputTokens, preference));
    final always = _always;
    if (always != null) return always;
    if (_script.isEmpty) throw StateError('FakeInferenceService: no scripted reply left for call ${calls.length}');
    final next = _script.removeAt(0);
    return switch (next) {
      InferenceResult r => r,
      InferenceException e => throw e,
      String s => InferenceResult(text: s, route: InferenceRoute.onDevice),
      _ => throw ArgumentError('unsupported script entry: $next'),
    };
  }
}

class FakeCall {
  final String prompt;
  final int maxOutputTokens;
  final InferencePreference preference;
  const FakeCall(this.prompt, this.maxOutputTokens, this.preference);
}
