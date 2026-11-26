import 'package:flutter/material.dart';
import '../inference/cloud_consent.dart';
import '../theme/app_theme.dart';

/// Asks for explicit consent before crisis text may be sent to the cloud model. Returns true if granted.
/// Default is no: closing the sheet or tapping "Not now" leaves consent off. Revocable in Settings.
Future<bool> showCloudConsentSheet(BuildContext context, CloudConsentStore consent, String lang) async {
  final granted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _ConsentBody(lang: lang),
  );
  if (granted == true) {
    await consent.grant();
    return true;
  }
  return false;
}

class _ConsentBody extends StatelessWidget {
  const _ConsentBody({required this.lang});
  final String lang;

  bool get _sw => lang == 'sw' || lang == 'sheng';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final points = _sw
        ? const [
            'Kwa chaguo-msingi, Niko Rada hutumia AI iliyo ndani ya simu tu, au maktaba iliyothibitishwa.',
            'Ukiruhusu, maelezo uliyoandika na kadi 2 za maktaba zinazohusiana hutumwa kwa Gemini ya Google (kupitia Firebase) ili kupata jibu.',
            'Usiandike majina, mahali au nambari za simu isipokuwa unataka zitumwe.',
            'Majibu ya Kiswahili na Sheng yanahitaji AI ya mtandaoni.',
            'Unaweza kuzima hili wakati wowote kwenye Mipangilio.',
          ]
        : const [
            'By default, Niko Rada uses only the AI on your phone, or the verified library.',
            'If you allow it, the text you type and the 2 matching library cards are sent to Google\'s Gemini '
                '(through Firebase) to produce an answer.',
            'Leave out names, places and phone numbers unless you want them sent.',
            'Generated answers in Kiswahili and Sheng need the cloud AI.',
            'You can turn this off at any time in Settings.',
          ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.cloud_outlined, color: AppTheme.info),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_sw ? 'Ruhusu AI ya mtandaoni?' : 'Allow cloud AI?',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 16),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7, right: 10),
                  child: Icon(Icons.circle, size: 6, color: AppTheme.onSurfaceDim),
                ),
                Expanded(child: Text(p, style: t.bodyMedium?.copyWith(height: 1.45))),
              ]),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('consent-decline'),
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(_sw ? 'Sio sasa' : 'Not now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('consent-allow'),
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(_sw ? 'Ruhusu' : 'Allow'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
