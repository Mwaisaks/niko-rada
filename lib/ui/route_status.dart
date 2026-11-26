import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../inference/inference_service.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'consent_sheet.dart';

bool _sw(String lang) => lang == 'sw' || lang == 'sheng';

/// What the app can use right now, in words. Pure, so it can be tested without widgets.
class RouteStatusText {
  final String label;
  final IconData icon;
  final Color color;

  /// True when tapping should offer cloud consent (online, no on-device model, consent off).
  final bool offersConsent;

  const RouteStatusText(this.label, this.icon, this.color, {this.offersConsent = false});

  static RouteStatusText of(InferenceAvailability? a, String lang) {
    final sw = _sw(lang);
    if (a == null) {
      return RouteStatusText(sw ? 'Inakagua AI…' : 'Checking AI…', Icons.hourglass_empty_rounded, AppTheme.onSurfaceDim);
    }
    if (a.error != null) {
      return RouteStatusText(sw ? 'AI haipatikani · maktaba iliyothibitishwa tu' : 'AI not set up · verified library only',
          Icons.menu_book_rounded, AppTheme.onSurfaceDim);
    }
    if (a.onDeviceReady) {
      return RouteStatusText(
          sw ? 'AI ndani ya simu iko tayari · bila mtandao' : 'On-device AI ready · works offline',
          Icons.phone_android_rounded,
          AppTheme.safe);
    }
    if (a.online && a.cloudConsent) {
      return RouteStatusText(sw ? 'AI ya mtandaoni · kwa idhini yako' : 'Cloud AI · with your permission',
          Icons.cloud_done_outlined, AppTheme.info);
    }
    if (a.online) {
      return RouteStatusText(
          sw ? 'AI ya mtandaoni imezimwa · gusa kuruhusu' : 'Cloud AI is off · tap to allow',
          Icons.cloud_off_outlined,
          AppTheme.primary,
          offersConsent: true);
    }
    return RouteStatusText(sw ? 'Hakuna mtandao · maktaba iliyothibitishwa tu' : 'Offline · verified library only',
        Icons.wifi_off_rounded, AppTheme.danger);
  }
}

/// A thin strip showing the current route. Tapping it offers consent when that would unlock an AI route.
class RouteStatusStrip extends StatelessWidget {
  const RouteStatusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = RouteStatusText.of(state.availability, state.language);
    return Material(
      color: s.color.withValues(alpha: 0.12),
      child: InkWell(
        onTap: () async {
          if (s.offersConsent) {
            await showCloudConsentSheet(context, state.consent, state.language);
          }
          await state.refreshAvailability();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Icon(s.icon, size: 14, color: s.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.label,
                  key: const Key('route-status'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: s.color, fontWeight: FontWeight.w600)),
            ),
            Icon(s.offersConsent ? Icons.chevron_right_rounded : Icons.refresh_rounded, size: 16, color: s.color),
          ]),
        ),
      ),
    );
  }
}

/// Which route produced one answer, and why it fell back, if it did.
class RouteBadge extends StatelessWidget {
  const RouteBadge({super.key, required this.route, this.fallbackReason, required this.lang});
  final InferenceRoute route;
  final String? fallbackReason;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final sw = _sw(lang);
    final onDevice = route == InferenceRoute.onDevice;
    final color = onDevice ? AppTheme.safe : AppTheme.info;
    final label = onDevice
        ? (sw ? 'Imejibiwa ndani ya simu' : 'Answered on this phone')
        : (sw ? 'Imejibiwa na AI ya mtandaoni' : 'Answered by cloud AI');
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(onDevice ? Icons.phone_android_rounded : Icons.cloud_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, key: const Key('route-badge'), style: t.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ]),
        if (fallbackReason != null) ...[
          const SizedBox(height: 4),
          Text(fallbackReason!, style: t.bodySmall?.copyWith(color: AppTheme.onSurfaceDim)),
        ],
      ]),
    );
  }
}
