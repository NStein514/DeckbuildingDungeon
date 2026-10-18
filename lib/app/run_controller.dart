import 'package:flutter/foundation.dart';
import '../core/persistence/run_repository.dart';
import '../game/models/models.dart';
import '../game/progression/run_rules.dart';
import '../game/progression/run_state.dart';

class RunController extends ChangeNotifier {
  RunController(this.repository) : rules = RunRules(repository.catalog);
  final RunRepository repository;
  final RunRules rules;
  RunState? _state;
  RunState? get state => _state?.copy();
  bool busy = false, loaded = false, _disposed = false;
  String? error;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      _state = await repository.load();
      loaded = true;
      error = null;
    } catch (e) {
      error = 'Could not load your run. $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> _commit(RunState Function() transition) async {
    if (busy || !loaded) return false;
    busy = true;
    error = null;
    _notify();
    try {
      final next = transition();
      await repository.save(next);
      _state = next;
      return true;
    } catch (e) {
      error = 'Progress was not saved. Please retry. $e';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> start(int seed) => _commit(() => rules.start(seed));
  Future<bool> descend() => _commit(() => rules.descend(_state!));
  Future<bool> enter(String id) => _commit(() => rules.enter(_state!, id));
  Future<bool> finish(Outcome outcome, int hp) =>
      _commit(() => rules.finishCombat(_state!, outcome, hp));
  Future<bool> reward(String? id) => _commit(() => rules.reward(_state!, id));
  Future<bool> rest({String? upgradeId}) =>
      _commit(() => rules.rest(_state!, upgradeId: upgradeId));
  Future<bool> fuse(String first, String second) =>
      _commit(() => rules.fuse(_state!, first, second));
  Future<bool> skipShrine() => _commit(() => rules.skipShrine(_state!));
  Future<bool> treasure() => _commit(() => rules.treasure(_state!));
}
