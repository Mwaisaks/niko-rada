import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/incident_report.dart';
import '../services/gemma_service.dart';
import '../services/store.dart';

/// Wraps GemmaService to extract structured IncidentReport objects.
/// Handles JSON validation, "unknown" defaults, and local persistence.
class ExtractorService {
  ExtractorService._();
  static final ExtractorService _instance = ExtractorService._();
  factory ExtractorService() => _instance;

  final _gemma = GemmaService();
  final _store = StoreService();
  final _uuid = const Uuid();

  /// Extracts an IncidentReport from [freeText] (text or voice transcript).
  /// Saves the report to the local pending-send queue.
  /// Throws [ExtractionException] if parsing fails after retries.
  Future<IncidentReport> extract(String freeText) async {
    final rawJson = await _gemma.extractIncident(freeText);

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

class ExtractionException implements Exception {
  final String message;
  ExtractionException(this.message);
  @override
  String toString() => 'ExtractionException: $message';
}
