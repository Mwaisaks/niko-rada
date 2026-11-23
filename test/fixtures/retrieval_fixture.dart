/// Retrieval fixture: realistic, synthetic queries. No real people or phone numbers.
///
/// In-corpus: each query lists the card ids that count as a sensible top result. The test passes if any of them
/// is in the top-k returned by RagService.retrieveTopK (k = 4, the app default today). Queries marked `panic` are
/// the exact strings the panic grid sends (lib/ui/panic_grid.dart).
///
/// Out-of-corpus: must be refused (no cards) in BOTH language modes, because the UI language and the language
/// the person types in do not always match.
class InCorpusQuery {
  final String query;
  final String lang;
  final String domain;
  final Set<String> expected;
  final bool panic;
  const InCorpusQuery(this.query, this.lang, this.domain, this.expected, {this.panic = false});
}

const inCorpusQueries = <InCorpusQuery>[
  // --- first_aid ---
  InCorpusQuery('There is tear gas. What do I do right now?', 'en', 'first_aid', {'teargas-001', 'teargas-002'}, panic: true),
  InCorpusQuery('Kuna machozi ya kutoa. Nifanye nini?', 'sw', 'first_aid', {'teargas-001', 'teargas-002'}, panic: true),
  InCorpusQuery('tear gas in my eyes', 'en', 'first_aid', {'teargas-001', 'teargas-002', 'pepperspray-001'}),
  InCorpusQuery('machozi machoni', 'sw', 'first_aid', {'teargas-001', 'teargas-002', 'pepperspray-001'}),
  InCorpusQuery('My friend was hit by a rubber bullet and is bleeding', 'en', 'first_aid',
      {'firstaid-001', 'firstaid-003', 'eyeinjury-001'}),
  InCorpusQuery('Rafiki yangu anatokwa na damu nyingi', 'sw', 'first_aid', {'firstaid-003', 'firstaid-001'}),
  InCorpusQuery('Someone fainted and is not responding but still breathing', 'en', 'first_aid', {'unconscious-001', 'firstaid-002'}),
  InCorpusQuery('pepper spray in my face', 'en', 'first_aid', {'pepperspray-001', 'teargas-001'}),
  InCorpusQuery('heat exhaustion and dehydration at a long protest', 'en', 'first_aid', {'heat-001'}),
  // --- evasion_safety ---
  InCorpusQuery('I am being followed. How do I get to safety?', 'en', 'evasion_safety', {'evasion-001'}, panic: true),
  InCorpusQuery('Ninafuatwa. Nitoroje?', 'sw', 'evasion_safety', {'evasion-001'}, panic: true),
  InCorpusQuery('There is a police checkpoint ahead, what should I do?', 'en', 'evasion_safety', {'evasion-004'}),
  InCorpusQuery('Kuna kizuizi cha polisi mbele yangu', 'sw', 'evasion_safety', {'evasion-004'}),
  InCorpusQuery('The crowd is pushing and I am scared of a stampede', 'en', 'evasion_safety', {'evasion-002'}),
  InCorpusQuery('Is it safe to walk home after curfew?', 'en', 'evasion_safety', {'curfew-001'}),
  // --- blackout_comms ---
  InCorpusQuery('The network is down. How can I reach my family and contacts?', 'en', 'blackout_comms',
      {'comms-001', 'comms-002'}, panic: true),
  InCorpusQuery('Mtandao umezimwa. Ninawezaje kuwasiliana na familia yangu?', 'sw', 'blackout_comms',
      {'comms-001', 'comms-002'}, panic: true),
  InCorpusQuery('The internet is throttled, should I use a VPN?', 'en', 'blackout_comms', {'vpn-001'}),
  InCorpusQuery('How do I use Briar to send messages without internet?', 'en', 'blackout_comms', {'comms-003'}),
  InCorpusQuery('Nitapataje habari kupitia redio ya FM?', 'sw', 'blackout_comms', {'radio-001'}),
  // --- documentation ---
  InCorpusQuery('I witnessed someone being forced into a vehicle. What should I do?', 'en', 'documentation',
      {'doc-001', 'rights-003', 'contacts-missingvoices-001'}, panic: true),
  InCorpusQuery('Nimeona mtu akilazimishwa kwenye gari. Nifanye nini?', 'sw', 'documentation',
      {'doc-001', 'rights-003', 'contacts-missingvoices-001'}, panic: true),
  InCorpusQuery('How do I prepare my phone for safety at a protest?', 'en', 'documentation', {'phone-001'}, panic: true),
  InCorpusQuery('Niandae simu yangu ili niwe salama maandamano.', 'sw', 'documentation', {'phone-001'}, panic: true),
  InCorpusQuery('remove metadata from photos before sharing them', 'en', 'documentation', {'metadata-001'}),
  InCorpusQuery('Nataka kuripoti kwa mashirika ya haki za binadamu', 'sw', 'documentation', {'doc-002'}),
  // --- rights ---
  InCorpusQuery('What are my rights if I am stopped or arrested?', 'en', 'rights', {'rights-001'}, panic: true),
  InCorpusQuery('Haki zangu ni zipi nikizuiwa au kukamatwa?', 'sw', 'rights', {'rights-001'}, panic: true),
  InCorpusQuery('Can I record the police in public?', 'en', 'rights', {'recordpolice-001'}),
  InCorpusQuery('My 16 year old son was arrested by police', 'en', 'rights', {'minors-001'}),
  InCorpusQuery('Is it legal to protest in Kenya?', 'en', 'rights', {'rights-002'}),
  // --- contacts ---
  InCorpusQuery('I need a lawyer, who do I call?', 'en', 'contacts', {'contacts-lsk-001', 'contacts-001'}),
  InCorpusQuery('emergency numbers in Kenya', 'en', 'contacts', {'contacts-001'}),
  InCorpusQuery('Nambari za dharura', 'sw', 'contacts', {'contacts-001'}),
  InCorpusQuery('How do I report a disappearance?', 'en', 'contacts',
      {'contacts-missingvoices-001', 'rights-003', 'doc-002'}),
  InCorpusQuery('Ninahitaji wakili', 'sw', 'contacts', {'contacts-lsk-001', 'contacts-001'}),
];

/// Sheng panic queries (asserted at top 4). Sheng mixes Kiswahili and English, so retrieval matches both card fields.
const shengPanicQueries = <InCorpusQuery>[
  InCorpusQuery('Kuna tear gas hapa. Nisaidie!', 'sheng', 'first_aid', {'teargas-001', 'teargas-002'}, panic: true),
  InCorpusQuery('Kuna mtu ananifuata. Help!', 'sheng', 'evasion_safety', {'evasion-001'}, panic: true),
  InCorpusQuery('Nimeona mtu wakimchukua forcefully kwenye gari. Saidie!', 'sheng', 'documentation',
      {'doc-001', 'rights-003'}, panic: true),
  InCorpusQuery('Net imekufa. Naeza kureach familia yangu aje?', 'sheng', 'blackout_comms', {'comms-001', 'comms-002'}, panic: true),
  InCorpusQuery('Niandae simu yangu properly kwa safety.', 'sheng', 'documentation', {'phone-001'}, panic: true),
  InCorpusQuery('Rights zangu ni zipi nikichukuliwa na polisi?', 'sheng', 'rights', {'rights-001'}, panic: true),
];

const outOfCorpusQueries = <String>[
  // cooking
  'best chapati recipe',
  'How do I cook pilau for ten people?',
  'Nipe mapishi ya chapati',
  'Jinsi ya kupika pilau',
  // sports
  'Write me a poem about football',
  'Who won the Premier League last season?',
  'Nani alishinda mechi ya mpira jana?',
  'Niandikie shairi kuhusu mpira',
  // coding
  'Write a Python function to sort a list',
  'How do I fix a null pointer exception in Java?',
  'Niandikie programu ya Python',
  // general chat
  'Hello, how are you today?',
  'Tell me a joke',
  'What is the capital of France?',
  'Habari yako leo?',
];
