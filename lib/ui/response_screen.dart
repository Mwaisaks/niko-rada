import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../agent/answer_flow.dart';
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

/// The validated model text. Citations `[card-id]` are shown as `[1]`, `[2]` matching the Sources list.
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

  @override
  Widget build(BuildContext context) => SelectableText(
        displayText(text, cards),
        key: const Key('guided-text'),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      );
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

/// Verified contacts from the corpus. The only place phone numbers appear.
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
        Container(
          key: Key('contacts-${c.id}'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title(lang), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SelectableText(c.content(lang), style: t.bodyMedium?.copyWith(height: 1.55)),
            const SizedBox(height: 6),
            Text(c.source, style: t.bodySmall?.copyWith(color: AppTheme.onSurfaceDim)),
          ]),
        ),
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
