import 'package:flutter/material.dart';
import 'hybrid_inference_channel.dart';

/// Phase 0 spike screen: send one prompt through Firebase AI Logic hybrid inference and show which route served it.
/// Synthetic prompts only. Not part of the shipped flow.
class HybridDebugScreen extends StatefulWidget {
  const HybridDebugScreen({super.key, this.channel});
  final HybridInferenceChannel? channel;

  @override
  State<HybridDebugScreen> createState() => _HybridDebugScreenState();
}

class _HybridDebugScreenState extends State<HybridDebugScreen> {
  late final HybridInferenceChannel _hybrid = widget.channel ?? HybridInferenceChannel();
  final _prompt = TextEditingController(
    text: 'In three short numbered steps, what should someone do right after tear gas exposure?',
  );
  final _cloudModel = TextEditingController(text: 'gemini-3.5-flash-lite');
  HybridMode _mode = HybridMode.preferOnDevice;

  bool _busy = false;
  String? _statusLine;
  HybridResult? _result;
  String? _error;

  static const _presets = {
    'EN': 'In three short numbered steps, what should someone do right after tear gas exposure?',
    'SW': 'Kwa hatua tatu fupi zilizo na nambari, mtu afanye nini mara baada ya kuathiriwa na gesi ya kutoa machozi?',
    'Sheng': 'Kwa steps tatu fupi, mtu afanye nini venye ameguzwa na teargas?',
  };

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on HybridInferenceException catch (e) {
      setState(() => _error = '${e.code}\n${e.message}${e.diagnostics == null ? '' : '\n${e.diagnostics}'}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkStatus() => _run(() async {
        final s = await _hybrid.status(cloudModel: _cloudModel.text);
        setState(() => _statusLine =
            'Firebase: ${s.firebaseConfigured ? 'configured' : 'missing'} · on-device model: ${s.onDeviceStatus} · '
            '${s.online ? 'online' : 'offline'}');
      });

  Future<void> _download() => _run(() async {
        final r = await _hybrid.downloadOnDeviceModel(cloudModel: _cloudModel.text);
        setState(() => _statusLine = 'Download: ${r['downloadResult']} · status now: ${r['onDeviceStatus']}'
            '${r['error'] == null ? '' : ' · ${r['error']}'}');
      });

  Future<void> _generate() => _run(() async {
        setState(() => _result = null);
        final r = await _hybrid.generate(_prompt.text, mode: _mode, cloudModel: _cloudModel.text, maxOutputTokens: 256);
        setState(() => _result = r);
      });

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Hybrid inference spike')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, children: [
            for (final e in _presets.entries)
              ActionChip(label: Text(e.key), onPressed: () => setState(() => _prompt.text = e.value)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _prompt,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Prompt (synthetic only)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<HybridMode>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Inference mode', border: OutlineInputBorder()),
            items: [
              for (final m in HybridMode.values) DropdownMenuItem(value: m, child: Text(m.wire)),
            ],
            onChanged: (m) => setState(() => _mode = m ?? _mode),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cloudModel,
            decoration: const InputDecoration(labelText: 'Cloud model', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: _busy ? null : _checkStatus, child: const Text('Check status')),
            OutlinedButton(onPressed: _busy ? null : _download, child: const Text('Download on-device model')),
            FilledButton(onPressed: _busy ? null : _generate, child: const Text('Generate')),
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
                '${r.online ? 'online' : 'offline'} · ${r.latencyMs} ms · cloud model ${r.cloudModel}'),
            if (r.fallbackReason != null) Text('Why: ${r.fallbackReason}'),
            const Divider(height: 24),
            SelectableText(r.text),
          ],
        ],
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
