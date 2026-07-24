/// Structured incident report — maps to Missing Voices / KHRC schema.
class IncidentReport {
  final String id;
  final DateTime createdAt;
  final String who;
  final String what;
  final String where;
  final String when;
  final String details;
  final String witnesses;
  final String sourceReliability;
  final String rawInput;
  bool sent;

  IncidentReport({
    required this.id,
    required this.createdAt,
    required this.who,
    required this.what,
    required this.where,
    required this.when,
    required this.details,
    required this.witnesses,
    required this.sourceReliability,
    required this.rawInput,
    this.sent = false,
  });

  factory IncidentReport.fromJson(Map<String, dynamic> json, {
    required String id,
    required DateTime createdAt,
    required String rawInput,
  }) {
    String get(String key) => (json[key] as String?) ?? 'unknown';
    return IncidentReport(
      id: id,
      createdAt: createdAt,
      who: get('who'),
      what: get('what'),
      where: get('where'),
      when: get('when'),
      details: get('details'),
      witnesses: get('witnesses'),
      sourceReliability: get('source_reliability'),
      rawInput: rawInput,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'who': who,
    'what': what,
    'where': where,
    'when': when,
    'details': details,
    'witnesses': witnesses,
    'source_reliability': sourceReliability,
    'raw_input': rawInput,
    'sent': sent,
  };

  /// Human-readable summary for display.
  String get summary => 'What: $what\nWhere: $where\nWhen: $when';
}
