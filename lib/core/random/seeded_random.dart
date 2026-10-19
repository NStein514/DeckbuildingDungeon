/// Portable 32-bit LCG: identical shuffles on native and web runtimes.
class SeededRandom {
  SeededRandom(int seed) : state = seed & 0xffffffff;
  int state;

  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max');
    state = (1664525 * state + 1013904223) & 0xffffffff;
    return state % max;
  }

  /// Uses high bits and rejection sampling; legacy nextInt stays unchanged.
  int nextFairInt(int max) {
    const range = 0x1000000;
    if (max <= 0 || max > range) throw ArgumentError.value(max, 'max');
    final limit = range - range % max;
    int sample;
    do {
      sample = nextInt(0x100000000) >>> 8;
    } while (sample >= limit);
    return sample % max;
  }

  void shuffleFair<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextFairInt(i + 1);
      final item = items[i];
      items[i] = items[j];
      items[j] = item;
    }
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
