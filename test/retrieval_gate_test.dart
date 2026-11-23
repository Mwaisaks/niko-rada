import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niko_rada/services/rag.dart';

import 'fixtures/retrieval_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rag = RagService();

  setUpAll(() async => rag.loadCards());

  group('in-corpus queries retrieve a sensible card (top 4)', () {
    for (final q in inCorpusQueries) {
      test('[${q.lang}] ${q.panic ? 'PANIC ' : ''}${q.query}', () {
        final ids = rag.retrieveTopK(q.query, lang: q.lang).map((c) => c.id).toList();
        expect(ids.any(q.expected.contains), isTrue,
            reason: 'expected one of ${q.expected}, got $ids');
      });
    }
  });

  group('out-of-corpus queries are refused in both language modes', () {
    for (final q in outOfCorpusQueries) {
      for (final lang in ['en', 'sw']) {
        test('[$lang] $q', () {
          final ids = rag.retrieveTopK(q, lang: lang).map((c) => c.id).toList();
          expect(ids, isEmpty, reason: 'should refuse, got $ids');
        });
      }
    }
  });

  test('empty and stopword-only input is refused', () {
    for (final q in ['', '   ', 'the and of', 'na ya kwa ni', '??!!']) {
      expect(rag.retrieveTopK(q, lang: 'en'), isEmpty, reason: q);
      expect(rag.retrieveTopK(q, lang: 'sw'), isEmpty, reason: q);
    }
  });

  // Set RETRIEVAL_REPORT=1 to print the per-query table used in the before/after report.
  test('report', () {
    if (Platform.environment['RETRIEVAL_REPORT'] != '1') return;
    final out = StringBuffer('\nRETRIEVAL REPORT\n');
    for (final q in [...inCorpusQueries, ...shengPanicQueries]) {
      final ids = rag.retrieveTopK(q.query, lang: q.lang).map((c) => c.id).toList();
      final top1 = ids.isNotEmpty && q.expected.contains(ids.first);
      final top2 = ids.take(2).any(q.expected.contains);
      final top4 = ids.any(q.expected.contains);
      out.writeln('IN|${q.lang}|${q.panic ? 'P' : ''}|${q.query}|${top1 ? 1 : 0}${top2 ? 1 : 0}${top4 ? 1 : 0}|$ids');
    }
    for (final q in outOfCorpusQueries) {
      for (final lang in ['en', 'sw']) {
        final ids = rag.retrieveTopK(q, lang: lang).map((c) => c.id).toList();
        out.writeln('OUT|$lang||$q|${ids.isEmpty ? 'refused' : 'PASSED'}|$ids');
      }
    }
    // ignore: avoid_print
    print(out);
  });
}
