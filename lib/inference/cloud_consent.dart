import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether crisis text may be sent to the cloud model. Read by the inference layer on every request.
abstract interface class CloudConsent {
  bool get granted;
}

/// Explicit, revocable consent for cloud inference. **Default: not granted.**
///
/// - Persisted locally (SharedPreferences) with the consent-text version and the time it was given.
/// - If the consent text changes ([currentVersion] bumped), earlier consent no longer counts: ask again.
/// - Revoking takes effect immediately for the next request.
/// - Until [load] completes, consent is treated as not granted.
/// UI comes later (Phase 2); this is the model only.
class CloudConsentStore extends ChangeNotifier implements CloudConsent {
  static const currentVersion = 1;
  static const _key = 'cloud_consent';

  DateTime? _grantedAt;
  bool _loaded = false;

  @override
  bool get granted => _grantedAt != null;
  DateTime? get grantedAt => _grantedAt;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _grantedAt = _parse(prefs.getString(_key));
    _loaded = true;
    notifyListeners();
  }

  Future<void> grant({DateTime? now}) async {
    final at = (now ?? DateTime.now()).toUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'v$currentVersion|${at.toIso8601String()}');
    _grantedAt = at;
    notifyListeners();
  }

  Future<void> revoke() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _grantedAt = null;
    notifyListeners();
  }

  /// Stored as `v<version>|<ISO-8601 UTC>`. Anything else (missing, malformed, older version) means not granted.
  static DateTime? _parse(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 2 || parts[0] != 'v$currentVersion') return null;
    return DateTime.tryParse(parts[1]);
  }
}
