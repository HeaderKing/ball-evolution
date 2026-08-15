import 'dart:io';
import 'package:path_provider/path_provider.dart';

// 非 Web 端存档：写入应用文档目录 dark_slash_save.json
File? _saveFile;
Map<String, String> _kv = {};

Future<void> initSave() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    _saveFile = File('${dir.path}${Platform.pathSeparator}dark_slash_save.json');
    if (_saveFile!.existsSync()) _kv['game'] = _saveFile!.readAsStringSync();
  } catch (_) {}
}

String? readSave() => _kv['game'];

void writeSave(String data) {
  _kv['game'] = data;
  try {
    final f = _saveFile;
    if (f == null) return;
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(data);
  } catch (_) {}
}
