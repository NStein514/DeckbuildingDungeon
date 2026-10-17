import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/persistence/save_store.dart';

class GameSettings extends ChangeNotifier {
  GameSettings({this.store});
  final SaveStore? store;
  bool reducedMotion = false,
      fastAnimations = false,
      loaded = false,
      _canPersist = true,
      _disposed = false;
  double musicVolume = .5, effectsVolume = .7;
  String? persistenceError;
  Future<void> _writes = Future.value();
  Future<void> get settled => _writes;
  Duration get duration => Duration(
    milliseconds: reducedMotion
        ? 0
        : fastAnimations
        ? 90
        : 220,
  );
  Future<void> load() async {
    try {
      final text = await store?.read();
      if (text != null) {
        final j = jsonDecode(text) as Map<String, dynamic>;
        if (j['version'] != 1 ||
            j['reducedMotion'] is! bool ||
            j['fastAnimations'] is! bool) {
          throw const FormatException();
        }
        final m = (j['musicVolume'] as num).toDouble(),
            e = (j['effectsVolume'] as num).toDouble();
        if (!m.isFinite || !e.isFinite || m < 0 || m > 1 || e < 0 || e > 1) {
          throw const FormatException();
        }
        reducedMotion = j['reducedMotion'] as bool;
        fastAnimations = j['fastAnimations'] as bool;
        musicVolume = m;
        effectsVolume = e;
      }
    } catch (_) {
      _canPersist = false;
      persistenceError =
          'Saved settings could not be loaded. Changes last for this session only.';
    }
    loaded = true;
    _notify();
  }

  void update({bool? reduced, bool? fast, double? music, double? effects}) {
    reducedMotion = reduced ?? reducedMotion;
    fastAnimations = fast ?? fastAnimations;
    musicVolume = (music ?? musicVolume).clamp(0, 1);
    effectsVolume = (effects ?? effectsVolume).clamp(0, 1);
    _notify();
    if (store == null || !_canPersist || !loaded) return;
    final text = jsonEncode({
      'version': 1,
      'reducedMotion': reducedMotion,
      'fastAnimations': fastAnimations,
      'musicVolume': musicVolume,
      'effectsVolume': effectsVolume,
    });
    _writes = _writes.then((_) async {
      try {
        await store!.write(text);
        persistenceError = null;
      } catch (_) {
        persistenceError =
            'Settings could not be saved. Change a setting to retry.';
      }
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
