import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps generated invoices and PO files in the app's own folder
/// (Documents/MarsEngineers/...) so links don't break if the original moves.
class FileStore {
  static Future<String> save(
    String subfolder,
    String fileName,
    Uint8List bytes,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'MarsEngineers', subfolder));
    await dir.create(recursive: true);

    final safe = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    var path = p.join(dir.path, safe);
    if (await File(path).exists() &&
        subfolder != 'invoices' &&
        subfolder != 'statements' &&
        subfolder != 'packages' &&
        subfolder != 'gst') {
      final ext = p.extension(safe);
      final base = p.basenameWithoutExtension(safe);
      path = p.join(
        dir.path,
        '${base}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
    }

    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
