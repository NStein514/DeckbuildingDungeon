import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'save_store.dart';

Future<SaveStore> createSaveStore({String name = 'run'}) async {
  final dir = await getApplicationSupportDirectory();
  return FileSaveStore(File('${dir.path}/deckbound-$name.json'));
}

/// Flush beside the destination and atomically rename on Android/iOS filesystems.
class FileSaveStore implements SaveStore {
  FileSaveStore(this.file);
  final File file;
  @override
  Future<String?> read() async =>
      await file.exists() ? file.readAsString() : null;
  @override
  Future<void> write(String contents) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(contents, flush: true);
    await temp.rename(file.path);
  }
}
