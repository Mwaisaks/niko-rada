import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/incident_report.dart';
import '../services/gemma_service.dart';
import '../services/rag.dart';
import '../services/store.dart';

/// Wraps GemmaService to extract structured IncidentReport objects.
/// Handles JSON validation, "unknown" defaults, and local persistence.
class ExtractorService {
  ExtractorService._(this._modelExtract, this._rag, this._store);
  static final ExtractorService _instance =
      ExtractorService._(GemmaService().extractIncident, RagService(), StoreService());
  factory ExtractorService() => _instance;

  /// Test seam: inject the model call so the gate can be tested without a native runtime.
  factory ExtractorService.forTesting({
    required Future<String> Function(String) modelExtract,
    required RagService rag,
    required StoreService store,
  }) =>
      ExtractorService._(modelExtract, rag, store);

  final Future<String> Function(String) _modelExtract;
  final RagService _rag;
  final StoreService _store;
  final _uuid = const Uuid();

  /// Out-of-corpus gate: the same RagService gate the Guide step uses in GemmaService.answer(). If no verified card
  /// passes it, the text never reaches the model.
  bool isInCorpus(String freeText, {String lang = 'en'}) => _rag.passesGate(freeText, lang: lang);

  /// Extracts an IncidentReport from [freeText] (text or voice transcript).
  /// Saves the report to the local pending-send queue.
  /// Throws [OutOfCorpusException] (before any model call) if the text matches nothing in the corpus.
  /// Throws [ExtractionException] if parsing fails after retries.
  Future<IncidentReport> extract(String freeText, {String lang = 'en'}) async {
    await _rag.loadCards();
    if (freeText.trim().isEmpty || !isInCorpus(freeText, lang: lang)) {
      throw const OutOfCorpusException();
    }
    final rawJson = await _modelExtract(freeText);

    // Strip any markdown fences the model may have added
    final cleaned = rawJson
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      // Fallback: try to extract the first {...} block
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match == null) {
        throw ExtractionException('Model did not return valid JSON: $cleaned');
      }
      try {
        parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      } catch (e) {
        throw ExtractionException('Could not parse JSON: $e');
      }
    }

    final report = IncidentReport.fromJson(
      parsed,
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      rawInput: freeText,
    );

    await _store.saveReport(report);
    return report;
  }
}

/// Raised when an account is outside what Niko Rada's verified library covers. The model is never called.
class OutOfCorpusException implements Exception {
  const OutOfCorpusException();
  static const userMessage =
      "This doesn't match anything in Niko Rada's verified library, so it was not processed. "
      'If someone is in danger, contact a lawyer, medic or trusted organisation now.\n\n'
      'Hii hailingani na chochote katika maktaba ya Niko Rada, kwa hivyo haikushughulikiwa. '
      'Ikiwa mtu yuko hatarini, wasiliana na wakili, mhudumu wa afya au shirika unaloliamini sasa.';
  @override
  String toString() => userMessage;
}

class ExtractionException implements Exception {
  final String message;
  ExtractionException(this.message);
  @override
  String toString() => 'ExtractionException: $message';
}
