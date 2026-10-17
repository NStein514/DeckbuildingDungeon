import 'package:web/web.dart' as web;
import 'save_store.dart';

Future<SaveStore> createSaveStore({String name = 'run'}) async =>
    BrowserSaveStore(name);

class BrowserSaveStore implements SaveStore {
  BrowserSaveStore(String name) : key = 'deckbound.$name.v1';
  final String key;
  @override
  Future<String?> read() async => web.window.localStorage.getItem(key);
  @override
  Future<void> write(String contents) async {
    web.window.localStorage.setItem(key, contents);
  }
}
