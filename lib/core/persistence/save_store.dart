abstract interface class SaveStore {
  Future<String?> read();
  Future<void> write(String contents);
}

class MemorySaveStore implements SaveStore {
  String? contents;
  @override
  Future<String?> read() async => contents;
  @override
  Future<void> write(String contents) async {
    this.contents = contents;
  }
}
