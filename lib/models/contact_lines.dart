/// Splits a verified contacts card into tappable call lines and plain text lines, for display only.
///
/// Numbers are never invented or reformatted: each [CallLine.numbers] entry is a substring of the card text, and
/// [dialString] only removes spaces. A line is a call line when the text after its first colon starts with a phone
/// number ("EMERGENCY (police, fire, ambulance): 999 or 112"); a line may hold several segments split by " | ".
/// Everything else (descriptions, NOTE/IMPORTANT lines, websites) stays text.
class ContactLines {
  final List<CallLine> calls;
  final List<TextLine> texts;
  const ContactLines(this.calls, this.texts);

  static final _number = RegExp(r'\+?\d[\d ]*\d');
  static final _labelled = RegExp(r'^([^:]{2,80}):\s*(.*)$');
  static const _acronyms = {'LSK', 'IMLU', 'KHRC', 'OB', 'ICRC', 'EFF', 'KNCHR', 'IPOA'};

  static ContactLines parse(String content) {
    final calls = <CallLine>[];
    final texts = <TextLine>[];
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final segments = line.split(' | ');
      final parsed = <CallLine>[];
      for (final seg in segments) {
        final m = _labelled.firstMatch(seg.trim());
        if (m == null) break;
        final rest = m.group(2)!;
        final first = _number.matchAsPrefix(rest);
        if (first == null || _digits(first.group(0)!).length < 3) break;
        final numbers = [
          for (final n in _number.allMatches(rest))
            if (_digits(n.group(0)!).length >= 3 && !_inParens(rest, n.start)) n.group(0)!.trim(),
        ];
        var detail = rest;
        for (final n in numbers) {
          detail = detail.replaceFirst(n, '');
        }
        detail = detail.replaceAll(RegExp(r'^[\s,]*(or|au|/)?[\s,]*$'), '').trim();
        detail = detail.replaceAll(RegExp(r'^(or|au)\s+'), '').trim();
        if (detail.startsWith('(') && detail.endsWith(')')) detail = detail.substring(1, detail.length - 1).trim();
        parsed.add(CallLine(niceLabel(m.group(1)!.trim()), numbers, detail.isEmpty ? null : detail,
            continued: parsed.isNotEmpty));
      }
      if (parsed.length == segments.length) {
        calls.addAll(parsed);
      } else {
        final m = _labelled.firstMatch(line);
        final label = m?.group(1)!.trim();
        // Only short ALL-CAPS prefixes count as labels ("NOTE:", "WEBSITE:"), not sentences with a colon in them.
        if (m != null && label!.length <= 24 && label == label.toUpperCase()) {
          texts.add(TextLine(niceLabel(label), m.group(2)!.trim()));
        } else {
          texts.add(TextLine(null, line));
        }
      }
    }
    return ContactLines(calls, texts);
  }

  static String _digits(String s) => s.replaceAll(RegExp(r'[^\d]'), '');

  static bool _inParens(String s, int index) =>
      s.lastIndexOf('(', index) > s.lastIndexOf(')', index);

  /// "KENYA RED CROSS AMBULANCE" → "Kenya Red Cross Ambulance"; known acronyms and mixed-case words are kept.
  static String niceLabel(String label) => label.splitMapJoin(RegExp(r'[A-Za-z]+'), onMatch: (m) {
        final w = m.group(0)!;
        if (w.length < 2 || w != w.toUpperCase() || _acronyms.contains(w)) return w;
        return w[0] + w.substring(1).toLowerCase();
      });

  /// The string handed to the dialer: the verified number with spaces removed.
  static String dialString(String number) => number.replaceAll(' ', '');
}

class CallLine {
  final String label;
  final List<String> numbers;
  final String? detail;

  /// True for the second and later " | " segments of one card line (e.g. a hospital's "Main" number after its
  /// casualty number); shown as part of the line above.
  final bool continued;
  const CallLine(this.label, this.numbers, this.detail, {this.continued = false});
}

class TextLine {
  final String? label;
  final String text;
  const TextLine(this.label, this.text);
}
