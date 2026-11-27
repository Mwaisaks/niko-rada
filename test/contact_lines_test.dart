import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/models/contact_lines.dart';
import 'package:niko_rada/services/rag.dart';

/// Tap-to-call display of the verified contacts cards: no number lost, none invented.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rag = RagService();
  setUpAll(() async => rag.loadCards());

  test('contacts-001 (English): call lines, labels and details', () {
    final c = ContactLines.parse(rag.cardById('contacts-001')!.contentEn);
    expect(c.calls.first.label, 'Emergency (police, fire, ambulance)');
    expect(c.calls.first.numbers, ['999', '112']);
    expect(c.calls[1].label, 'Kenya Red Cross Ambulance');
    expect(c.calls[1].numbers, ['1199']);
    expect(c.calls[1].detail, 'toll-free, 24/7 nationwide');
    final main = c.calls.firstWhere((l) => l.label == 'Main');
    expect(main.continued, isTrue);
    expect(c.calls.first.continued, isFalse);
    expect(c.texts.map((t) => t.label), containsAll(['Important', 'Note']));
  });

  test('contacts-001 (Kiswahili): the same numbers', () {
    final en = ContactLines.parse(rag.cardById('contacts-001')!.contentEn);
    final sw = ContactLines.parse(rag.cardById('contacts-001')!.contentSw);
    expect(sw.calls.first.label, 'Dharura (polisi, moto, ambulance)');
    expect([for (final l in sw.calls) ...l.numbers], [for (final l in en.calls) ...l.numbers]);
  });

  for (final id in ['contacts-001', 'contacts-lsk-001', 'contacts-imlu-001', 'contacts-missingvoices-001']) {
    for (final lang in ['en', 'sw']) {
      test('$id ($lang): every number in a call line is verbatim card text, and none is lost', () {
        final card = rag.cardById(id)!;
        final text = card.content(lang);
        final c = ContactLines.parse(text);
        final shown = [for (final l in c.calls) ...l.numbers];
        for (final n in shown) {
          expect(text, contains(n));
        }
        // Every phone-like number outside parentheses on a "LABEL: number" line ends up callable.
        final expected = RegExp(r'^[^:\n]+:\s*(\+?\d[\d ]*\d)', multiLine: true)
            .allMatches(text.replaceAll(' | ', '\n'))
            .map((m) => m.group(1)!.trim())
            .where((n) => n.replaceAll(' ', '').length >= 3);
        expect(shown, containsAll(expected));
      });
    }
  }

  test('LSK and IMLU: one call line each; websites and descriptions stay text', () {
    final lsk = ContactLines.parse(rag.cardById('contacts-lsk-001')!.contentEn);
    expect(lsk.calls.single.numbers, ['+254 799 595 800']);
    expect(lsk.texts.any((t) => t.label == 'Website' && t.text == 'lsk.or.ke'), isTrue);
    final imlu = ContactLines.parse(rag.cardById('contacts-imlu-001')!.contentEn);
    expect(imlu.calls.single.label, 'Toll-Free');
    expect(imlu.texts.first.text, startsWith('IMLU (Independent'));
  });

  test('a number mentioned inside a sentence is not turned into a call button', () {
    final mv = ContactLines.parse(rag.cardById('contacts-missingvoices-001')!.contentEn);
    expect(mv.calls, isEmpty);
  });

  test('dial string only removes spaces', () {
    expect(ContactLines.dialString('+254 20 284 5000'), '+254202845000');
  });
}
