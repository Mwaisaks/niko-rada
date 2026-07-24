import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

/// F4 — Language toggle + app settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(lang == 'sw' ? 'Mipangilio' : 'Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Language section
          Text(
            lang == 'sw' ? 'Lugha' : 'Language',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.onSurfaceDim, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          _LanguageOption(
            code: 'en',
            label: 'English',
            subtitle: 'English responses',
            selected: lang == 'en',
          ),
          const SizedBox(height: 8),
          _LanguageOption(
            code: 'sw',
            label: 'Kiswahili',
            subtitle: 'Majibu ya Kiswahili',
            selected: lang == 'sw',
          ),
          const SizedBox(height: 8),
          _LanguageOption(
            code: 'sheng',
            label: 'Sheng',
            subtitle: 'Sheng — Nairobi street mix',
            selected: lang == 'sheng',
            badge: 'Beta',
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // About / offline guarantee
          Text(
            lang == 'sw' ? 'Kuhusu Niko Rada' : 'About Niko Rada',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.onSurfaceDim),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.wifi_off_rounded,
            color: AppTheme.safe,
            title: lang == 'sw' ? 'Hakuna mtandao unaohitajika' : 'No network required',
            body: lang == 'sw'
                ? 'Niko Rada inafanya kazi kikamilifu bila mtandao. Gemma 4 inafanya kazi kwenye simu yako — hakuna data inayotoka nje.'
                : 'Niko Rada works fully offline. Gemma 4 runs on your device — no data leaves your phone.',
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.lock_outline_rounded,
            color: AppTheme.primary,
            title: lang == 'sw' ? 'Faragha kwa muundo' : 'Privacy by design',
            body: lang == 'sw'
                ? 'Hakuna akaunti, hakuna telemetry, hakuna seva. Ripoti zinabaki kwenye simu yako hadi utakapozituma.'
                : 'No accounts, no telemetry, no server. Reports stay on your device until you choose to send them.',
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.gavel_rounded,
            color: AppTheme.info,
            title: lang == 'sw' ? 'Mwongozo, si dhamana' : 'Guidance, not a guarantee',
            body: lang == 'sw'
                ? 'Majibu ya Niko Rada yanasaidiwa na vyanzo vilivyothibitishwa (EFF, ICRC, KHRC). Hata hivyo, si ushauri wa kisheria au kimatibabu.'
                : 'Niko Rada\'s answers are grounded in verified sources (EFF, ICRC, KHRC). They are guidance — not legal or medical advice.',
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.language_rounded,
            color: AppTheme.onSurfaceDim,
            title: lang == 'sw' ? 'Kuhusu Sheng' : 'About Sheng',
            body: lang == 'sw'
                ? 'Msaada wa Sheng unafanywa kwa kiwango cha mfano — si fasaha ya asili. Tumia Kiswahili kwa majibu ya kina zaidi.'
                : 'Sheng support is prompt-level — not native fluency. Use Kiswahili for more precise answers.',
          ),

          const SizedBox(height: 32),
          Text(
            'Niko Rada v1.0.0 · Build with Gemma: GDG on Campus UoN',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.onSurfaceDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String code;
  final String label;
  final String subtitle;
  final bool selected;
  final String? badge;

  const _LanguageOption({
    required this.code,
    required this.label,
    required this.subtitle,
    required this.selected,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<AppState>().setLanguage(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? AppTheme.primary : AppTheme.onBackground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.onSurfaceDim)),
                ),
              ],
            ]),
            Text(subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.onSurfaceDim)),
          ]),
          const Spacer(),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.primary, size: 22),
        ]),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _InfoCard({required this.icon, required this.color,
    required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurfaceDim, height: 1.5)),
        ])),
      ]),
    );
  }
}
