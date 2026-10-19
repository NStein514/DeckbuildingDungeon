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
  FusionRecipe('strike', 'firebolt', 'flaming_strike'),
  FusionRecipe('guard', 'frost_ward', 'glacial_barrier'),
  FusionRecipe('quick_slash', 'poison_edge', 'venom_flurry'),
  FusionRecipe('guard', 'spark', 'stormguard'),
  FusionRecipe('heavy_blow', 'firebolt', 'cinder_maul'),
];
