import '../../game/models/models.dart';

/// Silent implementation until licensed production audio is available.
abstract interface class AudioService {
  void handle(CombatEvent event);
  void setVolumes({required double music, required double effects});
  void dispose();
}

class SilentAudioService implements AudioService {
  @override
  void handle(CombatEvent event) {}
  @override
  void setVolumes({required double music, required double effects}) {}
  @override
  void dispose() {}
}
