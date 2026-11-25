import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/knowledge_card.dart';

/// Deterministic keyword retrieval over the bundled corpus, and the out-of-corpus gate. Pure Dart, no model.
///
/// How a query is matched (designed to be explainable):
/// 1. Tokenise: lowercase, split on non-letters, drop stopwords (English + Kiswahili + generic chat words) and words
///    shorter than 3 letters (except a few short domain terms such as "fm", "sms", "vpn").
/// 2. Each word becomes a small set of forms: the word itself, an English stem ("arrested" → "arrest") and a
///    Kiswahili stem ("ninafuatwa" → "fuatwa" → "fuat"). Stems shorter than 4 letters are discarded.
///    There is NO raw prefix matching ("chapati" does not match "cha"; "football" does not match "foot").
/// 3. A query word matches a card if any of its forms appears among the card's forms. Cards are matched against
///    both their English and Kiswahili text, because people code-switch (Sheng, mixed EN/SW).
/// 4. **Gate:** a card counts only if at least [minDistinctTerms] different query words match it, or, for short
///    queries, if the matching words cover at least [minCoverage] of the query's words.
///    If no card counts, retrieval returns nothing and callers refuse before any model call.
/// 5. Ranking among cards that pass: sum of IDF weights of the matched words (rarer words count more), plus a small
///    boost when the query mentions a domain keyword. Domain keywords only boost; they never filter cards out.
class RagService {
  RagService._();
  static final RagService _instance = RagService._();
  factory RagService() => _instance;

  /// A card must match at least this many distinct query words...
  static const minDistinctTerms = 2;

  /// ...or, with fewer matches, the matched words must cover at least this share of the query's words.
  static const minCoverage = 0.5;

  static const _domainBoost = 0.5;

  List<KnowledgeCard> _cards = [];
  List<Set<String>> _cardForms = [];

  /// Every single word that appears in any card (both languages), lowercase. Used to join query word pairs.
  Set<String> _cardWords = {};
  Map<String, double> _idfCache = {};
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
    _cardForms = [
      for (final c in _cards)
        {
          for (final t in tokenise('${c.titleEn} ${c.contentEn}')) ...formsOf(t, english: true, kiswahili: false),
          for (final t in tokenise('${c.titleSw} ${c.contentSw}')) ...formsOf(t, english: false, kiswahili: true),
          // "tear gas" in a card also matches a query that writes "teargas" (likewise "wi-fi" → "wifi").
          for (final t in compoundsOf('${c.titleEn} ${c.contentEn}')) ...formsOf(t, english: true, kiswahili: false),
          for (final t in compoundsOf('${c.titleSw} ${c.contentSw}')) ...formsOf(t, english: false, kiswahili: true),
        }
    ];
    _cardWords = {
      for (final c in _cards) ..._words('${c.titleEn} ${c.contentEn} ${c.titleSw} ${c.contentSw}'),
    };
    _idfCache = {};
    _loaded = true;
  }

  // ---------------------------------------------------------------------------
  // Retrieval + gate
  // ---------------------------------------------------------------------------

  /// Returns the top-k cards for [query] that pass the gate. Empty means "out of corpus": refuse.
  /// [lang] is kept for API compatibility; matching uses both card languages, display uses [lang].
  List<KnowledgeCard> retrieveTopK(String query, {String lang = 'en', int k = 4}) =>
      explain(query).take(k).map((m) => m.card).toList();

  /// The single out-of-corpus gate shared by Guide (GemmaService.answer) and extraction (ExtractorService).
  bool passesGate(String query, {String lang = 'en'}) => retrieveTopK(query, lang: lang, k: 1).isNotEmpty;

  /// All cards that pass the gate, best first, with the words that matched (for debugging and tests).
  List<RetrievalMatch> explain(String query) {
    final terms = tokenise(_joinCorpusCompounds(query)).toSet().toList();
    if (terms.isEmpty) return const [];
    final termForms = {for (final t in terms) t: formsOf(t, english: true, kiswahili: true)};
    final domains = _detectDomains(query);

    final matches = <RetrievalMatch>[];
    for (var i = 0; i < _cards.length; i++) {
      final forms = _cardForms[i];
      final matched = [for (final t in terms) if (termForms[t]!.any(forms.contains)) t];
      if (matched.isEmpty) continue;
      final coverage = matched.length / terms.length;
      if (matched.length < minDistinctTerms && coverage < minCoverage) continue; // the gate
      var score = 0.0;
      for (final t in matched) {
        score += _idf(t, termForms[t]!);
      }
      score += _domainBoost * (domains[_cards[i].domain] ?? 0);
      matches.add(RetrievalMatch(_cards[i], matched, score));
    }
    matches.sort((a, b) => b.score.compareTo(a.score)); // stable: ties keep corpus order
    return matches;
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

  /// A verified card by id (e.g. the emergency contacts card), or null.
  KnowledgeCard? cardById(String id) {
    for (final c in _cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool get isLoaded => _loaded;
  int get cardCount => _cards.length;

  // ---------------------------------------------------------------------------
  // Tokenising and stemming (public static for tests)
  // ---------------------------------------------------------------------------

  static List<String> _words(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Adjacent word pairs written as one word ("tear gas" → "teargas"), skipping pairs with a stopword in them.
  static List<String> compoundsOf(String text) {
    final w = _words(text);
    return [
      for (var i = 0; i + 1 < w.length; i++)
        if (!_stopWords.contains(w[i]) && !_stopWords.contains(w[i + 1]) && (w[i] + w[i + 1]).length >= 4)
          w[i] + w[i + 1],
    ];
  }

  /// Joins two adjacent query words when the corpus writes them as one word ("check point" → "checkpoint").
  String _joinCorpusCompounds(String query) {
    final w = _words(query);
    final out = <String>[];
    for (var i = 0; i < w.length; i++) {
      if (i + 1 < w.length && _cardWords.contains(w[i] + w[i + 1]) && (w[i] + w[i + 1]).length >= 4) {
        out.add(w[i] + w[i + 1]);
        i++;
      } else {
        out.add(w[i]);
      }
    }
    return out.join(' ');
  }

  static List<String> tokenise(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => (t.length >= 3 || _shortTerms.contains(t)) && !_isStop(t))
      .toList();

  static bool _isStop(String t) {
    if (_stopWords.contains(t)) return true;
    // Kiswahili verbs carry subject/tense prefixes: "ninahitaji" is the generic "I need".
    final sw = _swStripPrefixes(t);
    return sw != t && _stopWords.contains(sw);
  }

  /// The word plus its stems (stems must be at least 4 letters), plus a synonym-group tag if it has one.
  static Set<String> formsOf(String t, {required bool english, required bool kiswahili}) {
    final forms = <String>{t};
    final group = _synonyms[t];
    if (group != null) forms.add(group);
    if (english) {
      final s = enStem(t);
      if (s.length >= 4) forms.add(s);
    }
    if (kiswahili) {
      for (final s in swStems(t)) {
        if (s.length >= 4) forms.add(s);
      }
    }
    return forms;
  }

  /// Light English suffix stemmer: "arrested" → "arrest", "followed"/"following" → "follow", "share"/"sharing" →
  /// "shar", "stopped" → "stop", "photos" → "photo".
  static String enStem(String w) {
    if (w.length <= 3) return w;
    var s = w;
    if (s.endsWith('ies') && s.length > 4) {
      s = '${s.substring(0, s.length - 3)}y';
    } else if (s.endsWith('sses')) {
      s = s.substring(0, s.length - 2);
    } else if (s.endsWith('ing') && s.length - 3 >= 3) {
      s = s.substring(0, s.length - 3);
    } else if (s.endsWith('ed') && s.length - 2 >= 3) {
      s = s.substring(0, s.length - 2);
    } else if (s.endsWith('es') && RegExp(r'(s|x|z|ch|sh)es$').hasMatch(s)) {
      s = s.substring(0, s.length - 2);
    } else if (s.endsWith('s') && !s.endsWith('ss') && !s.endsWith('us') && !s.endsWith('is')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('ly') && s.length > 5) s = s.substring(0, s.length - 2);
    if (s.length > 3 && RegExp(r'([bcdfgkmnprt])\1$').hasMatch(s)) s = s.substring(0, s.length - 1);
    if (s.length > 3 && s.endsWith('e')) s = s.substring(0, s.length - 1);
    return s;
  }

  // Subject + tense prefixes ("ni-na-", "u-me-", "a-ki-"). The infinitive "ku-" and habitual "hu-" are never
  // followed by a tense marker, so they are stripped alone: "kutapika" → "tapika", not "pika" (which would
  // wrongly match "kupika", to cook).
  static final _swInfinitive = RegExp(r'^(ku|hu)');
  static final _swPrefix = RegExp(r'^(ni|u|a|tu|m|wa|i|li|ki|vi|zi)?(na|li|ta|me|ki|ka|nge)?');

  static String _swStripPrefixes(String w) {
    final inf = _swInfinitive.firstMatch(w);
    final m = inf ?? _swPrefix.firstMatch(w);
    final stripped = m == null ? w : w.substring(m.end);
    return stripped.length >= 3 ? stripped : w;
  }

  /// Kiswahili stems: strip subject/tense prefixes, then the passive "-wa", then a final vowel.
  /// "ninafuatwa"/"unafuatwa" → "fuatwa", "fuat"; "kukamatwa"/"ukikamatwa" → "kamatwa", "kamat".
  /// The unprefixed word minus its final vowel is kept too, because a verb root can itself start with a letter that
  /// looks like a prefix: "andaa" (prepare) → "anda", which "niandae" → "andae" → "anda" also reaches.
  /// After a subject+tense prefix (or the infinitive "ku-"), a verb may carry an object marker:
  /// "a-na-ni-fuata" (he is following me), "wa-me-m-kamata" (they arrested him), "ku-m-fuata" (to follow him).
  /// Object markers are only stripped in that position, never from the start of a bare word.
  static final _swObject = RegExp(r'^(ni|ku|mw|m|wa|tu|ki|vi|zi|li|ya|i|u)');

  static List<String> swStems(String w) {
    final out = <String>[];
    if (RegExp(r'[aeiou]$').hasMatch(w) && w.length > 4) out.add(w.substring(0, w.length - 1));
    final s = _swStripPrefixes(w);
    if (s != w) {
      out.addAll(_swSuffixVariants(s));
      final hadTenseOrInfinitive = _swInfinitive.hasMatch(w) || (_swPrefix.firstMatch(w)?.group(2) != null);
      final o = _swObject.firstMatch(s);
      if (hadTenseOrInfinitive && o != null && s.length - o.end >= 4) out.addAll(_swSuffixVariants(s.substring(o.end)));
    }
    return out;
  }

  /// The stem itself, minus the passive "-wa", and minus a final vowel: "fuatwa" → "fuatwa", "fuat".
  static List<String> _swSuffixVariants(String s) {
    final out = <String>[s];
    var t = s;
    if (t.endsWith('wa') && t.length > 5) {
      t = t.substring(0, t.length - 2);
      out.add(t);
    }
    if (RegExp(r'[aeiou]$').hasMatch(t) && t.length > 4) out.add(t.substring(0, t.length - 1));
    return out;
  }

  double _idf(String term, Set<String> forms) => _idfCache.putIfAbsent(term, () {
        final df = _cardForms.where((cf) => forms.any(cf.contains)).length;
        return math.log((_cards.length + 1) / (df + 1)) + 1;
      });

  /// Domain keywords (whole words / phrases). They only boost ranking; they never remove cards.
  Map<String, int> _detectDomains(String query) {
    final q = ' ${query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')} ';
    final hits = <String, int>{};
    _domainKeywords.forEach((domain, keywords) {
      final n = keywords.where((kw) => q.contains(' $kw ')).length;
      if (n > 0) hits[domain] = n;
    });
    return hits;
  }

  static const Map<String, List<String>> _domainKeywords = {
    'first_aid': ['tear gas', 'machozi', 'eyes', 'macho', 'burn', 'burns', 'rubber bullet', 'baton', 'bleeding',
        'damu', 'shock', 'mshtuko', 'jeraha', 'injury', 'injured', 'first aid', 'fainted', 'breathing'],
    'evasion_safety': ['followed', 'following me', 'ninafuatwa', 'checkpoint', 'kizuizi', 'escape', 'hide',
        'crowd', 'stampede', 'msongamano', 'curfew'],
    'blackout_comms': ['network', 'mtandao', 'internet', 'offline', 'blackout', 'signal', 'briar', 'wifi',
        'vpn', 'radio', 'redio', 'sms'],
    'documentation': ['witness', 'witnessed', 'shuhudia', 'nimeona', 'forced', 'forcefully', 'grabbed',
        'record what', 'abduction', 'utekaji', 'document',
        'evidence', 'ushahidi', 'metadata', 'photos', 'prepare my phone', 'simu yangu'],
    'rights': ['rights', 'haki', 'arrested', 'detained', 'kukamatwa', 'constitution', 'katiba', 'legal', 'protest'],
    'contacts': ['lawyer', 'wakili', 'emergency', 'dharura', 'number', 'numbers', 'nambari', 'hotline', 'call'],
  };

  /// Small, explicit synonym groups (EN/SW). A word in a group also matches the group tag, so "son" matches a card
  /// that says "child", and "police" matches "officer". Kept deliberately short; "minor" is excluded because the
  /// burns card uses it to mean "small".
  static const Map<String, String> _synonyms = {
    'police': '@police', 'polisi': '@police', 'officer': '@police', 'officers': '@police', 'cop': '@police',
    'cops': '@police', 'askari': '@police',
    'child': '@child', 'children': '@child', 'minors': '@child', 'son': '@child', 'daughter': '@child',
    'kid': '@child', 'kids': '@child', 'boy': '@child', 'girl': '@child', 'teenager': '@child', 'teen': '@child',
    'mtoto': '@child', 'watoto': '@child', 'binti': '@child',
    // Abduction accounts say "car"; the witnessing card says "vehicle" (EN) and "gari" (SW).
    'car': '@vehicle', 'cars': '@vehicle', 'vehicle': '@vehicle', 'vehicles': '@vehicle', 'gari': '@vehicle',
    'magari': '@vehicle',
  };

  /// Two-letter domain terms that would otherwise be dropped as "too short".
  static const Set<String> _shortTerms = {'fm', 'oc', 'id'};

  static const Set<String> _stopWords = {
    // English function words
    'the', 'and', 'are', 'was', 'were', 'been', 'being', 'have', 'has', 'had', 'does', 'did', 'will', 'would',
    'could', 'should', 'may', 'might', 'can', 'shall', 'for', 'with', 'about', 'from', 'that', 'this', 'its',
    'your', 'our', 'their', 'not', 'out', 'what', 'how', 'when', 'where', 'who', 'which', 'why', 'there', 'here',
    'them', 'they', 'him', 'her', 'his', 'she', 'you', 'yours', 'mine', 'into', 'onto', 'than', 'then', 'also',
    'any', 'all', 'some', 'very', 'just', 'too', 'now', 'right', 'still', 'but', 'yet', 'over', 'under',
    // English generic chat / request words
    'please', 'help', 'tell', 'give', 'need', 'want', 'get', 'got', 'make', 'know', 'write', 'show', 'like',
    'best', 'good', 'new', 'one', 'two', 'ten', 'today', 'yesterday', 'tomorrow', 'last', 'next', 'people',
    'someone', 'something', 'thing', 'things', 'way', 'hello', 'thanks', 'thank', 'okay',
    // Kiswahili function words
    'kwa', 'hii', 'hilo', 'hiyo', 'yake', 'wake', 'wao', 'mimi', 'wewe', 'sisi', 'nyinyi', 'ikiwa', 'yangu',
    'yako', 'yetu', 'yenu', 'zangu', 'zako', 'wangu', 'wako', 'nini', 'gani', 'zipi', 'kama', 'lakini', 'pia',
    'sana', 'hapa', 'pale', 'huko', 'leo', 'jana', 'kesho', 'sasa', 'kuna', 'ili', 'hadi', 'kwenye', 'katika',
    'kutoka', 'kuhusu', 'jinsi', 'nani', 'bila', 'baada', 'kabla', 'tena',
    // Kiswahili generic verbs / greetings (matched after prefix stripping, e.g. "ninahitaji" → "hitaji")
    'hitaji', 'taka', 'fanye', 'fanya', 'sema', 'pe', 'habari', 'jambo', 'mambo', 'asante', 'saidie', 'saidia',
  };
}

/// One card that passed the gate, with the query words that matched it.
class RetrievalMatch {
  final KnowledgeCard card;
  final List<String> matchedTerms;
  final double score;
  const RetrievalMatch(this.card, this.matchedTerms, this.score);
  @override
  String toString() => '${card.id} ${score.toStringAsFixed(2)} $matchedTerms';
}
