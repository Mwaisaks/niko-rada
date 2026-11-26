import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'response_screen.dart';
import 'route_status.dart';

/// F1 — Free-text grounded chat screen.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final lang = context.read<AppState>().language;
    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
    });

    // Navigate to response screen for streaming
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => answerScreen(
        query: text,
        title: lang == 'sw' ? 'Jibu' : 'Response',
        lang: lang,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(lang == 'sw' ? 'Uliza' : lang == 'sheng' ? 'Uliza' : 'Ask'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear',
            onPressed: () => setState(() => _messages.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          const RouteStatusStrip(),
          // Suggested queries
          if (_messages.isEmpty)
            Expanded(child: _buildSuggestions(lang))
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  return Align(
                    alignment: m.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: m.isUser
                            ? AppTheme.primary.withValues(alpha: 0.18)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: m.isUser
                              ? AppTheme.primary.withValues(alpha: 0.3)
                              : AppTheme.divider,
                        ),
                      ),
                      child: Text(m.text,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  );
                },
              ),
            ),
          _buildInputBar(lang),
        ],
      ),
    );
  }

  Widget _buildSuggestions(String lang) {
    final suggestions = lang == 'sw'
        ? [
            'Ninafanya nini na machozi ya kutoa?',
            'Ninawezaje kuwasiliana bila mtandao?',
            'Haki zangu nikizuiwa ni zipi?',
            'Niandae simu yangu vipi?',
          ]
        : lang == 'sheng'
            ? [
                'Tear gas inakuanga, nifanye aje?',
                'Net imekufa, niwasiliane aje?',
                'Rights zangu nikichukuliwa?',
                'Niset up simu yangu aje?',
              ]
            : [
                'What do I do about tear gas?',
                'How can I reach people with no network?',
                'What are my rights if arrested?',
                'How do I prepare my phone?',
              ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        Text(
          lang == 'sw' ? 'Maswali ya kawaida:' : 'Common questions:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.onSurfaceDim),
        ),
        const SizedBox(height: 16),
        ...suggestions.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              _controller.text = s;
              _send();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(children: [
                Expanded(child: Text(s,
                    style: Theme.of(context).textTheme.bodyLarge)),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppTheme.onSurfaceDim),
              ]),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildInputBar(String lang) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _send(),
            textInputAction: TextInputAction.send,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: lang == 'sw'
                  ? 'Andika swali lako...'
                  : lang == 'sheng'
                      ? 'Type hapa...'
                      : 'Type your question...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
          ),
        ),
      ]),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}
