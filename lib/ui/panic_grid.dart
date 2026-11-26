import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import 'response_screen.dart';
import 'route_status.dart';

/// F2 — Panic quick-action grid.
/// Large bilingual buttons, each pre-seeds a query → grounded answer.
class PanicGrid extends StatelessWidget {
  const PanicGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    final actions = _panicActions(lang);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(children: [
          const RouteStatusStrip(),
          Expanded(child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang == 'sw' ? 'Niko Rada' : 'Niko Rada',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppTheme.primary, fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      lang == 'sw'
                          ? 'Msaidizi wa usalama — mwongozo uliothibitishwa, hata bila mtandao'
                          : lang == 'sheng'
                              ? 'Safety msaidizi — verified guidance, hata bila net'
                              : 'Safety companion — verified guidance, even offline',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceDim),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      lang == 'sw' ? 'Chagua hali yako:' : lang == 'sheng' ? 'Chagua situation:' : 'What\'s happening:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _PanicButton(action: actions[i]),
                  childCount: actions.length,
                ),
              ),
            ),
          ],
        )),
        ]),
      ),
    );
  }

  List<_PanicAction> _panicActions(String lang) => [
    _PanicAction(
      emoji: '😤',
      labelEn: 'Tear Gas',
      labelSw: 'Machozi ya kutoa',
      labelSheng: 'Tear Gas!',
      query: lang == 'sw'
          ? 'Kuna machozi ya kutoa. Nifanye nini?'
          : lang == 'sheng'
              ? 'Kuna tear gas hapa. Nisaidie!'
              : 'There is tear gas. What do I do right now?',
      accent: AppTheme.danger,
      lang: lang,
    ),
    _PanicAction(
      emoji: '🏃',
      labelEn: 'Being Followed',
      labelSw: 'Ninafuatwa',
      labelSheng: 'Ninafuatwa!',
      query: lang == 'sw'
          ? 'Ninafuatwa. Nitoroje?'
          : lang == 'sheng'
              ? 'Kuna mtu ananifuata. Help!'
              : 'I am being followed. How do I get to safety?',
      accent: const Color(0xFFFF6F00),
      lang: lang,
    ),
    _PanicAction(
      emoji: '🚗',
      labelEn: 'Someone Was Grabbed',
      labelSw: 'Alikamatwa',
      labelSheng: 'Walichukua mtu!',
      query: lang == 'sw'
          ? 'Nimeona mtu akilazimishwa kwenye gari. Nifanye nini?'
          : lang == 'sheng'
              ? 'Nimeona mtu wakimchukua forcefully kwenye gari. Saidie!'
              : 'I witnessed someone being forced into a vehicle. What should I do?',
      accent: AppTheme.danger,
      lang: lang,
    ),
    _PanicAction(
      emoji: '📵',
      labelEn: 'Reach My People',
      labelSw: 'Fikia watu wangu',
      labelSheng: 'Niwasiliane na watu wangu',
      query: lang == 'sw'
          ? 'Mtandao umezimwa. Ninawezaje kuwasiliana na familia yangu?'
          : lang == 'sheng'
              ? 'Net imekufa. Naeza kureach familia yangu aje?'
              : 'The network is down. How can I reach my family and contacts?',
      accent: AppTheme.info,
      lang: lang,
    ),
    _PanicAction(
      emoji: '📱',
      labelEn: 'Prepare My Phone',
      labelSw: 'Andaa simu yangu',
      labelSheng: 'Set up simu yangu',
      query: lang == 'sw'
          ? 'Niandae simu yangu ili niwe salama maandamano.'
          : lang == 'sheng'
              ? 'Niandae simu yangu properly kwa safety.'
              : 'How do I prepare my phone for safety at a protest?',
      accent: AppTheme.safe,
      lang: lang,
    ),
    _PanicAction(
      emoji: '⚖️',
      labelEn: 'My Rights',
      labelSw: 'Haki zangu',
      labelSheng: 'Rights zangu',
      query: lang == 'sw'
          ? 'Haki zangu ni zipi nikizuiwa au kukamatwa?'
          : lang == 'sheng'
              ? 'Rights zangu ni zipi nikichukuliwa na polisi?'
              : 'What are my rights if I am stopped or arrested?',
      accent: AppTheme.primary,
      lang: lang,
    ),
  ];
}

class _PanicAction {
  final String emoji;
  final String labelEn;
  final String labelSw;
  final String labelSheng;
  final String query;
  final Color accent;
  final String lang;

  const _PanicAction({
    required this.emoji,
    required this.labelEn,
    required this.labelSw,
    required this.labelSheng,
    required this.query,
    required this.accent,
    required this.lang,
  });

  String get label =>
      lang == 'sw' ? labelSw : lang == 'sheng' ? labelSheng : labelEn;
}

class _PanicButton extends StatefulWidget {
  final _PanicAction action;
  const _PanicButton({required this.action});

  @override
  State<_PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<_PanicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResponseScreen(
        query: widget.action.query,
        title: widget.action.label,
        lang: widget.action.lang,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          decoration: AppTheme.panicButtonDecoration(a.accent),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.emoji, style: const TextStyle(fontSize: 32)),
              const Spacer(),
              Text(
                a.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
