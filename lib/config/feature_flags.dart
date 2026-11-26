/// Compile-time feature flags.
library;

/// Answer flow on Firebase AI Logic hybrid inference (default), or the legacy flutter_gemma path.
///
/// `flutter run --dart-define=HYBRID_AI=false` restores the old build: model-download screen + GemmaService streaming
/// answers. Kept until the owner confirms Android and flutter_gemma is removed (Phase 1, item 4).
const bool kHybridAi = bool.fromEnvironment('HYBRID_AI', defaultValue: true);
