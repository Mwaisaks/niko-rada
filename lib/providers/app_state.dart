import 'package:flutter/foundation.dart';
import '../agent/answer_flow.dart';
import '../config/feature_flags.dart';
import '../inference/cloud_consent.dart';
import '../inference/hybrid_inference_channel.dart';
import '../inference/hybrid_inference_service.dart';
import '../inference/inference_service.dart';
import '../services/gemma_service.dart';
import '../services/rag.dart';
import '../services/store.dart';

/// Global app state: language, cloud consent, and the current inference routes.
///
/// Owns the single [InferenceService] (Firebase AI Logic hybrid inference through the Kotlin bridge) and the
/// [AnswerFlow] built on it. Nothing else in the app creates a model client.
class AppState extends ChangeNotifier {
  AppState({CloudConsentStore? consent, InferenceService? inference, HybridInferenceChannel? channel})
      : consent = consent ?? CloudConsentStore(),
        _channel = channel ?? HybridInferenceChannel() {
    this.inference = inference ?? HybridInferenceService(consent: this.consent, channel: _channel);
    answerFlow = AnswerFlow(this.inference, RagService());
    this.consent.addListener(_onConsentChanged);
  }

  final _store = StoreService();
  final CloudConsentStore consent;
  final HybridInferenceChannel _channel;
  late final InferenceService inference;
  late final AnswerFlow answerFlow;

  String _language = 'en';
  bool _initialised = false;
  InferenceAvailability? _availability;
  bool _downloadStarted = false;
  bool _legacyModelReady = false;

  String get language => _language;

  /// Legacy flutter_gemma path only (HYBRID_AI=false): the Gemma weights are installed. Always true in hybrid mode,
  /// which needs no model download in the app.
  bool get modelReady => kHybridAi || _legacyModelReady;

  void setModelReady(bool ready) {
    _legacyModelReady = ready;
    notifyListeners();
  }

  bool get initialised => _initialised;

  /// Last known routes; null until the first check finishes.
  InferenceAvailability? get availability => _availability;

  Future<void> init() async {
    _language = await _store.getLanguage();
    await consent.load();
    await RagService().loadCards();
    if (!kHybridAi) {
      final gemma = GemmaService();
      await gemma.initialize();
      _legacyModelReady = gemma.isModelReady;
      _initialised = true;
      notifyListeners();
      return; // legacy path: no hybrid availability checks
    }
    _initialised = true;
    notifyListeners();
    await refreshAvailability();
  }

  /// Re-reads connectivity and the on-device model status (no model call). Cheap; call on screen entry and retry.
  Future<InferenceAvailability> refreshAvailability() async {
    final a = await inference.availability();
    _availability = a;
    notifyListeners();
    _maybeStartDownload(a);
    return a;
  }

  /// On a supported phone the model may be DOWNLOADABLE; ask AICore to fetch it once per launch. The result of the
  /// download is never trusted (on the Galaxy A16 it reported "completed" while the status stayed UNAVAILABLE):
  /// availability is re-read from checkStatus() afterwards.
  void _maybeStartDownload(InferenceAvailability a) {
    if (_downloadStarted || a.error != null || a.onDeviceStatus != 'DOWNLOADABLE') return;
    _downloadStarted = true;
    _channel
        .downloadOnDeviceModel(cloudModel: HybridInferenceService.defaultCloudModel)
        .then((_) => refreshAvailability(), onError: (Object e) => debugPrint('On-device download failed: $e'));
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    await _store.setLanguage(lang);
    notifyListeners();
  }

  void _onConsentChanged() {
    // Availability carries the consent flag; refresh it so the UI shows the new route immediately.
    final a = _availability;
    if (a != null) {
      _availability = InferenceAvailability(
        online: a.online,
        onDeviceReady: a.onDeviceReady,
        onDeviceStatus: a.onDeviceStatus,
        cloudConsent: consent.granted,
        error: a.error,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    consent.removeListener(_onConsentChanged);
    super.dispose();
  }
}
