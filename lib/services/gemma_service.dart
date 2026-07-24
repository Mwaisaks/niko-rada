import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import '../prompts/prompts.dart';
import '../services/rag.dart';

/// Model URL — ungated LiteRT-community weights for Gemma 4 E2B.
const _kModelUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

/// GemmaService — engine-agnostic interface over flutter_gemma.
/// Handles: initialize, model install, grounded answers, structured extraction.
class GemmaService {
  GemmaService._();
  static final GemmaService _instance = GemmaService._();
  factory GemmaService() => _instance;

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _initialised = false;

  final _rag = RagService();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Call once at app startup (main.dart or splash screen).
  Future<void> initialize() async {
    if (_initialised) return;
    await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);
    await _rag.loadCards();
    _initialised = true;
  }

  /// Whether the model file is already downloaded and set active.
  bool get isModelReady => FlutterGemma.hasActiveModel();

  /// Download the model. Provide [onProgress] for UI feedback (0.0–1.0).
  Future<void> installModel({void Function(double)? onProgress}) async {
    final builder = FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(_kModelUrl);

    if (onProgress != null) {
      builder.withProgress((percent) => onProgress(percent / 100));
    }

    await builder.install();
  }

  // ---------------------------------------------------------------------------
  // Grounded answer (F1 chat + F2 panic buttons)
  // ---------------------------------------------------------------------------

  /// Returns a grounded, cited, streamed answer in the given [lang].
  /// If no relevant cards are found, returns the refusal string.
  Stream<String> answer(String query, {String lang = 'en'}) async* {
    if (!_initialised) throw StateError('GemmaService not initialised');

    final cards = _rag.retrieveTopK(query, lang: lang);

    if (cards.isEmpty) {
      // Refusal path — no hallucination
      yield lang == 'sw' || lang == 'sheng'
          ? 'Sina taarifa ya hilo katika maktaba yangu. Tafadhali wasiliana na daktari, wakili, au mamlaka unayoyaamini.\n\n_Mwongozo tu, si dhamana. Si ushauri wa kisheria au kimatibabu._'
          : "I don't have that in my library. Please consult a doctor, lawyer, or trusted authority.\n\n_Guidance only, not a guarantee. Not legal or medical advice._";
      return;
    }

    final context = _rag.formatForPrompt(cards, lang);
    final prompt = Prompts.groundedAnswer(
      query: query,
      retrievedCards: context,
      language: lang,
    );

    yield* _streamGenerate(prompt);
  }

  // ---------------------------------------------------------------------------
  // Structured extraction (F3 incident logger)
  // ---------------------------------------------------------------------------

  /// Extracts a structured incident report from free text or voice transcript.
  /// Returns raw JSON string; caller is responsible for parsing.
  Future<String> extractIncident(String freeText) async {
    if (!_initialised) throw StateError('GemmaService not initialised');
    final prompt = Prompts.extractIncident(freeText);
    final buffer = StringBuffer();
    await for (final chunk in _streamGenerate(prompt)) {
      buffer.write(chunk);
    }
    return buffer.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  /// Lazily creates (once) and reuses the model + chat session — reloading
  /// the model weights on every call would be prohibitively slow on-device.
  Future<InferenceChat> _ensureChat() async {
    _model ??= await FlutterGemma.getActiveModel(maxTokens: 1024);
    _chat ??= await _model!.createChat(modelType: ModelType.gemma4);
    return _chat!;
  }

  Stream<String> _streamGenerate(String prompt) async* {
    final chat = await _ensureChat();
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        yield response.token;
      }
    }
  }

  Future<void> dispose() async {
    await _chat?.close();
    await _model?.close();
    _chat = null;
    _model = null;
    _initialised = false;
  }
}
