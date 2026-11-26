/// Plain-text test report for the hybrid spike, built for remote testers with no dev tools.
///
/// Privacy: contains device model, Android version, RAM, statuses, routes, latency and error codes. It never contains
/// device identifiers, account info, the App Check token, or anything the tester typed: model output is included
/// only for the built-in synthetic preset prompts, and custom prompts are recorded as "custom (text omitted)".
class SpikeDeviceInfo {
  final String manufacturer;
  final String model;
  final String androidVersion;
  final int sdkInt;
  final double totalRamGb;
  final bool firebaseConfigured;
  final bool appCheckBuildToken;

  const SpikeDeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.androidVersion,
    required this.sdkInt,
    required this.totalRamGb,
    required this.firebaseConfigured,
    required this.appCheckBuildToken,
  });

  factory SpikeDeviceInfo.fromMap(Map<Object?, Object?> m) => SpikeDeviceInfo(
        manufacturer: (m['manufacturer'] as String?) ?? '?',
        model: (m['model'] as String?) ?? '?',
        androidVersion: (m['androidVersion'] as String?) ?? '?',
        sdkInt: (m['sdkInt'] as num?)?.toInt() ?? 0,
        totalRamGb: (m['totalRamGb'] as num?)?.toDouble() ?? 0,
        firebaseConfigured: (m['firebaseConfigured'] as bool?) ?? false,
        appCheckBuildToken: (m['appCheckBuildToken'] as bool?) ?? false,
      );
}

enum SpikeStepKind { status, download, generate, triage }

class SpikeStep {
  final DateTime at;
  final SpikeStepKind kind;
  final String? mode;
  final String? promptLabel; // preset key (EN / SW / Sheng) or null for custom
  final bool? online;
  final String? onDeviceStatus;
  final String? route; // ON_DEVICE / IN_CLOUD / UNKNOWN
  final String? fallbackReason;
  final int? latencyMs;
  final String? errorCode;
  final String? errorMessage;
  final String? output; // only kept for preset prompts
  final String? note; // e.g. download result
  final String? rawReply; // triage only: the model's exact reply (synthetic situations only)
  final String? parseResult; // triage only: "ACCEPTED type|severity|active" or "REJECTED: reason"

  const SpikeStep({
    required this.at,
    required this.kind,
    this.mode,
    this.promptLabel,
    this.online,
    this.onDeviceStatus,
    this.route,
    this.fallbackReason,
    this.latencyMs,
    this.errorCode,
    this.errorMessage,
    this.output,
    this.note,
    this.rawReply,
    this.parseResult,
  });
}

class SpikeReport {
  static const _maxOutputChars = 400;

  static String build({required SpikeDeviceInfo? device, required List<SpikeStep> steps, DateTime? now}) {
    final b = StringBuffer()
      ..writeln('NIKO RADA — HYBRID SPIKE REPORT')
      ..writeln('Generated: ${_ts(now ?? DateTime.now())}');
    if (device == null) {
      b.writeln('Device: unknown (device info unavailable)');
    } else {
      b
        ..writeln('Device: ${device.manufacturer} ${device.model}')
        ..writeln('Android: ${device.androidVersion} (API ${device.sdkInt}) · RAM ${device.totalRamGb} GB')
        ..writeln('Firebase configured: ${_yn(device.firebaseConfigured)} · '
            'App Check token built in: ${_yn(device.appCheckBuildToken)}');
    }
    b.writeln('Steps: ${steps.length}');
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      b
        ..writeln()
        ..writeln('#${i + 1} ${_kind(s.kind)} @ ${_ts(s.at)}');
      if (s.mode != null) b.writeln('  mode: ${s.mode}');
      if (s.kind == SpikeStepKind.generate || s.kind == SpikeStepKind.triage) {
        b.writeln('  prompt: ${s.promptLabel == null ? 'custom (text omitted)' : 'preset ${s.promptLabel}'}');
      }
      if (s.online != null) b.writeln('  network: ${s.online! ? 'online' : 'OFFLINE'}');
      if (s.onDeviceStatus != null) b.writeln('  on-device model status: ${s.onDeviceStatus}');
      if (s.route != null) b.writeln('  answered by: ${_route(s.route!)}');
      if (s.fallbackReason != null) b.writeln('  fallback reason: ${s.fallbackReason}');
      if (s.latencyMs != null) b.writeln('  latency: ${s.latencyMs} ms');
      if (s.note != null) b.writeln('  result: ${s.note}');
      if (s.errorCode != null) b.writeln('  ERROR: ${s.errorCode}${s.errorMessage == null ? '' : ' — ${_oneLine(s.errorMessage!)}'}');
      if (s.rawReply != null) b.writeln('  raw reply: "${_visible(s.rawReply!)}"');
      if (s.parseResult != null) b.writeln('  parser: ${s.parseResult}');
      if (s.output != null && s.promptLabel != null) {
        final out = _oneLine(s.output!);
        b.writeln('  output: ${out.length > _maxOutputChars ? '${out.substring(0, _maxOutputChars)}…' : out}');
      }
    }
    return b.toString();
  }

  static String _kind(SpikeStepKind k) => switch (k) {
        SpikeStepKind.status => 'CHECK STATUS',
        SpikeStepKind.download => 'DOWNLOAD MODEL',
        SpikeStepKind.generate => 'GENERATE',
        SpikeStepKind.triage => 'TRIAGE',
      };

  static String _route(String r) => switch (r) {
        'ON_DEVICE' => 'ON DEVICE (Gemini Nano)',
        'IN_CLOUD' => 'IN THE CLOUD',
        _ => 'unknown',
      };

  static String _yn(bool v) => v ? 'yes' : 'no';

  /// Raw reply kept exact but on one line: newlines and tabs shown as \n and \t so format problems stay visible.
  static String _visible(String s) {
    final v = s.replaceAll('\n', r'\n').replaceAll('\r', r'\r').replaceAll('\t', r'\t');
    return v.length > 300 ? '${v.substring(0, 300)}…' : v;
  }
  static String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
  static String _ts(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
