import '../inference/inference_service.dart';
import '../models/knowledge_card.dart';
import '../services/rag.dart';
import 'guide.dart';

/// Why the app is showing verified cards instead of a generated answer (docs/LIMITED_MODE.md).
enum LimitedReason {
  /// Offline and no on-device model: neither route can answer (the Galaxy A16 case).
  noRoute,

  /// The request needs the cloud (e.g. Kiswahili/Sheng generation) and the phone is offline.
  offline,

  /// A route exists only through the cloud and the user has not consented (or the request needs the cloud).
  noConsent,

  /// Firebase or the model status could not be read.
  notConfigured,

  /// A model call failed for another reason (cloud error, on-device error, quota...).
  modelUnavailable,

  /// The model answered, but the answer failed validation (uncited, unknown source, phone number...).
  modelOutputRejected,

  /// The model said the retrieved cards do not cover the situation; the cards are still the best verified match.
  modelNotCovered,
}

/// Verified text shown without any model: the retrieved cards verbatim and the corpus contacts.
class LimitedModeView {
  final LimitedReason reason;
  final List<KnowledgeCard> cards;
  final List<KnowledgeCard> contacts;
  const LimitedModeView(this.reason, this.cards, this.contacts);

  String banner(String lang) => AgentText.limitedBanner(reason, lang);
}

sealed class AnswerOutcome {
  const AnswerOutcome();
}

/// Out-of-corpus: fixed refusal plus the emergency contacts. No model call was made.
class AnswerRefused extends AnswerOutcome {
  final List<KnowledgeCard> contacts;
  const AnswerRefused(this.contacts);
}

/// A validated, cited model answer, with the cards it was grounded in and the contacts.
class AnswerGuided extends AnswerOutcome {
  final GuideAnswered answer;
  final List<KnowledgeCard> contacts;
  const AnswerGuided(this.answer, this.contacts);
}

/// Limited mode: verified cards and contacts, no generated text.
class AnswerLimited extends AnswerOutcome {
  final LimitedModeView view;
  const AnswerLimited(this.view);
}

/// Guide + limited mode. Order: out-of-corpus gate → pre-flight route check → one Guide call → validation.
/// Any failure after the gate falls back to limited mode; generated text is shown only when it validated.
class AnswerFlow {
  static const emergencyContactsCardId = 'contacts-001';

  AnswerFlow(this._inference, this._rag) : _guide = Guide(_inference, _rag);
  final InferenceService _inference;
  final RagService _rag;
  final Guide _guide;

  Future<AnswerOutcome> answer(String query, {String lang = 'en'}) async {
    // 1. Gate first: off-topic input never reaches availability checks or a model.
    final cards = query.trim().isEmpty ? const <KnowledgeCard>[] : _guide.retrieve(query);
    if (cards.isEmpty) return AnswerRefused(contactsFor(const []));

    // 2. Pre-flight: if no allowed route can answer, go straight to limited mode (no failed call, no spinner).
    final a = await _inference.availability();
    final needsCloud = Guide.preferenceFor(lang) == InferencePreference.onlyInCloud;
    final routeOk = needsCloud ? a.canUseCloud : a.anyRoute;
    if (!routeOk) return _limited(_preflightReason(a, needsCloud), cards);

    // 3. One grounded call; anything but a validated answer → limited mode (backstop for NO_ROUTE and friends).
    final out = await _guide.generateFor(query, cards, lang: lang);
    return switch (out) {
      GuideAnswered g => AnswerGuided(g, contactsFor(g.cards)),
      GuideRejected r => _limited(LimitedReason.modelOutputRejected, r.cards),
      GuideNotCovered n => _limited(LimitedReason.modelNotCovered, n.cards),
      GuideUnavailable u => _limited(_errorReason(u.error.code), u.cards),
      GuideRefused() => AnswerRefused(contactsFor(const [])),
    };
  }

  AnswerLimited _limited(LimitedReason reason, List<KnowledgeCard> cards) =>
      AnswerLimited(LimitedModeView(reason, cards.take(Guide.maxCards).toList(), contactsFor(cards)));

  static LimitedReason _preflightReason(InferenceAvailability a, bool needsCloud) {
    // Only called when the needed route is missing.
    if (a.error != null) return LimitedReason.notConfigured;
    if (!a.online) return needsCloud && a.onDeviceReady ? LimitedReason.offline : LimitedReason.noRoute;
    return LimitedReason.noConsent; // online, but the only usable route is the cloud and consent is off
  }

  static LimitedReason _errorReason(String code) => switch (code) {
        'NO_ROUTE' => LimitedReason.noRoute,
        'OFFLINE' => LimitedReason.offline,
        'NO_CONSENT' => LimitedReason.noConsent,
        'FIREBASE_NOT_CONFIGURED' => LimitedReason.notConfigured,
        _ => LimitedReason.modelUnavailable,
      };

  /// The emergency contacts card always, first; then any contacts cards among [cards]. Numbers only ever come from
  /// these verified corpus cards.
  List<KnowledgeCard> contactsFor(List<KnowledgeCard> cards) {
    final emergency = _rag.cardById(emergencyContactsCardId);
    return [
      ?emergency,
      for (final c in cards)
        if (c.domain == 'contacts' && c.id != emergencyContactsCardId) c,
    ];
  }
}

/// Fixed UI text for the agent flow (English / Kiswahili; Sheng uses Kiswahili).
abstract final class AgentText {
  static bool _sw(String lang) => lang == 'sw' || lang == 'sheng';

  static String limitedBanner(LimitedReason reason, String lang) {
    final sw = _sw(lang);
    return switch (reason) {
      LimitedReason.noRoute => sw
          ? 'Hakuna mtandao, na simu hii haiwezi kuendesha AI ya ndani. Tunaonyesha mwongozo uliothibitishwa kutoka maktaba.'
          : "No connection, and this phone can't run the on-device AI. Showing verified guidance from the library.",
      LimitedReason.offline => sw
          ? 'Hakuna mtandao. Tunaonyesha mwongozo uliothibitishwa wa Kiswahili kutoka maktaba.'
          : 'No connection. Showing verified guidance from the library.',
      LimitedReason.noConsent => sw
          ? 'Tunaonyesha mwongozo uliothibitishwa kutoka maktaba. AI ya mtandaoni haitumiki bila idhini yako.'
          : 'Showing verified guidance from the library. Cloud AI is not used without your permission.',
      LimitedReason.notConfigured ||
      LimitedReason.modelUnavailable ||
      LimitedReason.modelOutputRejected ||
      LimitedReason.modelNotCovered =>
        sw
            ? 'AI haikuweza kutoa jibu lililothibitishwa. Tunaonyesha mwongozo uliothibitishwa kutoka maktaba.'
            : "The AI couldn't give a verified answer. Showing verified guidance from the library.",
    };
  }

  static String refusal(String lang) => _sw(lang)
      ? 'Sina taarifa ya hilo katika maktaba yangu. Ikiwa mtu yuko hatarini, wasiliana na msaada hapa chini.'
      : "I don't have that in my library. If someone is in danger, contact the help below.";

  static String disclaimer(String lang) => _sw(lang)
      ? 'Mwongozo tu, si dhamana. Si ushauri wa kisheria au kimatibabu.'
      : 'Guidance only, not a guarantee. Not legal or medical advice.';
}
