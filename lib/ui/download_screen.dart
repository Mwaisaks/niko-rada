import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/gemma_service.dart';
import '../theme/app_theme.dart';

/// F0 — First-run model download screen.
/// Shows progress bar, Wi-Fi reminder, and Limited Mode fallback.
class DownloadScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const DownloadScreen({super.key, required this.onComplete});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen>
    with SingleTickerProviderStateMixin {
  final _gemma = GemmaService();
  double _progress = 0;
  bool _downloading = false;
  bool _error = false;
  String? _errorMessage;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() { _downloading = true; _error = false; _progress = 0; });
    try {
      await _gemma.installModel(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        setState(() { _downloading = false; _error = true; _errorMessage = e.toString(); });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Logo / branding
              FadeTransition(
                opacity: _pulseAnim,
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Center(
                    child: Text('🛡️', style: TextStyle(fontSize: 32)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Niko Rada',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppTheme.primary, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                lang == 'sw'
                    ? 'Msaidizi wa usalama wa nje ya mtandao'
                    : 'Offline safety companion',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.onSurfaceDim),
              ),
              const SizedBox(height: 40),

              // Model download section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.download_rounded, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        lang == 'sw' ? 'Pakua Modeli' : 'Download Model',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      lang == 'sw'
                          ? 'Gemma 4 E2B (~2.4 GB) itapakuliwa mara moja kwa Wi-Fi. Baada ya hapo, kila kitu kinafanya kazi bila mtandao.'
                          : 'Gemma 4 E2B (~2.4 GB) downloads once on Wi-Fi. After that, everything works offline — no network ever needed again.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5, color: AppTheme.onSurfaceDim),
                    ),
                    const SizedBox(height: 16),

                    // Wi-Fi warning
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.wifi_rounded,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lang == 'sw'
                                ? 'Tumia Wi-Fi — faili ni kubwa (2.4 GB)'
                                : 'Use Wi-Fi — file is large (2.4 GB)',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.primary),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    if (_downloading) ...[
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progress > 0 ? _progress : null,
                              minHeight: 8,
                              backgroundColor: AppTheme.divider,
                              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(_progress * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.primary),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        lang == 'sw' ? 'Inapakuliwa...' : 'Downloading...',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.onSurfaceDim),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startDownload,
                          icon: const Icon(Icons.download_rounded),
                          label: Text(lang == 'sw' ? 'Anza Kupakua' : 'Start Download'),
                        ),
                      ),
                    ],

                    if (_error) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage ?? 'Download failed',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.danger)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _startDownload,
                        child: Text(lang == 'sw' ? 'Jaribu tena' : 'Retry'),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // Limited Mode
              TextButton(
                onPressed: widget.onComplete,
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.onSurfaceDim),
                child: Text(
                  lang == 'sw'
                      ? 'Endelea bila modeli (Hali ya kikwazo)'
                      : 'Continue without model (Limited Mode)',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang == 'sw'
                    ? 'Katika hali ya kikwazo, kadi za mwongozo zinapatikana lakini hakuna majibu ya AI.'
                    : 'In Limited Mode, guidance cards are available but no AI responses.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.onSurfaceDim),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
