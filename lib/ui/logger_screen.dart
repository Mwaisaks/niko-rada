import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../agent/branch.dart';
import '../inference/inference_service.dart';
import '../providers/app_state.dart';
import '../services/store.dart';
import '../models/incident_report.dart';
import '../theme/app_theme.dart';
import 'route_status.dart';

/// F3 — Incident logger.
/// Account → out-of-corpus gate → Triage → (active incident) Branch report on [InferenceService] → saved on the phone.
/// Nothing is sent anywhere; reports stay on the phone.
class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key});

  @override
  State<LoggerScreen> createState() => _LoggerScreenState();
}

class _LoggerScreenState extends State<LoggerScreen> {
  final _store = StoreService();
  final _controller = TextEditingController();
  final _recorder = AudioRecorder();

  List<IncidentReport> _reports = [];
  bool _isExtracting = false;
  bool _isRecording = false;
  String? _error;
  IncidentReport? _lastReport;
  InferenceRoute? _lastRoute;
  String? _lastFallback;

  /// The account waiting for the person's choice after an automatic report was not drafted.
  String? _pending;
  bool _offerAnyway = false; // Triage said "not active": offer to draft a report anyway
  bool _offerSaveRaw = false; // no AI report possible: offer to save the account as written

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    final reports = await _store.getReports();
    if (mounted) setState(() => _reports = reports);
  }

  bool get _sw {
    final lang = context.read<AppState>().language;
    return lang == 'sw' || lang == 'sheng';
  }

  Future<void> _extract({bool anyway = false}) async {
    final text = (anyway ? _pending : _controller.text.trim()) ?? '';
    if (text.isEmpty) return;
    setState(() {
      _isExtracting = true;
      _error = null;
      _lastReport = null;
      _offerAnyway = false;
      _offerSaveRaw = false;
    });
    final flow = context.read<AppState>().branchFlow;
    BranchOutcome out;
    try {
      out = anyway ? await flow.draft(text) : await flow.run(text);
    } catch (e) {
      debugPrint('Branch flow failed: $e');
      out = BranchReport(null, BranchDraftUnavailable(InferenceException('UNKNOWN', '$e')));
    }
    if (!mounted) return;
    await _handle(text, out);
  }

  Future<void> _handle(String text, BranchOutcome out) async {
    final sw = _sw;
    switch (out) {
      case BranchRefused():
        setState(() {
          _isExtracting = false;
          _error = LogText.outOfCorpus;
        });
      case BranchNotActive(:final triage):
        setState(() {
          _isExtracting = false;
          _pending = text;
          _offerAnyway = true;
          _error = sw
              ? 'Hii inaonekana kama swali la jumla (${triage.type.wire}), si tukio maalum ulilolishuhudia. Ripoti ni za tukio maalum.'
              : 'This reads as a general question (${triage.type.wire}), not a specific incident you witnessed. Reports are for specific incidents.';
        });
      case BranchTriageFailed():
      case BranchReport(draft: BranchDraftUnavailable() || BranchDraftMalformed()):
        setState(() {
          _isExtracting = false;
          _pending = text;
          _offerSaveRaw = true;
          _error = sw
              ? 'AI haikuweza kupanga ripoti sasa hivi. Unaweza kuhifadhi maelezo yako kama yalivyo.'
              : "The AI couldn't structure a report right now. You can save your account as written.";
        });
      case BranchReport(draft: BranchDrafted(:final draft, :final route, :final fallbackReason)):
        final report = IncidentReport.fromJson(draft.toJson(),
            id: const Uuid().v4(), createdAt: DateTime.now(), rawInput: text);
        await _store.saveReport(report);
        if (!mounted) return;
        _controller.clear();
        setState(() {
          _isExtracting = false;
          _pending = null;
          _lastReport = report;
          _lastRoute = route;
          _lastFallback = fallbackReason;
        });
        await _loadReports();
    }
  }

  /// No model: keep the person's own words, with every structured field "unknown".
  Future<void> _saveRaw() async {
    final text = _pending;
    if (text == null) return;
    final report = IncidentReport.fromJson(const {},
        id: const Uuid().v4(), createdAt: DateTime.now(), rawInput: text);
    await _store.saveReport(report);
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _pending = null;
      _offerSaveRaw = false;
      _error = null;
      _lastReport = report;
      _lastRoute = null;
      _lastFallback = null;
    });
    await _loadReports();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null && mounted) {
        // Voice notes are kept on the phone only; there is no transcription in this build.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice note saved on this phone. Type the account to create a report.')),
        );
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission needed')),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/incident_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _clearAll() async {
    final lang = context.read<AppState>().language;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: Text(lang == 'sw' ? 'Futa ripoti zote?' : 'Clear all reports?'),
        content: Text(lang == 'sw'
            ? 'Hii haiwezi kutenduliwa.'
            : 'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang == 'sw' ? 'Ghairi' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: Text(lang == 'sw' ? 'Futa' : 'Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.clearReports();
      await _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(lang == 'sw' ? 'Logi ya Tukio' : lang == 'sheng' ? 'Incident Log' : 'Incident Log'),
        actions: [
          if (_reports.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: lang == 'sw' ? 'Futa zote' : 'Clear all',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Input section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == 'sw'
                      ? 'Eleza kilichotokea:'
                      : lang == 'sheng'
                          ? 'Describe ilichotokea:'
                          : 'Describe what happened:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: lang == 'sw'
                        ? 'Nani aliyechukuliwa, wapi, lini, gari gani...'
                        : 'Who was taken, where, when, what vehicle...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExtracting ? null : () => _extract(),
                      icon: _isExtracting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.document_scanner_rounded),
                      label: Text(
                        _isExtracting
                            ? (lang == 'sw' ? 'Inachakata...' : 'Processing...')
                            : (lang == 'sw' ? 'Rekodi Tukio' : 'Log Incident'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? AppTheme.danger
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isRecording
                              ? AppTheme.danger
                              : AppTheme.divider,
                        ),
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: _isRecording
                            ? Colors.white
                            : AppTheme.onSurfaceDim,
                      ),
                    ),
                  ),
                ]),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                        key: const Key('log-notice'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _offerAnyway ? AppTheme.onSurface : AppTheme.danger)),
                  ),
                if (_offerAnyway || _offerSaveRaw)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      key: Key(_offerAnyway ? 'log-anyway' : 'log-save-raw'),
                      onPressed: _isExtracting ? null : (_offerAnyway ? () => _extract(anyway: true) : _saveRaw),
                      icon: Icon(_offerAnyway ? Icons.assignment_add : Icons.save_outlined, size: 18),
                      label: Text(_offerAnyway
                          ? (lang == 'sw' ? 'Unda ripoti hata hivyo' : 'Create a report anyway')
                          : (lang == 'sw' ? 'Hifadhi kama ilivyoandikwa' : 'Save as written')),
                    ),
                  ),
              ],
            ),
          ),

          // Last extracted report preview
          if (_lastReport != null)
            _ReportPreview(report: _lastReport!, lang: lang, route: _lastRoute, fallbackReason: _lastFallback),

          // Saved reports list
          Expanded(
            child: _reports.isEmpty
                ? _buildEmpty(lang)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    itemBuilder: (_, i) =>
                        _ReportCard(report: _reports[i], lang: lang,
                          onDelete: () async {
                            await _store.deleteReport(_reports[i].id);
                            await _loadReports();
                          },
                        ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String lang) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.assignment_outlined,
          size: 48, color: AppTheme.onSurfaceDim),
      const SizedBox(height: 12),
      Text(
        lang == 'sw' ? 'Hakuna ripoti zilizohifadhiwa.' : 'No reports saved yet.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.onSurfaceDim),
      ),
    ]),
  );
}

class _ReportPreview extends StatelessWidget {
  final IncidentReport report;
  final String lang;
  final InferenceRoute? route;
  final String? fallbackReason;
  const _ReportPreview({required this.report, required this.lang, this.route, this.fallbackReason});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.safe.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.safe.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.safe, size: 18),
            const SizedBox(width: 6),
            Text(
              lang == 'sw' ? 'Ripoti imehifadhiwa' : 'Report saved',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.safe),
            ),
          ]),
          if (route != null) ...[
            const SizedBox(height: 8),
            RouteBadge(route: route!, fallbackReason: fallbackReason, lang: lang),
          ],
          const SizedBox(height: 10),
          _row(context, '👤', lang == 'sw' ? 'Nani' : 'Who', report.who),
          _row(context, '📍', lang == 'sw' ? 'Wapi' : 'Where', report.where),
          _row(context, '🕐', lang == 'sw' ? 'Lini' : 'When', report.when),
          _row(context, '📋', lang == 'sw' ? 'Nini' : 'What', report.what),
          const SizedBox(height: 8),
          Text(
            lang == 'sw'
                ? 'Imehifadhiwa kwenye simu hii tu. Haitumwi popote.'
                : 'Saved on this phone only. Nothing is sent anywhere.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.onSurfaceDim, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext ctx, String icon, String label, String value) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text('$label: ', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600, color: AppTheme.onBackground)),
        Expanded(child: Text(value,
            style: Theme.of(ctx).textTheme.bodyMedium)),
      ]),
    );
}

class _ReportCard extends StatelessWidget {
  final IncidentReport report;
  final String lang;
  final VoidCallback onDelete;
  const _ReportCard({required this.report, required this.lang, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.assignment_outlined,
                  size: 16, color: AppTheme.onSurfaceDim),
              const SizedBox(width: 6),
              Expanded(child: Text(
                report.createdAt.toLocal().toString().substring(0, 16),
                style: Theme.of(context).textTheme.labelSmall,
              )),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppTheme.danger.withValues(alpha: 0.7),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            const SizedBox(height: 8),
            Text(report.summary,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                lang == 'sw'
                    ? 'Kwenye simu hii'
                    : 'On this phone',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed Log-tab text.
abstract final class LogText {
  static const outOfCorpus =
      "This doesn't match anything in Niko Rada's verified library, so it was not processed. "
      'If someone is in danger, contact a lawyer, medic or trusted organisation now.\n\n'
      'Hii hailingani na chochote katika maktaba ya Niko Rada, kwa hivyo haikushughulikiwa. '
      'Ikiwa mtu yuko hatarini, wasiliana na wakili, mhudumu wa afya au shirika unaloliamini sasa.';
}
