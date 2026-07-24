import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/app_state.dart';
import '../services/extractor.dart';
import '../services/store.dart';
import '../models/incident_report.dart';
import '../theme/app_theme.dart';

/// F3 — Offline incident logger.
/// Text or voice → Gemma extraction → structured report → local pending-send queue.
class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key});

  @override
  State<LoggerScreen> createState() => _LoggerScreenState();
}

class _LoggerScreenState extends State<LoggerScreen> {
  final _extractor = ExtractorService();
  final _store = StoreService();
  final _controller = TextEditingController();
  final _recorder = AudioRecorder();

  List<IncidentReport> _reports = [];
  bool _isExtracting = false;
  bool _isRecording = false;
  String? _error;
  IncidentReport? _lastReport;

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

  Future<void> _extract() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() { _isExtracting = true; _error = null; _lastReport = null; });
    try {
      final report = await _extractor.extract(text);
      if (mounted) {
        setState(() { _lastReport = report; _isExtracting = false; });
        _controller.clear();
        await _loadReports();
      }
    } catch (e) {
      if (mounted) setState(() { _isExtracting = false; _error = e.toString(); });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null && mounted) {
        // For now, show the path — full audio transcription via Gemma 4 audio input
        // is wired in Phase 4 polish. For now use text fallback.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording saved — transcription coming in next build')),
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
                      onPressed: _isExtracting ? null : _extract,
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.danger)),
                  ),
              ],
            ),
          ),

          // Last extracted report preview
          if (_lastReport != null)
            _ReportPreview(report: _lastReport!, lang: lang),

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
  const _ReportPreview({required this.report, required this.lang});

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
          const SizedBox(height: 10),
          _row(context, '👤', lang == 'sw' ? 'Nani' : 'Who', report.who),
          _row(context, '📍', lang == 'sw' ? 'Wapi' : 'Where', report.where),
          _row(context, '🕐', lang == 'sw' ? 'Lini' : 'When', report.when),
          _row(context, '📋', lang == 'sw' ? 'Nini' : 'What', report.what),
          const SizedBox(height: 8),
          Text(
            lang == 'sw'
                ? '⏳ Ipo kwenye foleni ya kutumwa — itapelekwa unapopata mtandao'
                : '⏳ Queued for send — will be transmitted when network returns',
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
                    ? '⏳ Inasubiri kutumwa'
                    : '⏳ Pending send',
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
