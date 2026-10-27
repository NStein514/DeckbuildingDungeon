import '../models/models.dart';

class FusionRecipe {
  const FusionRecipe(this.first, this.second, this.result);
  final String first, second, result;
  bool matches(CardInstance a, CardInstance b) =>
      a.id != b.id &&
      ((a.definitionId == first && b.definitionId == second) ||
          (a.definitionId == second && b.definitionId == first));
}

const fusionRecipes = [
  FusionRecipe('measured_strike', 'lantern_watch', 'dawnward'),
  FusionRecipe('stormglass_focus', 'winter_circuit', 'storm_prism'),
  FusionRecipe('patient_fang', 'wasting_venom', 'widows_promise'),
  FusionRecipe('graven_resolve', 'ossuary_ward', 'ancient_bastion'),
  FusionRecipe('phoenix_brand', 'cinder_insight', 'solar_script'),

  FusionRecipe('strike', 'firebolt', 'flaming_strike'),
  FusionRecipe('guard', 'frost_ward', 'glacial_barrier'),
  FusionRecipe('quick_slash', 'poison_edge', 'venom_flurry'),
  FusionRecipe('guard', 'spark', 'stormguard'),
  FusionRecipe('heavy_blow', 'firebolt', 'cinder_maul'),
  FusionRecipe('guard', 'poison_edge', 'venom_ward'),
  FusionRecipe('guard', 'mend', 'bloomguard'),
];
