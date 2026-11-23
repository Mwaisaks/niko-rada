import 'package:flutter/services.dart';

/// Inference modes, mirroring com.google.firebase.ai.InferenceMode (Firebase AI Logic, Android).
enum HybridMode { preferOnDevice, onlyOnDevice, preferInCloud, onlyInCloud }

extension HybridModeWire on HybridMode {
  String get wire => switch (this) {
        HybridMode.preferOnDevice => 'PREFER_ON_DEVICE',
        HybridMode.onlyOnDevice => 'ONLY_ON_DEVICE',
        HybridMode.preferInCloud => 'PREFER_IN_CLOUD',
        HybridMode.onlyInCloud => 'ONLY_IN_CLOUD',
      };
}

/// Which path served a response, from GenerateContentResponse.inferenceSource.
enum InferenceRoute { onDevice, inCloud, unknown }

InferenceRoute _parseRoute(Object? v) => switch (v) {
      'ON_DEVICE' => InferenceRoute.onDevice,
      'IN_CLOUD' => InferenceRoute.inCloud,
      _ => InferenceRoute.unknown,
    };

class HybridStatus {
  final bool firebaseConfigured;
  final String onDeviceStatus; // AVAILABLE | DOWNLOADABLE | DOWNLOADING | UNAVAILABLE | ...
  final bool online;
  const HybridStatus(this.firebaseConfigured, this.onDeviceStatus, this.online);
}

class HybridResult {
  final String text;
  final InferenceRoute route;
  final String mode;
  final String cloudModel;
  final String onDeviceStatusBefore;
  final bool online;
  final int latencyMs;
  final String? fallbackReason;

  const HybridResult({
    required this.text,
    required this.route,
    required this.mode,
    required this.cloudModel,
    required this.onDeviceStatusBefore,
    required this.online,
    required this.latencyMs,
    this.fallbackReason,
  });

  factory HybridResult.fromMap(Map<Object?, Object?> m) => HybridResult(
        text: (m['text'] as String?) ?? '',
        route: _parseRoute(m['route']),
        mode: (m['mode'] as String?) ?? '',
        cloudModel: (m['cloudModel'] as String?) ?? '',
        onDeviceStatusBefore: (m['onDeviceStatusBefore'] as String?) ?? 'UNKNOWN',
        online: (m['online'] as bool?) ?? false,
        latencyMs: (m['latencyMs'] as num?)?.toInt() ?? 0,
        fallbackReason: m['fallbackReason'] as String?,
      );
}

class HybridInferenceException implements Exception {
  final String code; // e.g. FIREBASE_NOT_CONFIGURED, FirebaseAIOnDeviceNotAvailableException, ...
  final String message;
  final Map<Object?, Object?>? diagnostics;
  const HybridInferenceException(this.code, this.message, [this.diagnostics]);
  @override
  String toString() => 'HybridInferenceException($code): $message';
}

/// Dart client for the Kotlin HybridInferencePlugin (android/app/src/main/kotlin/.../HybridInferencePlugin.kt),
/// which wraps Firebase AI Logic hybrid inference. Phase 1 builds InferenceService on top of this.
class HybridInferenceChannel {
  static const channelName = 'niko_rada/hybrid_inference';
  final MethodChannel _channel;

  HybridInferenceChannel([MethodChannel? channel]) : _channel = channel ?? const MethodChannel(channelName);

  Future<HybridStatus> status({String? cloudModel}) async {
    final m = await _invoke('status', {'cloudModel': cloudModel});
    return HybridStatus(
      (m['firebaseConfigured'] as bool?) ?? false,
      (m['onDeviceStatus'] as String?) ?? 'UNKNOWN',
      (m['online'] as bool?) ?? false,
    );
  }

  Future<Map<Object?, Object?>> downloadOnDeviceModel({String? cloudModel}) =>
      _invoke('download', {'cloudModel': cloudModel});

  Future<HybridResult> generate(
    String prompt, {
    HybridMode mode = HybridMode.preferOnDevice,
    String? cloudModel,
    int? maxOutputTokens,
  }) async {
    final m = await _invoke('generate', {
      'prompt': prompt,
      'mode': mode.wire,
      'cloudModel': cloudModel,
      'maxOutputTokens': maxOutputTokens,
    });
    return HybridResult.fromMap(m);
  }

  Future<Map<Object?, Object?>> _invoke(String method, Map<String, Object?> args) async {
    try {
      final r = await _channel.invokeMethod<Map<Object?, Object?>>(method, args);
      return r ?? const {};
    } on PlatformException catch (e) {
      throw HybridInferenceException(e.code, e.message ?? '', e.details as Map<Object?, Object?>?);
    } on MissingPluginException {
      throw const HybridInferenceException('NO_PLATFORM', 'Hybrid inference is only wired up on Android.');
    }
  }
}
