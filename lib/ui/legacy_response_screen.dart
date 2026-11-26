import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/gemma_service.dart';
import '../theme/app_theme.dart';

/// Legacy flutter_gemma streaming answer screen. Used only when built with --dart-define=HYBRID_AI=false.
class LegacyResponseScreen extends StatefulWidget {
  final String query;
  final String title;
  final String lang;

  const LegacyResponseScreen({
    super.key,
    required this.query,
    required this.title,
    required this.lang,
  });

  @override
  State<LegacyResponseScreen> createState() => _LegacyResponseScreenState();
}

class _LegacyResponseScreenState extends State<LegacyResponseScreen> {
  final _gemma = GemmaService();
  final _buffer = StringBuffer();
  String _text = '';
  bool _done = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      await for (final chunk in _gemma.answer(widget.query, lang: widget.lang)) {
        if (!mounted) return;
        _buffer.write(chunk);
        setState(() => _text = _buffer.toString());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _text = 'Error generating response: $e';
      });
    } finally {
      if (mounted) setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_done && !_error)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Retry',
              onPressed: () {
                _buffer.clear();
                setState(() { _text = ''; _done = false; _error = false; });
                _generate();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Offline badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            color: AppTheme.safe.withValues(alpha: 0.12),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded, size: 14, color: AppTheme.safe),
              const SizedBox(width: 6),
              Text(
                widget.lang == 'sw'
                    ? 'Jibu linafanywa kwenye simu — bila mtandao'
                    : 'Generated on-device — no network used',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.safe),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_done && _text.isEmpty)
                    _buildThinking()
                  else
                    MarkdownBody(
                      data: _text,
                      styleSheet: MarkdownStyleSheet(
                        p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                        h1: Theme.of(context).textTheme.titleLarge,
                        h2: Theme.of(context).textTheme.titleMedium,
                        code: const TextStyle(
                          fontFamily: 'monospace',
                          color: AppTheme.primary,
                          backgroundColor: AppTheme.surfaceVariant,
                        ),
                        em: const TextStyle(
                          color: AppTheme.onSurfaceDim,
                          fontStyle: FontStyle.italic,
                        ),
                        listBullet: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  if (!_done)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.lang == 'sw' ? 'Inafikiri...' : 'Thinking...',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onSurfaceDim),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(4, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 16,
          width: double.infinity * (i == 3 ? 0.6 : 1.0),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      )),
    );
  }
}
