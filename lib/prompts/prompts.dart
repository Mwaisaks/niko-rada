/// Prompt templates for Niko Rada.
/// Three prompts: grounded answer, structured extraction, optional keyword router.
class Prompts {
  Prompts._();

  // ---------------------------------------------------------------------------
  // (a) Grounded generation — used for panic buttons and free-text chat.
  //     Model must ONLY use the provided SOURCES. Refuses if uncovered.
  // ---------------------------------------------------------------------------
  static String groundedAnswer({
    required String query,
    required String retrievedCards,
    required String language,
  }) {
    final langInstruction = _languageInstruction(language);
    return '''
You are Niko Rada, an offline safety companion built to help people in Kenya during protests, network blackouts, and emergencies.

RULES (non-negotiable):
1. Answer ONLY using the SOURCES provided below. Do not use any external knowledge.
2. If the SOURCES do not cover the question, say exactly: "Sina taarifa ya hilo katika maktaba yangu / I don't have that in my library. Please consult a doctor, lawyer, or trusted authority." Do not guess or invent.
3. Be CALM, CONCRETE, and BRIEF. Use numbered steps. Most important action first.
4. $langInstruction
5. End every answer with this disclaimer on its own line: "_Mwongozo tu, si dhamana. Si ushauri wa kisheria au kimatibabu. / Guidance only, not a guarantee. Not legal or medical advice._"
6. Cite the source of your answer using [Source Name] at the end of your answer, before the disclaimer.

SOURCES:
$retrievedCards

USER SITUATION: $query
''';
  }

  // ---------------------------------------------------------------------------
  // (b) Structured extraction — for the incident logger.
  //     Output MUST be valid JSON only. No preamble, no markdown fences.
  // ---------------------------------------------------------------------------
  static String extractIncident(String freeText) {
    return '''
Extract a structured incident report from the account below.
Output ONLY valid JSON with exactly these fields:
{
  "who": "description of person(s) taken or involved",
  "what": "what happened",
  "where": "location — street, landmark, area",
  "when": "time and date if mentioned",
  "details": "any additional details — vehicle, clothing, uniforms, what was said",
  "witnesses": "any witnesses mentioned",
  "source_reliability": "firsthand / secondhand / unknown"
}
Use "unknown" for any field that is not mentioned. Do NOT invent details.
Output ONLY the JSON object. No explanation, no markdown, no extra text.

ACCOUNT: $freeText
''';
  }

  // ---------------------------------------------------------------------------
  // (c) Optional keyword router — maps input to a corpus domain.
  //     Used to filter retrieval. Falls back to deterministic keyword matching.
  // ---------------------------------------------------------------------------
  static String routeQuery(String query) {
    return '''
Classify the user's safety query into exactly ONE of these domains:
first_aid | evasion_safety | blackout_comms | documentation | contacts | rights | general

Rules: output ONLY the domain label. No explanation.

QUERY: $query
''';
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------
  static String _languageInstruction(String lang) {
    switch (lang) {
      case 'sw':
        return 'Reply in Kiswahili. Use clear, simple Kiswahili that any Kenyan can understand.';
      case 'sheng':
        return 'Reply in Sheng — the Nairobi street mix of Kiswahili and English. '
            'Keep it natural and conversational, as a Nairobi young person would speak. '
            'Mix Sheng vocabulary (e.g. sema, fanya, gari, fiti, mbaya) with clear Kiswahili for safety terms.';
      default:
        return 'Reply in English.';
    }
  }
}
