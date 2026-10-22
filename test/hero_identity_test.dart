import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'package:deckbound/game/progression/starting_build.dart';
import 'test_catalog.dart';

void main() {
  test('hero identity survives deck changes, reload and deeper descent', () {
    final rules = RunRules(loadCatalog());
    for (final build in StartingBuild.values) {
      final run = rules.start(514, build: build);
      run.deck.removeAt(0);
      final restored = RunState.fromJson(run.toJson());
      expect(restored.startingBuild, build);
      restored.phase = RunPhase.victory;
      expect(rules.descend(restored).startingBuild, build);
    }
  });
  test('legacy saves default to Wanderer; invalid identities are rejected', () {
    final json = RunRules(loadCatalog()).start(514).toJson()
      ..remove('startingBuild');
    expect(RunState.fromJson(json).startingBuild, StartingBuild.wanderer);
    json['startingBuild'] = 'invalid';
    expect(() => RunState.fromJson(json), throwsArgumentError);
  });
}
