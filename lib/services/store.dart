import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/incident_report.dart';

/// Local persistence service.
/// Uses SharedPreferences for now (sufficient for <100 reports + prefs).
/// Upgrade path: Drift/SQLite for larger data sets.
class StoreService {
  StoreService._();
  static final StoreService _instance = StoreService._();
  factory StoreService() => _instance;

  static const _kLangKey = 'language';
  static const _kOnboardedKey = 'onboarded';
  static const _kReportsKey = 'reports';

  // ---------------------------------------------------------------------------
  // Language preference
  // ---------------------------------------------------------------------------

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLangKey) ?? 'en';
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, lang);
  }

  // ---------------------------------------------------------------------------
  // Onboarding flag
  // ---------------------------------------------------------------------------

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardedKey) ?? false;
  }

  Future<void> setOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardedKey, true);
  }

  // ---------------------------------------------------------------------------
  // Incident reports (pending send queue)
  // ---------------------------------------------------------------------------

  Future<void> saveReport(IncidentReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_kReportsKey) ?? [];
    existing.add(jsonEncode(report.toJson()));
    await prefs.setStringList(_kReportsKey, existing);
  }

  Future<List<IncidentReport>> getReports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kReportsKey) ?? [];
    return raw.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      return IncidentReport.fromJson(
        json,
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        rawInput: json['raw_input'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> clearReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kReportsKey);
  }

  Future<void> deleteReport(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_kReportsKey) ?? [];
    final updated = existing
        .where((s) => (jsonDecode(s) as Map)['id'] != id)
        .toList();
    await prefs.setStringList(_kReportsKey, updated);
  }
}
