import 'package:flutter/material.dart';
import '../services/gemma_service.dart';
import '../services/store.dart';

/// Global app state — language preference, model ready state.
class AppState extends ChangeNotifier {
  final _store = StoreService();
  final _gemma = GemmaService();

  String _language = 'en';
  bool _modelReady = false;
  bool _initialised = false;

  String get language => _language;
  bool get modelReady => _modelReady;
  bool get initialised => _initialised;

  Future<void> init() async {
    _language = await _store.getLanguage();
    await _gemma.initialize();
    _modelReady = _gemma.isModelReady;
    _initialised = true;
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    await _store.setLanguage(lang);
    notifyListeners();
  }

  void setModelReady(bool ready) {
    _modelReady = ready;
    notifyListeners();
  }
}
