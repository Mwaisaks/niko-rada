import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/knowledge_card.dart';

/// Simple keyword + TF-IDF-style retrieval over the bundled corpus.
/// No external native surface — pure Dart.
///
/// Upgrade path: swap to flutter_gemma built-in embeddings + vector store
/// once the corpus grows beyond ~100 cards.
class RagService {
  RagService._();
  static final RagService _instance = RagService._();
  factory RagService() => _instance;

  List<KnowledgeCard> _cards = [];
  bool _loaded = false;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------
  Future<void> loadCards() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/corpus/cards.jsonl');
    _cards = raw
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => KnowledgeCard.fromJson(jsonDecode(line) as Map<String, dynamic>))
        .where((card) => card.verified) // exclude unverified contacts
        .toList();
    _loaded = true;
  }

  // ---------------------------------------------------------------------------
  // Retrieval
  // ---------------------------------------------------------------------------

  /// Returns the top-k most relevant cards for [query], in [lang].
  /// Optionally filters to a specific [domain].
  List<KnowledgeCard> retrieveTopK(
    String query, {
    String lang = 'en',
    String? domain,
    int k = 4,
    double threshold = 0.05,
  }) {
    final queryTokens = _tokenise(query.toLowerCase());
    if (queryTokens.isEmpty) return [];

    // Deterministic domain override — check keywords first
    final detectedDomain = domain ?? _detectDomain(query);

    // Score each card
    final scored = <_ScoredCard>[];
    for (final card in _cards) {
      if (detectedDomain != null && card.domain != detectedDomain) continue;
      final score = _score(queryTokens, card, lang);
      if (score >= threshold) {
        scored.add(_ScoredCard(card, score));
      }
    }

    // If domain filter found nothing, fall back to full corpus
    if (scored.isEmpty && detectedDomain != null) {
      for (final card in _cards) {
        final score = _score(queryTokens, card, lang);
        if (score >= threshold) {
          scored.add(_ScoredCard(card, score));
        }
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(k).map((s) => s.card).toList();
  }

  /// Formats the retrieved cards into a prompt-injectable string.
  String formatForPrompt(List<KnowledgeCard> cards, String lang) {
    if (cards.isEmpty) return '(No relevant cards found in corpus.)';
    final buffer = StringBuffer();
    for (var i = 0; i < cards.length; i++) {
      buffer.writeln('[${i + 1}] ${cards[i].title(lang)} (${cards[i].source})');
      buffer.writeln(cards[i].content(lang));
      buffer.writeln();
    }
    return buffer.toString();
  }

  bool get isLoaded => _loaded;
  int get cardCount => _cards.length;

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  double _score(List<String> queryTokens, KnowledgeCard card, String lang) {
    final cardText = '${card.title(lang)} ${card.content(lang)} ${card.domain}'
        .toLowerCase();
    final cardTokens = _tokenise(cardText);
    if (cardTokens.isEmpty) return 0;

    int matches = 0;
    for (final qt in queryTokens) {
      // Exact token match
      if (cardTokens.contains(qt)) {
        matches++;
        continue;
      }
      // Partial/stem match (simple prefix)
      for (final ct in cardTokens) {
        if (ct.startsWith(qt) || qt.startsWith(ct)) {
          matches++;
          break;
        }
      }
    }
    // Normalise by query length
    return matches / queryTokens.length;
  }

  List<String> _tokenise(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2 && !_stopWords.contains(t))
        .toList();
  }

  /// Deterministic keyword → domain mapping (fallback if router model fails).
  String? _detectDomain(String query) {
    final q = query.toLowerCase();

    if (_matchesAny(q, ['tear gas', 'machozi', 'gas', 'eyes', 'macho', 'inhale',
        'burn', 'rubber bullet', 'baton', 'struck', 'first aid', 'damu',
        'bleeding', 'shock', 'burn', 'mshtuko', 'jeraha'])) {
      return 'first_aid';
    }
    if (_matchesAny(q, ['follow', 'fuatwa', 'followed', 'checkpoint', 'kizuizi',
        'escape', 'hide', 'crowd', 'crush', 'stampede', 'msongamano', 'run'])) {
      return 'evasion_safety';
    }
    if (_matchesAny(q, ['network', 'mtandao', 'internet', 'offline', 'blackout',
        'reach', 'fikia', 'contact', 'signal', 'briar', 'rendezvous', 'kukutana',
        'wifi', 'message', 'call'])) {
      return 'blackout_comms';
    }
    if (_matchesAny(q, ['witness', 'shuhudia', 'record', 'rekodi', 'abduction',
        'utekaji', 'report', 'ripoti', 'document', 'disappeared', 'grabbed',
        'kamatwa', 'arrested'])) {
      return 'documentation';
    }
    if (_matchesAny(q, ['rights', 'haki', 'arrested', 'detained', 'lawyer',
        'protest right', 'constitution', 'katiba', 'silent'])) {
      return 'rights';
    }
    if (_matchesAny(q, ['phone', 'simu', 'prepare', 'andaa', 'encryption',
        'pin', 'surveillance', 'monitored'])) {
      return 'documentation';
    }
    if (_matchesAny(q, ['emergency', 'hospital', 'dharura', 'number', 'nambari',
        'contact', 'call', 'hotline'])) {
      return 'contacts';
    }
    return null; // no domain detected — search all
  }

  bool _matchesAny(String text, List<String> keywords) =>
      keywords.any((kw) => text.contains(kw));

  static const Set<String> _stopWords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'can', 'shall', 'to', 'of', 'in', 'on',
    'at', 'by', 'for', 'with', 'about', 'from', 'that', 'this', 'it',
    'its', 'my', 'your', 'our', 'their', 'if', 'and', 'or', 'but', 'not',
    'no', 'so', 'up', 'out', 'what', 'how', 'when', 'where', 'who', 'which',
    'na', 'ya', 'wa', 'kwa', 'ni', 'la', 'za', 'au', 'si', 'ikiwa', 'hii',
    'hilo', 'hiyo', 'yake', 'wake', 'wao', 'mimi', 'wewe', 'sisi', 'nyinyi',
  };
}

class _ScoredCard {
  final KnowledgeCard card;
  final double score;
  _ScoredCard(this.card, this.score);
}
