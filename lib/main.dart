import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'src/ad.dart';
import 'src/audio.dart';
import 'src/config.dart';
import 'src/input.dart';
import 'src/render.dart';
import 'src/save.dart';
import 'src/state.dart';
import 'src/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSave(); // 加载 SQLite 存档
  runApp(const DarkSlashApp());
}

class DarkSlashApp extends StatelessWidget {
  const DarkSlashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '球球进化',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7E57C2), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GameState game = GameState();
  final InputState _input = InputState();
  final FixedJoy _joy = FixedJoy();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _up = 0, _down = 0, _left = 0, _right = 0;
  Offset? _cursor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioManager.I.init();
    AudioManager.I.enabled = game.settings.sound;
    AudioManager.I.sfxVolume = game.settings.sfxVolume;
    AudioManager.I.bgmVolume = game.settings.bgmVolume;
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 意外退出（切后台/锁屏/关闭）先存档再暂停；死亡不算存档
    if (state != AppLifecycleState.resumed && game.phase == GamePhase.playing) {
      game.saveRun();
      game.phase = GamePhase.paused;
      setState(() {});
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (game.phase != GamePhase.playing) {
      _joy.end();
    }
    var dx = _input.mx, dy = _input.my;
    if (_joy.active) {
      final d = _joy.direction(85);
      dx += d.dx;
      dy += d.dy;
    } else if (_cursor != null) {
      final hd = holdDirection(
          Offset(game.player.x, game.player.y), _cursor!, game.viewW, game.viewH);
      dx += hd.dx;
      dy += hd.dy;
    }
    game.update(dt, Offset(dx, dy));
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final down = event is KeyDownEvent || event is KeyRepeatEvent;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.arrowUp) {
      _up = down ? 1 : 0;
    } else if (k == LogicalKeyboardKey.keyS || k == LogicalKeyboardKey.arrowDown) {
      _down = down ? 1 : 0;
    } else if (k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.arrowLeft) {
      _left = down ? 1 : 0;
    } else if (k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.arrowRight) {
      _right = down ? 1 : 0;
    } else if (k == LogicalKeyboardKey.keyP || k == LogicalKeyboardKey.escape) {
      if (down) togglePause();
    } else {
      return KeyEventResult.ignored;
    }
    _input.mx = (_right - _left).toDouble();
    _input.my = (_down - _up).toDouble();
    return KeyEventResult.handled;
  }

  void togglePause() {
    if (game.phase == GamePhase.playing) {
      game.phase = GamePhase.paused;
    } else if (game.phase == GamePhase.paused) {
      game.phase = GamePhase.playing;
    }
    setState(() {});
  }

  void _startNew() {
    game.startNewRun();
    setState(() {});
  }

  void _continue() {
    game.continueRun();
    setState(() {});
  }

  void _pick(UpgradeChoice c) {
    game.applyChoice(c);
    setState(() {});
  }

  void _retry() {
    game.startNewRun();
    setState(() {});
  }

  void _toMenu() {
    game.phase = GamePhase.menu;
    game.saveMeta();
    setState(() {});
  }

  void _buyMeta(int i) {
    game.buyMeta(i);
    setState(() {});
  }

  void _buySkin(int i) {
    if (game.buySkin(i)) setState(() {});
  }

  void _selectSkin(int i) {
    game.selectSkin(i);
    setState(() {});
  }

  void _openSkills() => showSkillsDialog(context, game);
  void _openStatus() => showStatusDialog(context, game);

  void _toggleSound() {
    game.settings.sound = !game.settings.sound;
    AudioManager.I.enabled = game.settings.sound;
    game.saveMeta();
    setState(() {});
  }

  void _openSettings() {
    showSettingsDialog(context, game);
    AudioManager.I.sfxVolume = game.settings.sfxVolume;
    AudioManager.I.bgmVolume = game.settings.bgmVolume;
    AudioManager.I.enabled = game.settings.sound;
    setState(() {});
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _adRevive() async {
    final ok = await adService.showRewarded(AdReward.revive);
    if (!mounted) return;
    if (!ok) {
      _toast('广告未看完，未复活');
      return;
    }
    game.revive();
    setState(() {});
  }

  Future<void> _adCoins() async {
    final ok = await adService.showRewarded(AdReward.coins);
    if (!mounted) return;
    if (!ok) {
      _toast('广告未看完，未发放金币');
      return;
    }
    // 看广告金币阶梯上升：每看 3 次升一档
    final step = (game.meta.adsWatched ~/ 3) > 9 ? 9 : (game.meta.adsWatched ~/ 3);
    final reward = kAdCoinsBase * (1 + step);
    game.meta.adsWatched++;
    game.meta.gold += reward;
    game.saveMeta();
    _toast('+$reward 金币');
    setState(() {});
  }

  Future<void> _openMonthlyCard() async {
    if (game.meta.monthlyCard) {
      _toast('月卡已开通');
      return;
    }
    final ok = await game.buyMonthlyCard();
    if (!mounted) return;
    if (ok) {
      _toast('月卡开通成功！每局可复活 $kMonthlyRevives 次');
    } else {
      _toast('购买未完成');
    }
    setState(() {});
  }

  Future<void> _adItem() async {
    final ok = await adService.showRewarded(AdReward.item);
    if (!mounted) return;
    if (!ok) {
      _toast('广告未看完，未获得道具');
      return;
    }
    const kinds = ['shield', 'power', 'haste'];
    game.grantBuff(kinds[game.rng.nextInt(kinds.length)]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final phase = game.phase;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E14),
        body: Stack(children: [
          Positioned.fill(
            child: MouseRegion(
              onHover: (e) => _cursor = e.localPosition,
              onExit: (_) => _cursor = null,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  if (e.kind == PointerDeviceKind.touch) {
                    final c = _joy.center.distance == 0
                        ? Offset(game.viewW / 2, game.viewH - 135)
                        : _joy.center;
                    if ((e.localPosition - c).distance <= 140) {
                      _joy.start(e.localPosition, c);
                    }
                  }
                },
                onPointerMove: (e) {
                  if (_joy.active) _joy.move(e.localPosition);
                },
                onPointerUp: (e) => _joy.end(),
                onPointerCancel: (e) => _joy.end(),
                child: CustomPaint(painter: GamePainter(game), size: Size.infinite),
              ),
            ),
          ),
          Positioned.fill(
            child: JoystickOverlay(_joy, visible: phase == GamePhase.playing),
          ),
          if (phase != GamePhase.menu)
            Positioned.fill(
                child: Hud(game,
                    onPause: togglePause,
                    onToggleSound: _toggleSound,
                    soundOn: AudioManager.I.enabled)),
          if (phase == GamePhase.levelup)
            Positioned.fill(child: UpgradePanel(game, onPick: _pick)),
          if (phase == GamePhase.paused)
            Positioned.fill(
                child: PausePanel(game,
                    onResume: togglePause, onRetry: _retry, onMenu: _toMenu,
                    onAdItem: _adItem, onSkills: _openSkills, onStatus: _openStatus,
                    onSettings: _openSettings)),
          if (phase == GamePhase.gameover)
            Positioned.fill(
                child: GameOverPanel(game,
                    onRetry: _retry, onMenu: _toMenu, onRevive: _adRevive)),
          if (phase == GamePhase.menu)
            Positioned.fill(
                child: MenuPanel(game,
                    onStart: _startNew, onContinue: _continue, onBuyMeta: _buyMeta,
                    onAdCoins: _adCoins, onMonthlyCard: _openMonthlyCard,
                    onBuySkin: _buySkin, onSelectSkin: _selectSkin)),
        ]),
      ),
    );
  }
}
