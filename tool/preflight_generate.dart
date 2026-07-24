// Temporary pre-flight probe — NOT part of the app. Proves one real
// end-to-end offline generation on the Linux desktop build:
//   1. Installs the model from a local file (already downloaded out-of-band).
//   2. Runs a real panic-button query through GemmaService.answer().
//   3. Prints the response, then exits.
// Run under `strace -e trace=network` to prove no network syscalls fire
// during generation. Delete this file once the proof is captured.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:niko_rada/services/gemma_service.dart';

/// Path to the model file, already downloaded out-of-band (curl) to avoid
/// re-downloading through the app's own (still-unverified) F0 download flow.
const _kLocalModelPath =
    '/tmp/claude-1000/-home-mwaisaka-mercie-Desktop-projects-niko-rada/67b6195c-d176-4e22-930c-f6d870b13a0b/scratchpad/model/gemma-4-E2B-it.litertlm';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final gemma = GemmaService();

  stdout.writeln('PREFLIGHT: initializing GemmaService...');
  await gemma.initialize();

  if (!gemma.isModelReady) {
    stdout.writeln('PREFLIGHT: installing model from local file: $_kLocalModelPath');
    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(_kLocalModelPath).install();
  } else {
    stdout.writeln('PREFLIGHT: model already active, skipping install.');
  }

  stdout.writeln('PREFLIGHT: >>> GENERATION_START <<<');
  final buffer = StringBuffer();
  try {
    await for (final chunk in gemma.answer(
      'There is tear gas. What do I do right now?',
      lang: 'en',
    )) {
      buffer.write(chunk);
    }
    stdout.writeln('PREFLIGHT: >>> GENERATION_END <<<');
    stdout.writeln('PREFLIGHT: RESPONSE_START');
    stdout.writeln(buffer.toString());
    stdout.writeln('PREFLIGHT: RESPONSE_END');
    stdout.writeln('PREFLIGHT: SUCCESS');
  } catch (e, st) {
    stdout.writeln('PREFLIGHT: >>> GENERATION_END (ERROR) <<<');
    stdout.writeln('PREFLIGHT: FAILURE: $e');
    stdout.writeln(st.toString());
  }

  exit(0);
}
