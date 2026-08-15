import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager I = AudioManager._();
  AudioManager._();

  // 测试环境下不创建播放器（避免 MissingPluginException 异步报错）
  static const bool _inTest = bool.fromEnvironment('FLUTTER_TEST');

  static const int _sfxPoolSize = 6; // 多播放器池，避免高频音效互相覆盖
  final List<AudioPlayer> _sfx = [];
  int _sfxIdx = 0;
  AudioPlayer? _bgmBattle;
  AudioPlayer? _bgmBoss;
  bool _enabled = true;
  int _lastHitMs = 0;
  int _lastPickupMs = 0;
  String _currentBgm = '';
  final Map<String, int> _lastWeapon = {};
  double _sfxVolume = 0.6;
  double _bgmVolume = 0.32;

  bool get enabled => _enabled;

  double get sfxVolume => _sfxVolume;
  double get bgmVolume => _bgmVolume;

  set sfxVolume(double v) {
    _sfxVolume = v.clamp(0, 1);
  }

  set bgmVolume(double v) {
    _bgmVolume = v.clamp(0, 1);
  }

  set enabled(bool v) {
    _enabled = v;
    if (!v) {
      for (final s in _sfx) {
        s.stop().catchError((_) {});
      }
      _bgmBattle?.stop().catchError((_) {});
      _bgmBoss?.stop().catchError((_) {});
    } else {
      playBgm('bgm.mp3');
    }
  }

  Future<void> init() async {
    if (_inTest) return;
    try {
      _bgmBattle = AudioPlayer();
      _bgmBoss = AudioPlayer();
      await _bgmBattle!.setReleaseMode(ReleaseMode.loop);
      await _bgmBoss!.setReleaseMode(ReleaseMode.loop);
      for (int i = 0; i < _sfxPoolSize; i++) {
        _sfx.add(AudioPlayer());
      }
      await _bgmBattle!.play(AssetSource('audio/bgm.mp3'), volume: 0.32 * _bgmVolume);
      _currentBgm = 'bgm.mp3';
    } catch (_) {
      _sfx.clear();
      _bgmBattle = null;
      _bgmBoss = null;
    }
  }

  AudioPlayer? _nextSfx() {
    if (_sfx.isEmpty) return null;
    final s = _sfx[_sfxIdx];
    _sfxIdx = (_sfxIdx + 1) % _sfx.length;
    return s;
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
        await boss.play(AssetSource('audio/bgm_boss.wav'), volume: 0.55 * _bgmVolume);
      } catch (_) {}
    } else {
      try {
        await boss.stop();
        await battle.play(AssetSource('audio/bgm.mp3'), volume: 0.32 * _bgmVolume);
      } catch (_) {}
    }
  }

  // 武器专属音效（按武器节流，避免高频连射噪音）
  Future<void> playWeapon(String key, String file, {double volume = 0.4}) async {
    if (!_enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastWeapon[key] ?? 0;
    if (now - last < 120) return;
    _lastWeapon[key] = now;
    final s = _nextSfx();
    if (s == null) return;
    try {
      await s.play(AssetSource('audio/$file'), volume: volume * _sfxVolume);
    } catch (_) {}
  }

  Future<void> play(String name, {double volume = 0.6, String? file}) async {
    if (!_enabled) return;
    final s = _nextSfx();
    if (s == null) return;
    try {
      await s.play(AssetSource('audio/${file ?? '$name.wav'}'),
          volume: volume * _sfxVolume);
    } catch (_) {}
  }

  // 拾取音效节流（金币/经验高频收集时避免噪音）
  Future<void> playPickup() async {
    if (!_enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPickupMs < 60) return;
    _lastPickupMs = now;
    final s = _nextSfx();
    if (s == null) return;
    try {
      await s.play(AssetSource('audio/sfx_pickup.wav'), volume: 0.35 * _sfxVolume);
    } catch (_) {}
  }

  // 命中音效节流（高频伤害时避免噪音）
  Future<void> playHit() async {
    if (!_enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHitMs < 80) return;
    _lastHitMs = now;
    final s = _nextSfx();
    if (s == null) return;
    try {
      await s.play(AssetSource('audio/sfx_hit.ogg'), volume: 0.16 * _sfxVolume);
    } catch (_) {}
  }
}
