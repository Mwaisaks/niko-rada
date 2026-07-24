/// Knowledge card model — mirrors the JSONL schema in assets/corpus/cards.jsonl
class KnowledgeCard {
  final String id;
  final String domain;
  final String titleEn;
  final String titleSw;
  final String contentEn;
  final String contentSw;
  final String source;
  final String sourceUrl;
  final String region;
  final bool verified;

  const KnowledgeCard({
    required this.id,
    required this.domain,
    required this.titleEn,
    required this.titleSw,
    required this.contentEn,
    required this.contentSw,
    required this.source,
    required this.sourceUrl,
    required this.region,
    required this.verified,
  });

  factory KnowledgeCard.fromJson(Map<String, dynamic> json) {
    return KnowledgeCard(
      id: json['id'] as String,
      domain: json['domain'] as String,
      titleEn: json['title_en'] as String,
      titleSw: json['title_sw'] as String,
      contentEn: json['content_en'] as String,
      contentSw: json['content_sw'] as String,
      source: json['source'] as String,
      sourceUrl: json['source_url'] as String,
      region: json['region'] as String,
      verified: json['verified'] as bool,
    );
  }

  /// Returns the title in the given language (falls back to English).
  String title(String lang) {
    if (lang == 'sw' || lang == 'sheng') return titleSw;
    return titleEn;
  }

  /// Returns the content in the given language (falls back to English).
  String content(String lang) {
    if (lang == 'sw' || lang == 'sheng') return contentSw;
    return contentEn;
  }
}

/// Supported corpus domains.
enum CorpusDomain {
  firstAid,
  evasionSafety,
  blackoutComms,
  documentation,
  contacts,
  rights,
  general;

  static CorpusDomain fromString(String s) {
    switch (s) {
      case 'first_aid':
        return CorpusDomain.firstAid;
      case 'evasion_safety':
        return CorpusDomain.evasionSafety;
      case 'blackout_comms':
        return CorpusDomain.blackoutComms;
      case 'documentation':
        return CorpusDomain.documentation;
      case 'contacts':
        return CorpusDomain.contacts;
      case 'rights':
        return CorpusDomain.rights;
      default:
        return CorpusDomain.general;
    }
  }
}
