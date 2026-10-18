import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../core/persistence/profile_repository.dart';
import '../game/profile/player_profile.dart';
import '../core/persistence/run_repository.dart';
import '../game/models/models.dart';
import '../game/progression/run_rules.dart';
import '../game/progression/run_state.dart';

class RunController extends ChangeNotifier {
  RunController(this.repository, {this.profileRepository})
    : rules = RunRules(repository.catalog);
  final RunRepository repository;
  final ProfileRepository? profileRepository;
  PlayerProfile? _profile;
  PlayerProfile? get profile => _profile;
  String? profileError;
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
      await _loadProfile();
      busy = false;
      _notify();
    }
  }

  Future<void> _loadProfile() async {
    if (profileRepository == null) return;
    try {
      _profile = await profileRepository!.load();
      await _syncProfile();
    } catch (_) {
      _profile = null;
      profileError =
          'Your journal could not be loaded. Its original data is preserved. Retry before replacing this journey.';
    }
  }

  Future<bool> _syncProfile() async {
    if (profileRepository == null) return true;
    if (_profile == null) return false;
    try {
      if (_state != null) {
        final next = _profile!.include(_state!);
        if (jsonEncode(next.toJson()) != jsonEncode(_profile!.toJson())) {
          await profileRepository!.save(next);
          _profile = next;
        }
      }
      profileError = null;
      return true;
    } catch (_) {
      profileError =
          'Your run is saved, but the journal update is pending. Retry before replacing this journey.';
      return false;
    }
  }

  Future<void> retryProfile() async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      await _loadProfile();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> _commit(
    RunState Function() transition, {
    bool replacing = false,
  }) async {
    if (busy || !loaded) return false;
    busy = true;
    error = null;
    _notify();
    try {
      if (replacing && !await _syncProfile()) {
        throw StateError(
          'Retry the journal update before starting another journey.',
        );
      }
      final next = transition();
      await repository.save(next);
      _state = next;
      // Run replacement is already durable. A journal failure must not invite
      // replay of this command; union/max records reconcile on retry or load.
      await _syncProfile();
      return true;
    } catch (e) {
      error = 'Progress was not saved. Please retry. $e';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> start(int seed) =>
      _commit(() => rules.start(seed), replacing: true);
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
  Future<bool> buyCard(String id) => _commit(() => rules.buyCard(_state!, id));
  Future<bool> merchantHeal() => _commit(() => rules.merchantHeal(_state!));
  Future<bool> removeCard(String id) =>
      _commit(() => rules.removeCard(_state!, id));
  Future<bool> leaveMerchant() => _commit(() => rules.leaveMerchant(_state!));
  Future<bool> resolveEvent(bool accept) =>
      _commit(() => rules.resolveEvent(_state!, accept: accept));
  Future<bool> treasure() => _commit(() => rules.treasure(_state!));
}
