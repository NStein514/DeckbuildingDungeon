import 'package:flutter/foundation.dart';

/// Session settings; durable settings join versioned run saves in milestone 2.
class GameSettings extends ChangeNotifier {
  bool reducedMotion = false;
  bool fastAnimations = false;
  double musicVolume = .5, effectsVolume = .7;
  Duration get duration => Duration(milliseconds: reducedMotion ? 0 : fastAnimations ? 90 : 220);
  void update({bool? reduced, bool? fast, double? music, double? effects}) {
    reducedMotion = reduced ?? reducedMotion;
    fastAnimations = fast ?? fastAnimations;
    musicVolume = music ?? musicVolume;
    effectsVolume = effects ?? effectsVolume;
    notifyListeners();
  }
}
