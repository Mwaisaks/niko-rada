import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'consent_sheet.dart';
import 'route_status.dart';

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

          // AI routes and cloud consent
          Text(
            lang == 'sw' ? 'AI na faragha' : 'AI and privacy',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.onSurfaceDim, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          const _CloudConsentTile(),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // About
          Text(
            lang == 'sw' ? 'Kuhusu Niko Rada' : 'About Niko Rada',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.onSurfaceDim),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.wifi_off_rounded,
            color: AppTheme.safe,
            title: lang == 'sw' ? 'Inafanya kazi bila mtandao' : 'Works without a connection',
            body: lang == 'sw'
                ? 'Kwenye simu zinazoweza kuendesha Gemini Nano, majibu hutengenezwa ndani ya simu, bila mtandao. Kwenye simu nyingine, maktaba iliyothibitishwa bado inafanya kazi bila mtandao; majibu ya AI yanahitaji mtandao na idhini yako.'
                : 'On phones that can run Gemini Nano, answers are generated on the phone, offline. On other phones the verified library still works offline; AI answers then need a connection and your permission.',
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.lock_outline_rounded,
            color: AppTheme.primary,
            title: lang == 'sw' ? 'Faragha kwa muundo' : 'Privacy by design',
            body: lang == 'sw'
                ? 'Hakuna akaunti. Maandishi yako hutumwa kwa AI ya mtandaoni tu ukiruhusu. Ripoti zinabaki kwenye simu yako.'
                : 'No accounts. Your text goes to the cloud AI only if you allow it. Reports stay on your phone.',
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
            'Niko Rada · Firebase AI Logic hybrid inference',
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

class _CloudConsentTile extends StatelessWidget {
  const _CloudConsentTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    final sw = lang == 'sw' || lang == 'sheng';
    final granted = state.consent.granted;
    final status = RouteStatusText.of(state.availability, lang);
    final t = Theme.of(context).textTheme;
    final onDevice = state.availability?.onDeviceStatus ?? '…';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(
          key: const Key('consent-switch'),
          contentPadding: EdgeInsets.zero,
          value: granted,
          title: Text(sw ? 'Ruhusu AI ya mtandaoni' : 'Allow cloud AI', style: t.titleMedium),
          subtitle: Text(
            sw
                ? 'Imezimwa kwa chaguo-msingi. Ikiwashwa, maelezo yako na kadi 2 za maktaba hutumwa kwa Gemini ya Google kupitia Firebase.'
                : 'Off by default. When on, your text and 2 library cards are sent to Google\'s Gemini through Firebase.',
            style: t.bodySmall?.copyWith(color: AppTheme.onSurfaceDim, height: 1.4),
          ),
          onChanged: (v) async {
            if (v) {
              await showCloudConsentSheet(context, state.consent, lang);
            } else {
              await state.consent.revoke();
            }
          },
        ),
        const SizedBox(height: 4),
        Row(children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 6),
          Expanded(child: Text(status.label, style: t.labelSmall?.copyWith(color: status.color))),
        ]),
        const SizedBox(height: 4),
        Text(sw ? 'Hali ya AI ndani ya simu: $onDevice' : 'On-device model status: $onDevice',
            style: t.labelSmall?.copyWith(color: AppTheme.onSurfaceDim)),
      ]),
    );
  }
}
