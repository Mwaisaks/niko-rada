import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hybrid_inference_channel.dart';
import 'spike_report.dart';

/// Phase 0 spike screen: send one prompt through Firebase AI Logic hybrid inference and show which route served it.
/// Built so a remote tester with no dev tools can run the checklist and send back a plain-text report.
/// Synthetic prompts only. Not part of the shipped flow.
class HybridDebugScreen extends StatefulWidget {
  const HybridDebugScreen({super.key, this.channel});
  final HybridInferenceChannel? channel;

  @override
  State<HybridDebugScreen> createState() => _HybridDebugScreenState();
}

class _HybridDebugScreenState extends State<HybridDebugScreen> {
  late final HybridInferenceChannel _hybrid = widget.channel ?? HybridInferenceChannel();

  static const presets = {
    'EN': 'In three short numbered steps, what should someone do right after tear gas exposure?',
    'SW': 'Kwa hatua tatu fupi zilizo na nambari, mtu afanye nini mara baada ya kuathiriwa na gesi ya kutoa machozi?',
    'Sheng': 'Kwa steps tatu fupi, mtu afanye nini venye ameguzwa na teargas?',
  };

  final _prompt = TextEditingController(text: presets['EN']);
  final _cloudModel = TextEditingController(text: 'gemini-3.5-flash-lite');
  HybridMode _mode = HybridMode.preferOnDevice;

  bool _busy = false;
  String? _statusLine;
  HybridResult? _result;
  String? _error;
  SpikeDeviceInfo? _device;
  final List<SpikeStep> _steps = [];

  /// The preset key if the prompt box still holds that preset's exact text; null for anything typed.
  String? get _presetLabel {
    for (final e in presets.entries) {
      if (e.value == _prompt.text) return e.key;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  @override
  void dispose() {
    _prompt.dispose();
    _cloudModel.dispose();
    super.dispose();
  }

  Future<void> _loadDevice() async {
    try {
      final m = await _hybrid.deviceInfo();
      if (mounted) setState(() => _device = SpikeDeviceInfo.fromMap(m));
    } catch (_) {
      // Non-Android or plugin missing: the report says "device info unavailable".
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on HybridInferenceException catch (e) {
      setState(() => _error = '${e.code}\n${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkStatus() => _run(() async {
        try {
          final s = await _hybrid.status(cloudModel: _cloudModel.text);
          _steps.add(SpikeStep(
              at: DateTime.now(), kind: SpikeStepKind.status, online: s.online, onDeviceStatus: s.onDeviceStatus));
          setState(() => _statusLine = 'On-device model: ${s.onDeviceStatus} · ${s.online ? 'online' : 'offline'}');
        } on HybridInferenceException catch (e) {
          _steps.add(SpikeStep(
              at: DateTime.now(), kind: SpikeStepKind.status, errorCode: e.code, errorMessage: e.message));
          rethrow;
        }
      });

  Future<void> _download() => _run(() async {
        try {
          final r = await _hybrid.downloadOnDeviceModel(cloudModel: _cloudModel.text);
          _steps.add(SpikeStep(
            at: DateTime.now(),
            kind: SpikeStepKind.download,
            onDeviceStatus: r['onDeviceStatus'] as String?,
            note: '${r['downloadResult']}',
            errorMessage: r['error'] as String?,
            errorCode: r['error'] == null ? null : 'DownloadFailed',
          ));
          setState(() => _statusLine = 'Download: ${r['downloadResult']} · status now: ${r['onDeviceStatus']}'
              '${r['error'] == null ? '' : ' · ${r['error']}'}');
        } on HybridInferenceException catch (e) {
          _steps.add(SpikeStep(
              at: DateTime.now(), kind: SpikeStepKind.download, errorCode: e.code, errorMessage: e.message));
          rethrow;
        }
      });

  Future<void> _generate() => _run(() async {
        setState(() => _result = null);
        final label = _presetLabel;
        try {
          final r = await _hybrid.generate(_prompt.text,
              mode: _mode, cloudModel: _cloudModel.text, maxOutputTokens: 256);
          _steps.add(SpikeStep(
            at: DateTime.now(),
            kind: SpikeStepKind.generate,
            mode: r.mode,
            promptLabel: label,
            online: r.online,
            onDeviceStatus: r.onDeviceStatusBefore,
            route: switch (r.route) {
              InferenceRoute.onDevice => 'ON_DEVICE',
              InferenceRoute.inCloud => 'IN_CLOUD',
              InferenceRoute.unknown => 'UNKNOWN',
            },
            fallbackReason: r.fallbackReason,
            latencyMs: r.latencyMs,
            output: label == null ? null : r.text,
          ));
          setState(() => _result = r);
        } on HybridInferenceException catch (e) {
          final d = e.diagnostics;
          _steps.add(SpikeStep(
            at: DateTime.now(),
            kind: SpikeStepKind.generate,
            mode: (d?['mode'] as String?) ?? _mode.wire,
            promptLabel: label,
            online: d?['online'] as bool?,
            onDeviceStatus: d?['onDeviceStatusBefore'] as String?,
            latencyMs: (d?['latencyMs'] as num?)?.toInt(),
            errorCode: e.code,
            errorMessage: e.message,
          ));
          rethrow;
        }
      });

  Future<void> _copyResults() async {
    final text = SpikeReport.build(device: _device, steps: _steps);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report copied (${_steps.length} steps). Paste it into WhatsApp or email.')),
    );
  }

  bool get _didStatus => _steps.any((s) => s.kind == SpikeStepKind.status);
  bool get _didOnline => _steps.any((s) => s.kind == SpikeStepKind.generate && s.online == true);
  bool get _didOffline => _steps.any((s) => s.kind == SpikeStepKind.generate && s.online == false);

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hybrid inference test'),
        actions: [
          IconButton(
            tooltip: 'Copy results',
            onPressed: _steps.isEmpty ? null : _copyResults,
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Checklist(didStatus: _didStatus, didOnline: _didOnline, didOffline: _didOffline),
          const SizedBox(height: 12),
          if (_device != null)
            Text('${_device!.manufacturer} ${_device!.model} · Android ${_device!.androidVersion} · '
                '${_device!.totalRamGb} GB RAM'
                '${_device!.firebaseConfigured ? '' : ' · Firebase NOT configured in this build'}'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final e in presets.entries)
              ChoiceChip(
                label: Text(e.key),
                selected: _presetLabel == e.key,
                onSelected: (_) => setState(() => _prompt.text = e.value),
              ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _prompt,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Prompt (use a preset; typed text is not included in the report)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<HybridMode>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Inference mode', border: OutlineInputBorder()),
            items: [for (final m in HybridMode.values) DropdownMenuItem(value: m, child: Text(m.wire))],
            onChanged: (m) => setState(() => _mode = m ?? _mode),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Advanced'),
            children: [
              TextField(
                controller: _cloudModel,
                decoration: const InputDecoration(labelText: 'Cloud model', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
            ],
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: _busy ? null : _checkStatus, child: const Text('1 · Check status')),
            OutlinedButton(onPressed: _busy ? null : _download, child: const Text('Download on-device model')),
            FilledButton(onPressed: _busy ? null : _generate, child: const Text('Send prompt')),
          ]),
          if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (_statusLine != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_statusLine!)),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              margin: const EdgeInsets.only(top: 12),
              child: Padding(padding: const EdgeInsets.all(12), child: SelectableText('Error: $_error')),
            ),
          if (r != null) ...[
            const SizedBox(height: 12),
            _RouteBadge(route: r.route),
            const SizedBox(height: 8),
            Text('mode ${r.mode} · on-device status before: ${r.onDeviceStatusBefore} · '
                '${r.online ? 'online' : 'offline'} · ${r.latencyMs} ms'),
            if (r.fallbackReason != null) Text('Why: ${r.fallbackReason}'),
            const Divider(height: 24),
            SelectableText(r.text),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _steps.isEmpty ? null : _copyResults,
            icon: const Icon(Icons.copy_all_outlined),
            label: Text('Copy results (${_steps.length} steps)'),
          ),
        ],
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.didStatus, required this.didOnline, required this.didOffline});
  final bool didStatus;
  final bool didOnline;
  final bool didOffline;

  @override
  Widget build(BuildContext context) {
    Widget step(bool done, String title, String detail) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? Colors.green : null),
          title: Text(title),
          subtitle: Text(detail),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Test steps', style: Theme.of(context).textTheme.titleMedium),
          step(didStatus, '1. Check status',
              'Wi-Fi or data ON. Tap "Check status". If it says DOWNLOADABLE, tap "Download on-device model", '
                  'wait, then check again.'),
          step(didOnline, '2. Send a prompt online',
              'Keep preset EN and mode PREFER_ON_DEVICE. Tap "Send prompt". Optional: repeat with SW and Sheng.'),
          step(didOffline, '3. Send a prompt in airplane mode',
              'Turn airplane mode ON, keep this app open, tap "Send prompt" again (EN, then SW and Sheng). '
                  'An error here is a valid result.'),
          step(false, '4. Copy results', 'Tap "Copy results" and paste the text into WhatsApp or email.'),
        ]),
      ),
    );
  }
}

class _RouteBadge extends StatelessWidget {
  const _RouteBadge({required this.route});
  final InferenceRoute route;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (route) {
      InferenceRoute.onDevice => ('On your device', Icons.phone_android, Colors.green),
      InferenceRoute.inCloud => ('In the cloud', Icons.cloud_outlined, Colors.blue),
      InferenceRoute.unknown => ('Route unknown', Icons.help_outline, Colors.grey),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(avatar: Icon(icon, color: color), label: Text(label)),
    );
  }
}
