/// Portable 32-bit LCG: identical shuffles on native and web runtimes.
class SeededRandom {
  SeededRandom(int seed) : state = seed & 0xffffffff;
  int state;

  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max');
    state = (1664525 * state + 1013904223) & 0xffffffff;
    return state % max;
  }

  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final value = items[i];
      items[i] = items[j];
      items[j] = value;
    }
  }
}
