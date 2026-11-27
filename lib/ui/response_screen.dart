import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../agent/answer_flow.dart';
import '../models/contact_lines.dart';
import '../models/knowledge_card.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'consent_sheet.dart';
import 'route_status.dart';

/// Answer screen for panic buttons and typed questions.
///
/// Runs [AnswerFlow]: out-of-corpus gate → pre-flight route check → one grounded Guide call → validation. Shows a
/// validated, cited answer with the route that served it, or limited mode (verified cards verbatim), or the refusal.
/// Contacts always come from the verified corpus cards.
class ResponseScreen extends StatefulWidget {
  final String query;
  final String title;
  final String lang;

  const ResponseScreen({super.key, required this.query, required this.title, required this.lang});

  @override
  State<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends State<ResponseScreen> {
  AnswerOutcome? _outcome;
  bool _busy = false;

  bool get _sw => widget.lang == 'sw' || widget.lang == 'sheng';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = context.read<AppState>();
    AnswerOutcome out;
    try {
      // Fresh availability so the status strip matches what the flow sees (the flow re-checks itself).
      await state.refreshAvailability();
      out = await state.answerFlow.answer(widget.query, lang: widget.lang);
    } catch (e) {
      debugPrint('Answer flow failed: $e');
      final flow = state.answerFlow;
      out = AnswerLimited(LimitedModeView(LimitedReason.modelUnavailable, const [], flow.contactsFor(const [])));
    }
    if (!mounted) return;
    setState(() {
      _outcome = out;
      _busy = false;
    });
  }

  Future<void> _allowCloudAndRetry() async {
    final state = context.read<AppState>();
    final granted = await showCloudConsentSheet(context, state.consent, widget.lang);
    if (granted && mounted) await _run();
  }

  @override
  Widget build(BuildContext context) {
    final out = _outcome;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!_busy && out != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: _sw ? 'Jaribu tena' : 'Try again',
              onPressed: _run,
            ),
        ],
      ),
      body: Column(children: [
        const RouteStatusStrip(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _QueryEcho(text: widget.query),
              const SizedBox(height: 12),
              _EmergencyQuickCall(lang: widget.lang),
              const SizedBox(height: 16),
              if (_busy || out == null) _Thinking(lang: widget.lang) else ..._outcomeWidgets(out),
            ],
          ),
        ),
      ]),
    );
  }

  List<Widget> _outcomeWidgets(AnswerOutcome out) {
    final lang = widget.lang;
    return switch (out) {
      AnswerGuided g => [
          RouteBadge(route: g.answer.route, fallbackReason: g.answer.fallbackReason, lang: lang),
          const SizedBox(height: 16),
          _GuidedText(text: g.answer.text, cards: g.answer.cards),
          const SizedBox(height: 20),
          _SectionLabel(_sw ? 'Vyanzo' : 'Sources'),
          for (final (i, c) in g.answer.cards.indexed)
            if (g.answer.citedIds.contains(c.id)) _SourceLine(index: i + 1, card: c, lang: lang),
          const SizedBox(height: 20),
          _ContactsSection(contacts: g.contacts, lang: lang),
          _Disclaimer(lang: lang),
        ],
      AnswerLimited l => [
          _LimitedBanner(
            view: l.view,
            lang: lang,
            onAllowCloud: l.view.reason == LimitedReason.noConsent ? _allowCloudAndRetry : null,
            onRetry: _run,
          ),
          const SizedBox(height: 16),
          for (final c in l.view.cards) ...[
            _VerifiedCard(card: c, lang: lang),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          _ContactsSection(contacts: l.view.contacts, lang: lang),
          _Disclaimer(lang: lang),
        ],
      AnswerRefused r => [
          Container(
            key: const Key('refusal'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Text(AgentText.refusal(lang), style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
          ),
          const SizedBox(height: 20),
          _ContactsSection(contacts: r.contacts, lang: lang),
          _Disclaimer(lang: lang),
        ],
    };
  }
}

class _QueryEcho extends StatelessWidget {
  const _QueryEcho({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
}

class _Thinking extends StatelessWidget {
  const _Thinking({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 10),
        Text(lang == 'sw' || lang == 'sheng' ? 'Inatafuta mwongozo…' : 'Finding verified guidance…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceDim)),
      ]);
}

/// The validated model text, one row per numbered step. Citations `[card-id]` are shown as `[1]`, `[2]` matching the
/// Sources list.
class _GuidedText extends StatelessWidget {
  const _GuidedText({required this.text, required this.cards});
  final String text;
  final List<KnowledgeCard> cards;

  static String displayText(String text, List<KnowledgeCard> cards) {
    var t = text;
    for (final (i, c) in cards.indexed) {
      t = t.replaceAll('[${c.id}]', '[${i + 1}]');
    }
    return t;
  }

  static final _stepRe = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
  static final _refsRe = RegExp(r'(\s*\[\d+\])+\s*$');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = <Widget>[];
    for (final line in displayText(text, cards).split('\n')) {
      final m = _stepRe.firstMatch(line);
      if (m == null) continue;
      final body = m.group(2)!;
      final refs = _refsRe.firstMatch(body)?.group(0)?.trim() ?? '';
      final sentence = body.substring(0, body.length - (_refsRe.firstMatch(body)?.group(0)?.length ?? 0)).trim();
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Text(m.group(1)!,
                style: t.labelLarge?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: sentence),
                  if (refs.isNotEmpty)
                    TextSpan(
                        text: ' $refs',
                        style: t.bodySmall?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                ]),
                style: t.bodyLarge?.copyWith(height: 1.45, color: AppTheme.onBackground),
              ),
            ),
          ),
        ]),
      ));
    }
    return Semantics(
      container: true,
      child: Column(key: const Key('guided-text'), crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.onSurfaceDim, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
      );
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.index, required this.card, required this.lang});
  final int index;
  final KnowledgeCard card;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('[$index] ', style: t.bodyMedium?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w700)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(card.title(lang), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('${card.source} · ${card.sourceUrl}', style: t.bodySmall?.copyWith(color: AppTheme.onSurfaceDim)),
          ]),
        ),
      ]),
    );
  }
}

class _LimitedBanner extends StatelessWidget {
  const _LimitedBanner({required this.view, required this.lang, required this.onRetry, this.onAllowCloud});
  final LimitedModeView view;
  final String lang;
  final VoidCallback onRetry;
  final VoidCallback? onAllowCloud;

  @override
  Widget build(BuildContext context) {
    final sw = lang == 'sw' || lang == 'sheng';
    final t = Theme.of(context).textTheme;
    return Container(
      key: const Key('limited-banner'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.menu_book_rounded, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(view.banner(lang), style: t.bodyMedium?.copyWith(height: 1.45))),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (onAllowCloud != null)
            FilledButton.tonalIcon(
              key: const Key('allow-cloud'),
              onPressed: onAllowCloud,
              icon: const Icon(Icons.cloud_outlined, size: 18),
              label: Text(sw ? 'Ruhusu AI ya mtandaoni' : 'Allow cloud AI'),
            ),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(sw ? 'Jaribu tena' : 'Try again'),
          ),
        ]),
      ]),
    );
  }
}

/// A verified corpus card shown verbatim (no model), with its citation.
class _VerifiedCard extends StatelessWidget {
  const _VerifiedCard({required this.card, required this.lang});
  final KnowledgeCard card;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_outlined, size: 16, color: AppTheme.safe),
          const SizedBox(width: 6),
          Expanded(child: Text(card.title(lang), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        SelectableText(card.content(lang), style: t.bodyMedium?.copyWith(height: 1.55)),
        const SizedBox(height: 10),
        Text('${card.source} · ${card.sourceUrl}', style: t.bodySmall?.copyWith(color: AppTheme.onSurfaceDim)),
      ]),
    );
  }
}

/// Opens the phone's dialer with a verified number (no call is placed without the person pressing call).
Future<void> _dial(BuildContext context, String number, String lang) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: ContactLines.dialString(number))).catchError((_) => false);
  if (!ok && context.mounted) {
    final sw = lang == 'sw' || lang == 'sheng';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sw ? 'Haikuweza kufungua simu. Piga $number' : "Couldn't open the dialer. Dial $number"),
    ));
  }
}

/// One verified number as a large, tappable call button.
class _CallButton extends StatelessWidget {
  const _CallButton({required this.number, required this.lang, this.prominent = false});
  final String number;
  final String lang;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final sw = lang == 'sw' || lang == 'sheng';
    final label = Text(number, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3));
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
      backgroundColor: WidgetStatePropertyAll(prominent ? AppTheme.danger : AppTheme.danger.withValues(alpha: 0.18)),
      foregroundColor: WidgetStatePropertyAll(prominent ? Colors.white : AppTheme.onBackground),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
    return Semantics(
      button: true,
      label: sw ? 'Piga $number' : 'Call $number',
      excludeSemantics: true,
      child: FilledButton.icon(
        key: Key('call-$number'),
        style: style,
        onPressed: () => _dial(context, number, lang),
        icon: const Icon(Icons.call_rounded, size: 18),
        label: label,
      ),
    );
  }
}

/// The first line of the verified emergency contacts card (999 / 112) as call buttons, near the top of every answer.
class _EmergencyQuickCall extends StatelessWidget {
  const _EmergencyQuickCall({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    final card = context.read<AppState>().answerFlow.contactsFor(const []).firstOrNull;
    if (card == null) return const SizedBox.shrink();
    final calls = ContactLines.parse(card.content(lang)).calls;
    if (calls.isEmpty) return const SizedBox.shrink();
    final first = calls.first;
    final t = Theme.of(context).textTheme;
    return Container(
      key: const Key('emergency-quick-call'),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(first.label,
              style: t.bodyMedium?.copyWith(color: AppTheme.onBackground, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        for (final (i, n) in first.numbers.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          _CallButton(number: n, lang: lang, prominent: true),
        ],
      ]),
    );
  }
}

/// Verified contacts from the corpus. The only place phone numbers appear; each number is a call button.
class _ContactsSection extends StatelessWidget {
  const _ContactsSection({required this.contacts, required this.lang});
  final List<KnowledgeCard> contacts;
  final String lang;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) return const SizedBox.shrink();
    final sw = lang == 'sw' || lang == 'sheng';
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(sw ? 'Msaada uliothibitishwa' : 'Verified help'),
      for (final c in contacts)
        Builder(builder: (context) {
          final lines = ContactLines.parse(c.content(lang));
          return Container(
            key: Key('contacts-${c.id}'),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.verified_outlined, size: 16, color: AppTheme.safe),
                const SizedBox(width: 6),
                Expanded(child: Text(c.title(lang), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              ]),
              for (final l in lines.calls) ...[
                SizedBox(height: l.continued ? 8 : 14),
                Text(l.label,
                    style: l.continued
                        ? t.bodySmall?.copyWith(color: AppTheme.onSurfaceDim)
                        : t.bodyMedium?.copyWith(color: AppTheme.onBackground, fontWeight: FontWeight.w600)),
                if (l.detail != null)
                  Text(l.detail!, style: t.bodySmall?.copyWith(color: AppTheme.onSurfaceDim)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final n in l.numbers) _CallButton(number: n, lang: lang),
                ]),
              ],
              if (lines.texts.isNotEmpty) const SizedBox(height: 14),
              for (final tl in lines.texts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.rich(
                    TextSpan(children: [
                      if (tl.label != null)
                        TextSpan(text: '${tl.label}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: tl.text),
                    ]),
                    style: t.bodySmall?.copyWith(color: AppTheme.onSurface, height: 1.45),
                  ),
                ),
              const SizedBox(height: 4),
              Text(c.source, style: t.bodySmall?.copyWith(color: AppTheme.onSurfaceDim)),
            ]),
          );
        }),
    ]);
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(AgentText.disclaimer(lang),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceDim, fontStyle: FontStyle.italic)),
      );
}
