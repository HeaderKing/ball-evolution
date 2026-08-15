import 'dart:js_interop';
import 'package:sqlite3/wasm.dart' as sqlite_wasm;

// Web 端存档：SQLite(Wasm) 持久化到 IndexedDB；加载失败回退 localStorage
extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

@JS('localStorage')
external _Storage get _storage;

const String _lsKey = 'dark_slash_save';

Map<String, String> _kv = {};
void Function(String key, String value)? _persist;

Future<void> initSave() async {
  try {
    final sqlite = await sqlite_wasm.WasmSqlite3.loadFromUrlString('sqlite3.wasm');
    final fs = await sqlite_wasm.IndexedDbFileSystem.open(dbName: 'dark_slash');
    sqlite.registerVirtualFileSystem(fs, makeDefault: true);
    final db = sqlite.open('/app.db');
    db.execute('CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT)');
    for (final row in db.select('SELECT key, value FROM kv')) {
      _kv[row['key'] as String] = row['value'] as String;
    }
    _persist = (String key, String value) {
      db.execute(
        'INSERT INTO kv(key, value) VALUES(?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value=excluded.value',
        [key, value],
      );
    };
    // 迁移旧 localStorage 存档
    if (_kv.isEmpty) {
      final old = _storage.getItem(_lsKey);
      if (old != null && old.isNotEmpty) {
        _kv['game'] = old;
        _persist!('game', old);
      }
    }
  } catch (_) {
    final old = _storage.getItem(_lsKey);
    if (old != null) _kv['game'] = old;
    _persist = (String key, String value) => _storage.setItem(_lsKey, value);
  }
}

String? readSave() => _kv['game'];

void writeSave(String data) {
  _kv['game'] = data;
  _persist?.call('game', data);
}
