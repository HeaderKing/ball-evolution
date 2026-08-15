import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager I = AudioManager._();
  AudioManager._();

  // 测试环境下不创建播放器（避免 MissingPluginException 异步报错）
  static const bool _inTest = bool.fromEnvironment('FLUTTER_TEST');

  AudioPlayer? _sfx;
  AudioPlayer? _bgmBattle;
  AudioPlayer? _bgmBoss;
  bool _enabled = true;
  int _lastHitMs = 0;
  String _currentBgm = '';
  final Map<String, int> _lastWeapon = {};

  bool get enabled => _enabled;

  set enabled(bool v) {
    _enabled = v;
    if (!v) {
      _bgmBattle?.stop().catchError((_) {});
      _bgmBoss?.stop().catchError((_) {});
    } else {
      playBgm('bgm.mp3');
    }
  }

  Future<void> init() async {
    if (_inTest) return;
    try {
      _sfx = AudioPlayer();
      _bgmBattle = AudioPlayer();
      _bgmBoss = AudioPlayer();
      await _bgmBattle!.setReleaseMode(ReleaseMode.loop);
      await _bgmBoss!.setReleaseMode(ReleaseMode.loop);
      await _bgmBattle!.play(AssetSource('audio/bgm.mp3'), volume: 0.32);
      _currentBgm = 'bgm.mp3';
    } catch (_) {
      _sfx = null;
      _bgmBattle = null;
      _bgmBoss = null;
    }
  }

  // 切换背景乐：战斗与 Boss 各用一个播放器，切换稳定、Boss 音量更大
  Future<void> playBgm(String file) async {
    if (_currentBgm == file) return;
    _currentBgm = file;
    final battle = _bgmBattle, boss = _bgmBoss;
    if (battle == null || boss == null) return;
    if (file == 'bgm_boss.wav') {
      try {
        await battle.stop();
        await boss.play(AssetSource('audio/bgm_boss.wav'), volume: 0.55);
      } catch (_) {}
    } else {
      try {
        await boss.stop();
        await battle.play(AssetSource('audio/bgm.mp3'), volume: 0.32);
      } catch (_) {}
    }
  }

  // 武器专属音效（按武器节流，避免高频连射噪音）
  Future<void> playWeapon(String key, String file, {double volume = 0.4}) async {
    final s = _sfx;
    if (!_enabled || s == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastWeapon[key] ?? 0;
    if (now - last < 120) return;
    _lastWeapon[key] = now;
    try {
      await s.play(AssetSource('audio/$file'), volume: volume);
    } catch (_) {}
  }

  Future<void> play(String name, {double volume = 0.6, String? file}) async {
    final s = _sfx;
    if (!_enabled || s == null) return;
    try {
      await s.play(AssetSource('audio/${file ?? '$name.wav'}'), volume: volume);
    } catch (_) {}
  }

  // 命中音效节流（高频伤害时避免噪音）
  Future<void> playHit() async {
    final s = _sfx;
    if (!_enabled || s == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHitMs < 80) return;
    _lastHitMs = now;
    try {
      await s.play(AssetSource('audio/sfx_hit.ogg'), volume: 0.16);
    } catch (_) {}
  }
}
