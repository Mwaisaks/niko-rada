import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/services/extractor.dart';
import 'package:niko_rada/services/rag.dart';
import 'package:niko_rada/services/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synthetic accounts only. No real people, places tied to real cases, or phone numbers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> modelCalls;
  late ExtractorService extractor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    modelCalls = [];
    extractor = ExtractorService.forTesting(
      modelExtract: (text) async {
        modelCalls.add(text);
        return '{"who":"a young man","what":"taken into a car","where":"near a bus stage","when":"unknown",'
            '"details":"white car","witnesses":"the narrator","source_reliability":"firsthand"}';
      },
      rag: RagService(),
      store: StoreService(),
    );
    await RagService().loadCards();
  });

  group('out-of-corpus gate (before the model)', () {
    for (final text in [
      'What is the best chapati recipe?',
      'How do I bake bread?',
      'qwxz zzkp vvrt',
      '   ',
    ]) {
      test('refuses "$text" (en) without calling the model', () async {
        await expectLater(extractor.extract(text, lang: 'en'), throwsA(isA<OutOfCorpusException>()));
        expect(modelCalls, isEmpty);
        expect(await StoreService().getReports(), isEmpty);
      });
    }
  });

  group('in-corpus accounts reach the model', () {
    for (final (text, lang) in [
      ('I witnessed two men grab a young man near the bus stage and force him into a white car. I want to record what happened.', 'en'),
      ('Nimeshuhudia utekaji: watu wawili walimkamata kijana na kumweka kwenye gari jeupe.', 'sw'),
    ]) {
      test('extracts ($lang) "$text"', () async {
        final report = await extractor.extract(text, lang: lang);
        expect(modelCalls, [text]);
        expect(report.rawInput, text);
        expect(await StoreService().getReports(), hasLength(1));
      });
    }
  });

  test('gate agrees with Guide retrieval for the same text and language', () {
    final rag = RagService();
    for (final (text, lang) in [
      ('tear gas in my eyes', 'en'),
      ('best chapati recipe', 'en'),
      ('machozi machoni', 'sw'),
    ]) {
      expect(extractor.isInCorpus(text, lang: lang), rag.retrieveTopK(text, lang: lang).isNotEmpty, reason: text);
    }
    expect(extractor.isInCorpus('tear gas in my eyes'), isTrue);
    expect(extractor.isInCorpus('best chapati recipe'), isFalse);
  });

  // Formerly a known gap (open risk #8): single token / raw prefix matches let off-topic text through
  // ("chapati" ~ "cha", "football" ~ "foot", "write"). Fixed on fix/retrieval-gate.
  test('off-topic text that shares a prefix with card words is refused', () async {
    await expectLater(extractor.extract('best chapati recipe', lang: 'sw'), throwsA(isA<OutOfCorpusException>()));
    await expectLater(extractor.extract('Write me a poem about football', lang: 'en'),
        throwsA(isA<OutOfCorpusException>()));
  });

  test('refusal message is bilingual and points to human help', () {
    expect(OutOfCorpusException.userMessage, contains('lawyer'));
    expect(OutOfCorpusException.userMessage, contains('wakili'));
  });
}
