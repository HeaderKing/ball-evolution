import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'config.dart';
import 'entities.dart';
import 'input.dart';
import 'state.dart';

String fmtTime(double t) {
  final m = t ~/ 60;
  final s = (t % 60).floor();
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ============ 技能图标 ============
class WeaponIcon extends StatelessWidget {
  final WeaponType type;
  final Color color;
  final double size;
  const WeaponIcon(this.type, {super.key, required this.color, this.size = 20});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _WeaponIconPainter(type, color));
}

class _WeaponIconPainter extends CustomPainter {
  final WeaponType type;
  final Color color;
  _WeaponIconPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final w = size.width;
    Paint s() => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w / 11;
    final f = Paint()..color = color;
    switch (type) {
      case WeaponType.bolt:
        canvas.drawCircle(c - Offset(w * 0.3, 0), w * 0.14, f);
        canvas.drawCircle(c, w * 0.2, f);
        canvas.drawLine(c - Offset(w * 0.42, 0), c, s()..strokeWidth = w / 7);
        break;
      case WeaponType.orbit:
        final blade = Path()
          ..moveTo(c.dx, c.dy - w * 0.46)
          ..lineTo(c.dx + w * 0.14, c.dy + w * 0.02)
          ..lineTo(c.dx - w * 0.14, c.dy + w * 0.02)
          ..close();
        canvas.drawPath(blade, f);
        canvas.drawLine(Offset(c.dx - w * 0.22, c.dy + w * 0.04), Offset(c.dx + w * 0.22, c.dy + w * 0.04),
            s()..strokeWidth = w / 14);
        canvas.drawLine(Offset(c.dx, c.dy + w * 0.04), Offset(c.dx, c.dy + w * 0.26),
            s()..strokeWidth = w / 12);
        canvas.drawCircle(c, w * 0.34, Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w / 16);
        break;
      case WeaponType.axe:
        final head = Path()
          ..moveTo(c.dx, c.dy - w * 0.36)
          ..lineTo(c.dx + w * 0.3, c.dy - w * 0.22)
          ..lineTo(c.dx + w * 0.34, c.dy + w * 0.16)
          ..quadraticBezierTo(c.dx + w * 0.16, c.dy + w * 0.3, c.dx, c.dy + w * 0.22)
          ..quadraticBezierTo(c.dx - w * 0.16, c.dy + w * 0.3, c.dx - w * 0.34, c.dy + w * 0.16)
          ..lineTo(c.dx - w * 0.3, c.dy - w * 0.22)
          ..close();
        canvas.drawPath(head, f);
        canvas.drawLine(Offset(c.dx, c.dy + w * 0.22), Offset(c.dx + w * 0.08, c.dy + w * 0.46),
            s()..strokeWidth = w / 10);
        break;
      case WeaponType.lightning:
        final path = Path()
          ..moveTo(c.dx + w * 0.14, c.dy - w * 0.42)
          ..lineTo(c.dx - w * 0.2, c.dy + w * 0.1)
          ..lineTo(c.dx + w * 0.02, c.dy + w * 0.1)
          ..lineTo(c.dx - w * 0.14, c.dy + w * 0.42)
          ..lineTo(c.dx + w * 0.2, c.dy - w * 0.1)
          ..lineTo(c.dx - w * 0.02, c.dy - w * 0.1)
          ..close();
        canvas.drawPath(path, f);
        break;
      case WeaponType.aura:
        final path = Path()
          ..moveTo(c.dx, c.dy - w * 0.42)
          ..quadraticBezierTo(c.dx + w * 0.32, c.dy + w * 0.05, c.dx, c.dy + w * 0.42)
          ..quadraticBezierTo(c.dx - w * 0.32, c.dy + w * 0.05, c.dx, c.dy - w * 0.42);
        canvas.drawPath(path, f);
        break;
      case WeaponType.frost:
        final p = s();
        for (int i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * w * 0.4, p);
          for (int b = -1; b <= 1; b += 2) {
            final br = a + b * math.pi / 4;
            canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * w * 0.2,
                c + Offset(math.cos(br) * w * 0.34, math.sin(br) * w * 0.34), p);
          }
        }
        canvas.drawCircle(c, w * 0.08, f);
        break;
      case WeaponType.homing:
        canvas.drawCircle(c, w * 0.28, s());
        canvas.drawLine(c, c + Offset(w * 0.42, 0), s()..strokeWidth = w / 8);
        canvas.drawLine(c + Offset(w * 0.3, -w * 0.12), c + Offset(w * 0.42, 0), s());
        canvas.drawLine(c + Offset(w * 0.3, w * 0.12), c + Offset(w * 0.42, 0), s());
        break;
      case WeaponType.holy:
        canvas.drawCircle(c, w * 0.42, s()..strokeWidth = w / 12);
        canvas.drawLine(c - Offset(w * 0.18, 0), c + Offset(w * 0.18, 0), s());
        canvas.drawLine(c - Offset(0, w * 0.18), c + Offset(0, w * 0.18), s());
        break;
      case WeaponType.laser:
        canvas.drawLine(c - Offset(w * 0.42, 0), c + Offset(w * 0.42, 0), s()..strokeWidth = w / 6);
        canvas.drawLine(c - Offset(w * 0.42, 0), c + Offset(w * 0.42, 0), Paint()..color = Colors.white..strokeWidth = w / 20);
        break;
      case WeaponType.thorns:
        canvas.drawCircle(c, w * 0.28, s());
        for (int i = 0; i < 8; i++) {
          final a = i * 2 * math.pi / 8;
          canvas.drawLine(
              c + Offset(math.cos(a) * w * 0.26, math.sin(a) * w * 0.26),
              c + Offset(math.cos(a) * w * 0.46, math.sin(a) * w * 0.46),
              s());
        }
        break;
      case WeaponType.scythe:
        final handlePath = Path()
          ..moveTo(c.dx - w * 0.2, c.dy + w * 0.44)
          ..quadraticBezierTo(c.dx + w * 0.1, c.dy + w * 0.1, c.dx + w * 0.16, c.dy - w * 0.28);
        canvas.drawPath(handlePath, s()..strokeWidth = w / 12);
        final scytheBlade = Path()
          ..moveTo(c.dx + w * 0.16, c.dy - w * 0.28)
          ..arcToPoint(Offset(c.dx - w * 0.32, c.dy - w * 0.06), radius: Radius.circular(w * 0.44))
          ..quadraticBezierTo(c.dx - w * 0.24, c.dy + w * 0.08, c.dx + w * 0.06, c.dy - w * 0.04)
          ..close();
        canvas.drawPath(scytheBlade, f);
        break;
      case WeaponType.venom:
        final drop = Path()
          ..moveTo(c.dx, c.dy - w * 0.44)
          ..quadraticBezierTo(c.dx + w * 0.3, c.dy - w * 0.1, c.dx, c.dy + w * 0.4)
          ..quadraticBezierTo(c.dx - w * 0.3, c.dy - w * 0.1, c.dx, c.dy - w * 0.44);
        canvas.drawPath(drop, f);
        break;
      case WeaponType.gun:
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w * 0.62, height: w * 0.22),
                Radius.circular(w * 0.1)),
            f);
        canvas.drawLine(Offset(c.dx + w * 0.31, c.dy), Offset(c.dx + w * 0.45, c.dy),
            s()..strokeWidth = w / 10);
        break;
      case WeaponType.staff:
        canvas.drawLine(Offset(c.dx - w * 0.3, c.dy + w * 0.4), Offset(c.dx + w * 0.3, c.dy - w * 0.4),
            s()..strokeWidth = w / 10);
        for (int i = 0; i < 3; i++) {
          final a = i * 2 * math.pi / 3;
          canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * w * 0.3, s()..strokeWidth = w / 12);
        }
        break;
      case WeaponType.blade:
        final bladeP = Path()
          ..moveTo(c.dx, c.dy - w * 0.46)
          ..lineTo(c.dx + w * 0.16, c.dy)
          ..lineTo(c.dx, c.dy + w * 0.46)
          ..lineTo(c.dx - w * 0.16, c.dy)
          ..close();
        canvas.drawPath(bladeP, f);
        break;
      case WeaponType.sword:
        final crescent = Path()
          ..moveTo(c.dx - w * 0.42, c.dy)
          ..quadraticBezierTo(c.dx, c.dy - w * 0.38, c.dx + w * 0.42, c.dy)
          ..quadraticBezierTo(c.dx, c.dy + w * 0.18, c.dx - w * 0.42, c.dy);
        canvas.drawPath(crescent, f);
        break;
      case WeaponType.fists:
        canvas.drawCircle(c, w * 0.3, f);
        for (int i = 0; i < 4; i++) {
          final a = i * 2 * math.pi / 4;
          canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * w * 0.18, w * 0.08, f);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _WeaponIconPainter old) =>
      old.type != type || old.color != color;
}

// ============ 虚拟方向盘 ============
class JoystickOverlay extends StatelessWidget {
  final FixedJoy joy;
  final bool visible;
  const JoystickOverlay(this.joy, {super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(builder: (ctx, cons) {
        final center = Offset(cons.maxWidth / 2, cons.maxHeight - 135);
        joy.center = center;
        final knob = joy.active ? joy.stick : center;
        return CustomPaint(
          size: Size.infinite,
          painter: _JoyPainter(center, knob, joy.active),
        );
      }),
    );
  }
}

class _JoyPainter extends CustomPainter {
  final Offset center;
  final Offset knob;
  final bool active;
  _JoyPainter(this.center, this.knob, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(center, 90, Paint()..color = const Color(0x33222A3A));
    canvas.drawCircle(center, 90, Paint()
      ..color = const Color(0x77222A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
    if (active) {
      canvas.drawCircle(knob, 38, Paint()..color = const Color(0xAA42A5F5));
      canvas.drawCircle(knob, 38, Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
    } else {
      canvas.drawCircle(center, 26, Paint()..color = const Color(0x6642A5F5));
    }
  }

  @override
  bool shouldRepaint(covariant _JoyPainter old) =>
      old.center != center || old.knob != knob || old.active != active;
}

// ============ HUD ============
class Hud extends StatelessWidget {
  final GameState game;
  final VoidCallback onPause;
  final VoidCallback onToggleSound;
  final bool soundOn;
  const Hud(this.game,
      {super.key, required this.onPause, required this.onToggleSound, required this.soundOn});

  @override
  Widget build(BuildContext context) {
    final p = game.player;
    final hpR = (p.hp / p.maxHp).clamp(0.0, 1.0);
    final xpR = (p.xp / p.xpNeed).clamp(0.0, 1.0);
    Monster? boss;
    for (final m in game.monsters) {
      if (m.isBoss) {
        boss = m;
        break;
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(children: [
          Positioned(
            top: 92,
            left: 0,
            right: 0,
            child: Center(
              child: boss != null ? _bossBar(boss, context) : _bossCountdown(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xCC1A1E29),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF42A5F5), width: 1.5),
                  boxShadow: const [BoxShadow(color: Color(0x6642A5F5), blurRadius: 8)],
                ),
                child: Text('Lv.${p.level}',
                    style: const TextStyle(color: Color(0xFF90CAF9), fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 3),
              _bar(hpR, const Color(0xFFEF5350), width: 160, label: 'HP ${p.hp.round()}/${p.maxHp.round()}'),
              const SizedBox(height: 3),
              _bar(xpR, const Color(0xFF42A5F5), width: 160, label: 'EXP ${p.xp.round()}/${p.xpNeed}'),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.monetization_on, size: 13, color: Color(0xFFFFC400)),
                const SizedBox(width: 3),
                Text('${game.gold.round()}',
                    style: const TextStyle(color: Color(0xFFFFC400), fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Column(children: [
                Text(fmtTime(game.time),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                Text('击杀 ${game.kills}',
                    style: const TextStyle(
                        color: Color(0xFFB0BEC5), fontSize: 13, fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
              ]),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _skillsButton(context),
              const SizedBox(height: 6),
              _statusButton(context),
            ]),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: IconButton(
              onPressed: onPause,
              icon: const Icon(Icons.pause, color: Colors.white),
              iconSize: 26,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xCC2A1A4A),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF7E57C2)),
                shadowColor: const Color(0xFF7E57C2),
                elevation: 6,
                padding: const EdgeInsets.all(12),
              ),
              tooltip: '暂停',
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: IconButton(
              onPressed: onToggleSound,
              icon: Icon(soundOn ? Icons.volume_up : Icons.volume_off,
                  color: soundOn ? const Color(0xFF80CBC4) : const Color(0xFF9E9E9E)),
              iconSize: 24,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xCC2A1A4A),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF00897B)),
              ),
              tooltip: '声音',
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bar(double ratio, Color color, {required double width, required String label}) {
    return SizedBox(
      width: width,
      height: 20,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0x661A1E29),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.black45),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.55)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 2)])),
      ]),
    );
  }

  Widget _skillsButton(BuildContext context) {
    final count = game.player.weapons.length + game.player.passives.length;
    return GestureDetector(
      onTap: () => _showSkills(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC1A1E29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF7E57C2), width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFB39DDB)),
          const SizedBox(width: 4),
          Text('技能 ×$count',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Future<void> _showSkills(BuildContext context) async {
    game.frozen = true;
    await showSkillsDialog(context, game);
    game.frozen = false;
  }

  Widget _statusButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStatus(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC1A1E29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00897B), width: 1.5),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.monitor_heart, size: 16, color: Color(0xFF80CBC4)),
          SizedBox(width: 4),
          Text('状态', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Future<void> _showStatus(BuildContext context) async {
    game.frozen = true;
    await showStatusDialog(context, game);
    game.frozen = false;
  }

  String _nextBossName() {
    const kinds = [MonsterKind.golem, MonsterKind.wolf, MonsterKind.ghost];
    return monsterDefs[kinds[game.bossCount % kinds.length]]!.name;
  }

  Widget _bossCountdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1E29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66EF5350)),
      ),
      child: Text('下波 BOSS ${_nextBossName()}  ${fmtTime(game.bossTimer)}',
          style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _bossBar(Monster m, BuildContext context) {
    final ratio = (m.hp / m.maxHp).clamp(0.0, 1.0);
    final warning = m.skillWarn > 0;
    final skills = bossSkills[m.kind] ?? const [];
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x22141020), // 透明悬浮
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: warning ? const Color(0x88FF1744) : const Color(0x55FF5252),
            width: warning ? 2 : 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('BOSS #${game.bossCount} ${monsterDefs[m.kind]!.name}  ${(ratio * 100).round()}%',
            style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.bold)),
        Text('${m.hp.round()} / ${m.maxHp.round()}',
            style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 8,
            child: Stack(children: [
              Container(color: const Color(0x66000000)),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio,
                  heightFactor: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFFF8A80)]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        if (warning)
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text('⚠ 技能蓄力中，快躲开！',
                style: TextStyle(color: Color(0xFFFF5252), fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        // 技能列表（点击查看详情）
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in skills) ...[
              GestureDetector(
                onTap: () => _showSkillDetail(context, s),
                child: Container(
                  margin: const EdgeInsets.only(left: 4, top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x66EF5350),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x88FF5252)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 2),
                    const Icon(Icons.info_outline, size: 9, color: Color(0x99FFFFFF)),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ]),
    );
  }

  void _showSkillDetail(BuildContext context, BossSkillDef s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(s.name, style: const TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.bold)),
        content: Text(s.desc, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了', style: TextStyle(color: Color(0xFF90CAF9))),
          ),
        ],
      ),
    );
  }
}

// ============ 升级三选一 ============
class UpgradePanel extends StatelessWidget {
  final GameState game;
  final ValueChanged<UpgradeChoice> onPick;
  const UpgradePanel(this.game, {super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('等级提升！',
              style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Color(0xFF42A5F5), blurRadius: 12)])),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, c) in game.pendingChoices.indexed) ...[
                if (i > 0) const SizedBox(width: 16),
                _choiceCard(c),
              ],
            ],
          ),
        ]),
      ),
    );
  }

  Widget _choiceCard(UpgradeChoice c) {
    final r = c.rarity();
    final rc = kRarityColors[r];
    final rn = kRarityNames[r];
    return Expanded(
      child: GestureDetector(
        onTap: () => onPick(c),
        child: Container(
          height: 172,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: rc, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF151A26), Color(0xFF1C2230)],
            ),
            boxShadow: [BoxShadow(color: rc.withValues(alpha: 0.3), blurRadius: 12)],
          ),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: rc.withValues(alpha: 0.25),
                border: Border(bottom: BorderSide(color: rc.withValues(alpha: 0.6))),
              ),
              child: Text(rn,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: rc, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(c.title(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  if (c.kind == ChoiceKind.weapon && c.level == weaponDefs[c.weapon!]!.maxLevel) ...[
                    const SizedBox(height: 4),
                    Text('★ 满级觉醒',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: rc, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 6),
                  Text(c.description(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============ 暂停 ============
class PausePanel extends StatelessWidget {
  final GameState game;
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final VoidCallback onAdItem;
  final VoidCallback onSkills;
  final VoidCallback onStatus;
  const PausePanel(this.game,
      {super.key, required this.onResume, required this.onRetry, required this.onMenu, required this.onAdItem, required this.onSkills, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    return _scrim(Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('已暂停', style: _bigTitle),
      const SizedBox(height: 10),
      Text('存活 ${fmtTime(game.time)} · Lv.${game.player.level} · 击杀 ${game.kills}',
          style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 15)),
      const SizedBox(height: 24),
      _btn('继续游戏', () => onResume()),
      const SizedBox(height: 10),
      _btn('重新开始', () => onRetry(), dark: true),
      const SizedBox(height: 10),
      _adBtn('看广告 · 获得随机道具', () => onAdItem()),
      const SizedBox(height: 10),
      _btn('查看技能', () => onSkills(), dark: true),
      const SizedBox(height: 10),
      _btn('查看状态', () => onStatus(), dark: true),
      const SizedBox(height: 10),
      _btn('返回主菜单', () => onMenu(), dark: true),
    ]));
  }
}

// ============ 结束 ============
class GameOverPanel extends StatelessWidget {
  final GameState game;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final VoidCallback onRevive;
  const GameOverPanel(this.game,
      {super.key, required this.onRetry, required this.onMenu, required this.onRevive});

  @override
  Widget build(BuildContext context) {
    final m = game.meta;
    return _scrim(Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('你死了', style: TextStyle(color: Color(0xFFFF5252), fontSize: 40, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('存活 ${fmtTime(game.time)}', style: const TextStyle(color: Colors.white, fontSize: 18)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x661A1E29),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x55222A3A)),
        ),
        child: Column(children: [
          _row('击杀', '${game.kills}'),
          _row('达到等级', 'Lv.${game.player.level}'),
          _row('本局金币', '+${game.gold.round()}'),
          _row('最佳等级', 'Lv.${m.bestLevel}'),
          _row('最佳存活', fmtTime(m.bestTime)),
        ]),
      ),
      const SizedBox(height: 20),
      if (game.reviveLeft > 0) ...[
        _adBtn('看广告 · 复活（剩 ${game.reviveLeft} 次）', () => onRevive()),
        const SizedBox(height: 10),
      ],
      _btn('再来一局', () => onRetry()),
      const SizedBox(height: 10),
      _btn('返回主菜单', () => onMenu(), dark: true),
    ]));
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$k  ', style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 14)),
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
      );
}

// ============ 主菜单 ============
class MenuPanel extends StatelessWidget {
  final GameState game;
  final VoidCallback onStart;
  final VoidCallback onContinue;
  final ValueChanged<int> onBuyMeta;
  final VoidCallback onAdCoins;
  final VoidCallback onMonthlyCard;
  final ValueChanged<int> onBuySkin;
  final ValueChanged<int> onSelectSkin;
  const MenuPanel(this.game,
      {super.key, required this.onStart, required this.onContinue, required this.onBuyMeta, required this.onAdCoins, required this.onMonthlyCard, required this.onBuySkin, required this.onSelectSkin});

  void _showSkillBook(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141824),
        title: const Text('技能图鉴', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('— 武器 —', style: TextStyle(color: Color(0xFF90CAF9), fontWeight: FontWeight.bold)),
              for (final w in WeaponType.values)
                _skillCard(WeaponIcon(w, color: weaponDefs[w]!.color, size: 26),
                    weaponDefs[w]!.name, weaponDefs[w]!.desc, weaponDefs[w]!.rarity,
                    () => _showSkillDetail(ctx, weapon: w)),
              const SizedBox(height: 12),
              const Text('— 被动 —', style: TextStyle(color: Color(0xFF90CAF9), fontWeight: FontWeight.bold)),
              for (final p in PassiveType.values)
                _skillCard(_passiveIcon(p, passiveDefs[p]!.rarity),
                    passiveDefs[p]!.name, passiveDefs[p]!.desc, passiveDefs[p]!.rarity,
                    () => _showSkillDetail(ctx, passive: p)),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭', style: TextStyle(color: Color(0xFF90CAF9))),
          ),
        ],
      ),
    );
  }

  void _showSkillDetail(BuildContext context, {WeaponType? weapon, PassiveType? passive}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141824),
        content: _SkillDetailView(weapon: weapon, passive: passive),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭', style: TextStyle(color: Color(0xFF90CAF9))),
          ),
        ],
      ),
    );
  }

  Widget _skillCard(Widget icon, String name, String desc, int rarity, VoidCallback onTap) {
    final rc = kRarityColors[rarity];
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x661A1E29),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: rc.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text(kRarityNames[rarity], style: TextStyle(color: rc, fontSize: 10)),
              ]),
              Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF78909C), fontSize: 11)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF546E7A), size: 18),
        ]),
      ),
    );
  }

  Widget _passiveIcon(PassiveType p, int rarity, {double size = 24}) {
    final rc = kRarityColors[rarity];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: rc.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: rc),
      ),
      child: Icon(Icons.auto_awesome, size: size * 0.55, color: Colors.white),
    );
  }

  // 看广告金币阶梯收益：每看 3 次升一档
  int _adReward() {
    final step = (game.meta.adsWatched ~/ 3) > 9 ? 9 : (game.meta.adsWatched ~/ 3);
    return kAdCoinsBase * (1 + step);
  }

  Widget _monthlyCard() {
    final on = game.meta.monthlyCard;
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x0DFFD54F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: on ? const Color(0xFFFFD54F) : const Color(0x44FFD54F), width: 1.5),
      ),
      child: Row(children: [
        const Icon(Icons.workspace_premium, color: Color(0xFFFFD54F), size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('月卡 ¥$kMonthlyCardPrice',
                style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 14, fontWeight: FontWeight.bold)),
            Text(on ? '已开通：每局复活 $kMonthlyRevives 次'
                    : '每局复活 $kMonthlyRevives 次（普通 $kRevivePerRun 次）',
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11)),
          ]),
        ),
        if (!on)
          SizedBox(
            height: 34,
            child: FilledButton(
              onPressed: onMonthlyCard,
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black),
              child: const Text('开通', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        else
          const Text('已开通', style: TextStyle(color: Color(0xFF66BB6A), fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _showSkins(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141824),
        title: const Text('皮肤', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(children: [
              for (int i = 0; i < skins.length; i++) _skinRow(ctx, i),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭', style: TextStyle(color: Color(0xFF90CAF9))),
          ),
        ],
      ),
    );
  }

  Widget _skinRow(BuildContext ctx, int i) {
    final s = skins[i];
    final owned = game.meta.ownedSkins.contains(i);
    final selected = game.meta.selectedSkin == i;
    final canBuy = game.meta.gold >= s.cost;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x661A1E29),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected ? const Color(0xFF42A5F5) : const Color(0x22222A3A),
            width: selected ? 2 : 1),
      ),
      child: Row(children: [
        Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
                color: s.color, shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 2))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            Text(s.desc, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
          ]),
        ),
        if (selected)
          const Text('使用中', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontWeight: FontWeight.bold))
        else if (owned)
          SizedBox(
            height: 32,
            child: FilledButton(
              onPressed: () {
                onSelectSkin(i);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF42A5F5)),
              child: const Text('使用'),
            ),
          )
        else
          SizedBox(
            height: 32,
            child: FilledButton(
              onPressed: canBuy
                  ? () {
                      onBuySkin(i);
                      Navigator.pop(ctx);
                    }
                  : null,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC400), foregroundColor: Colors.black),
              child: Text('${s.cost}金'),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = game.meta;
    return Container(
      color: const Color(0xEE0B0E14),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFB39DDB), Color(0xFFE1BEE7), Color(0xFF9575CD)],
            ).createShader(bounds),
            child: const Text('球球进化',
                style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Color(0xFF7E57C2), blurRadius: 18)])),
          ),
          const Text('打怪 · 升级 · 变强', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 16)),
          const SizedBox(height: 8),
          Text('最佳 Lv.${m.bestLevel} · 最佳 ${fmtTime(m.bestTime)}',
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14)),
          const SizedBox(height: 24),
          _btn('新游戏', () => onStart()),
          if (game.hasRun()) ...[
            const SizedBox(height: 10),
            _btn('继续上次存档', () => onContinue(), dark: true),
          ],
          const SizedBox(height: 10),
          _adBtn('看广告 · 获得金币 +${_adReward()}', () => onAdCoins()),
          const SizedBox(height: 10),
          _btn('技能图鉴', () => _showSkillBook(context), dark: true),
          const SizedBox(height: 10),
          _btn('皮肤', () => _showSkins(context), dark: true),
          const SizedBox(height: 20),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.monetization_on, size: 16, color: Color(0xFFFFC400)),
            const SizedBox(width: 4),
            Text('金币 ${m.gold.round()}',
                style: const TextStyle(color: Color(0xFFFFC400), fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          _btn('强化祝福（金币）', () => _showMetaUpgrades(context), dark: true),
          const SizedBox(height: 16),
          _monthlyCard(),
        ]),
      ),
    );
  }

  void _showMetaUpgrades(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141824),
        title: const Text('强化祝福', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: _MetaUpgradesView(game, onBuyMeta: onBuyMeta)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭', style: TextStyle(color: Color(0xFF90CAF9))),
          ),
        ],
      ),
    );
  }
}

// 强化祝福弹窗（6 项元养成，金币购买，可即时刷新）
class _MetaUpgradesView extends StatefulWidget {
  final GameState game;
  final ValueChanged<int> onBuyMeta;
  const _MetaUpgradesView(this.game, {required this.onBuyMeta});
  @override
  State<_MetaUpgradesView> createState() => _MetaUpgradesViewState();
}

class _MetaUpgradesViewState extends State<_MetaUpgradesView> {
  @override
  Widget build(BuildContext context) {
    final m = widget.game.meta;
    return SizedBox(
      width: 340,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.monetization_on, size: 16, color: Color(0xFFFFC400)),
          const SizedBox(width: 4),
          Text('金币 ${m.gold.round()}',
              style: const TextStyle(color: Color(0xFFFFC400), fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        for (int i = 0; i < metaUpgrades.length; i++) ...[
          _row(i),
          if (i < metaUpgrades.length - 1) const SizedBox(height: 8),
        ],
      ]),
    );
  }

  Widget _row(int i) {
    final bought = widget.game.meta.metaBought[i];
    final cost = metaCost(i, bought);
    final canBuy = widget.game.meta.gold >= cost;
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x661A1E29),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: canBuy ? const Color(0x55FFD54F) : const Color(0x22222A3A)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${metaUpgrades[i].name} ×$bought',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            Text(metaUpgrades[i].desc, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
          ]),
        ),
        SizedBox(
          height: 32,
          child: FilledButton(
            onPressed: canBuy
                ? () {
                    widget.onBuyMeta(i);
                    setState(() {});
                  }
                : null,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC400), foregroundColor: Colors.black),
            child: Text('$cost金'),
          ),
        ),
      ]),
    );
  }
}

// 我的技能 / 玩家状态 对话框（可互相切换，暂停时也能打开）
Widget weaponChipWidget(WeaponType type, int lv) {
  final name = weaponDefs[type]!.name;
  final color = weaponDefs[type]!.color;
  return Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xAA1A1E29),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.7)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      WeaponIcon(type, color: color, size: 15),
      const SizedBox(width: 5),
      Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(width: 5),
      Text(lv >= 10 ? 'MAX★' : 'Lv.$lv',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ]),
  );
}

Widget passiveChipWidget(PassiveType type, int lv) {
  return Container(
    margin: const EdgeInsets.only(bottom: 3),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0x881A1E29),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0x4490A4AE)),
    ),
    child: Text('${passiveDefs[type]!.name} Lv.$lv',
        style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11)),
  );
}

Future<void> showSkillsDialog(BuildContext context, GameState game) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF141824),
      title: const Text('我的技能', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final e in game.player.weapons.entries) weaponChipWidget(e.key, e.value),
            if (game.player.passives.isNotEmpty) const SizedBox(height: 6),
            for (final e in game.player.passives.entries) passiveChipWidget(e.key, e.value),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            showStatusDialog(context, game);
          },
          child: const Text('查看状态', style: TextStyle(color: Color(0xFF80CBC4))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('关闭', style: TextStyle(color: Color(0xFF90CAF9))),
        ),
      ],
    ),
  );
}

Future<void> showStatusDialog(BuildContext context, GameState game) async {
  final p = game.player;
  final rows = <(String, String)>[
    ('等级', 'Lv.${p.level}'),
    ('生命', '${p.hp.round()} / ${p.maxHp.round()}'),
    ('攻击倍率', '×${p.damageMult().toStringAsFixed(2)}'),
    ('移动速度', '${p.moveSpeed().round()}'),
    ('攻速', '${((1 - p.hasteMult()) * 100).round()}%'),
    ('暴击率', '${(p.critChance() * 100).round()}%'),
    ('暴击伤害', '×${(kCritMult + 0.3 * p.passiveLevel(PassiveType.critDmg)).toStringAsFixed(1)}'),
    ('吸血', '${(p.lifesteal() * 100).round()}%'),
    ('闪避', '${5 * p.passiveLevel(PassiveType.evade)}%'),
    ('拾取范围', '${p.magnetRange().round()}'),
    ('经验加成', '+${((p.xpMult() - 1) * 100).round()}%'),
    ('金币加成', '+${20 * p.passiveLevel(PassiveType.wealth)}%'),
    ('生命回复', '最大生命×${(1.5 * p.passiveLevel(PassiveType.regen)).toStringAsFixed(1)}%/秒'),
  ];
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF141824),
      title: const Text('玩家状态', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Text(k, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
                  const Spacer(),
                  Text(v, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            showSkillsDialog(context, game);
          },
          child: const Text('查看技能', style: TextStyle(color: Color(0xFFB39DDB))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('关闭', style: TextStyle(color: Color(0xFF90CAF9))),
        ),
      ],
    ),
  );
}

// 被动在某等级的总增幅（图鉴详情）
String passiveBonusInfo(PassiveType pt, int lv) => switch (pt) {
      PassiveType.hp => '生命上限 +5%×$lv（按当前）',
      PassiveType.speed => '移动速度 +${8 * lv}%',
      PassiveType.power => '伤害 +${15 * lv}%',
      PassiveType.haste => '攻速 -${8 * lv}%',
      PassiveType.crit => '暴击率 +${8 * lv}%',
      PassiveType.lifesteal => '吸血 +${3 * lv}%',
      PassiveType.magnet => '拾取范围 +${30 * lv}% · 经验 +${10 * lv}%',
      PassiveType.regen => '每秒回血 最大生命×${1.5 * lv}%',
      PassiveType.wealth => '金币 +${20 * lv}%',
      PassiveType.area => '范围 +${10 * lv}%',
      PassiveType.evade => '闪避 +${5 * lv}%',
      PassiveType.critDmg => '暴伤 +${30 * lv}%',
      PassiveType.stun => '眩晕 +${6 * lv}%',
      PassiveType.explode => '爆炸 +${10 * lv}伤害',
    };

// 武器在某等级的关键属性（图鉴详情）
List<(String, String)> weaponStats(WeaponType w, int lv) {
  switch (w) {
    case WeaponType.bolt:
      final p = boltParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('间隔', '${p.interval.toStringAsFixed(2)}s'), ('弹数', '${p.count}'), ('穿透', '${p.pierce}')];
    case WeaponType.orbit:
      final p = orbitParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('剑数', '${p.count}'), ('半径', '${p.radius.round()}')];
    case WeaponType.axe:
      final p = axeParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('半径', '${p.radius.round()}'), ('间隔', '${p.interval.toStringAsFixed(2)}s')];
    case WeaponType.lightning:
      final p = lightningParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('范围', '${p.range.round()}'), ('链数', '${p.chains}')];
    case WeaponType.aura:
      final p = auraParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(1)), ('半径', '${p.radius.round()}')];
    case WeaponType.frost:
      final p = frostParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('半径', '${p.radius.round()}'), ('间隔', '${p.interval.toStringAsFixed(1)}s')];
    case WeaponType.homing:
      final p = homingParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('弹数', '${p.count}')];
    case WeaponType.holy:
      final p = holyParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('半径', '${p.radius.round()}')];
    case WeaponType.laser:
      final p = laserParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('长度', '${p.length.round()}'), ('宽度', '${p.width.round()}')];
    case WeaponType.thorns:
      final p = thornsParam(lv);
      return [('反伤', p.dmg.toStringAsFixed(0)), ('范围', '${p.range.round()}')];
    case WeaponType.scythe:
      final p = scytheParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('半径', '${p.radius.round()}'), ('次数', '${p.hits}')];
    case WeaponType.venom:
      final p = venomParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(1)), ('半径', '${p.radius.round()}'), ('持续', '${p.duration.toStringAsFixed(1)}s')];
    case WeaponType.gun:
      final p = gunParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('间隔', '${p.interval.toStringAsFixed(2)}s')];
    case WeaponType.staff:
      final p = staffParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('半径', '${p.radius.round()}'), ('间隔', '${p.interval.toStringAsFixed(1)}s')];
    case WeaponType.blade:
      final p = bladeParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('数量', '${p.count}'), ('射程', '${p.range.round()}')];
    case WeaponType.sword:
      final p = swordParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('波数', '${p.waves}')];
    case WeaponType.fists:
      final p = fistsParam(lv);
      return [('伤害', p.dmg.toStringAsFixed(0)), ('半径', '${p.radius.round()}'), ('间隔', '${p.interval.toStringAsFixed(2)}s')];
  }
}

// 技能图鉴详情视图（等级步进器展示每一级属性）
class _SkillDetailView extends StatefulWidget {
  final WeaponType? weapon;
  final PassiveType? passive;
  const _SkillDetailView({this.weapon, this.passive});
  @override
  State<_SkillDetailView> createState() => _SkillDetailViewState();
}

class _SkillDetailViewState extends State<_SkillDetailView> {
  int lv = 1;

  @override
  Widget build(BuildContext context) {
    final w = widget.weapon;
    final p = widget.passive;
    final name = w != null ? weaponDefs[w]!.name : passiveDefs[p!]!.name;
    final rarity = w != null ? weaponDefs[w]!.rarity : passiveDefs[p]!.rarity;
    final rc = kRarityColors[rarity];
    final desc = w != null ? weaponDefs[w]!.desc : passiveDefs[p]!.desc;
    final maxLv = w != null ? weaponDefs[w]!.maxLevel : 10;
    return SizedBox(
      width: 320,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (w != null)
            WeaponIcon(w, color: weaponDefs[w]!.color, size: 40)
          else
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: rc.withValues(alpha: 0.25), shape: BoxShape.circle,
                border: Border.all(color: rc)),
              child: const Icon(Icons.auto_awesome, size: 22, color: Colors.white),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Text(kRarityNames[rarity], style: TextStyle(color: rc, fontSize: 12)),
              ]),
              Text('Lv.$lv', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
            onPressed: lv > 1 ? () => setState(() => lv--) : null),
          Text('$lv', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: lv < maxLv ? () => setState(() => lv++) : null),
        ]),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0x661A1E29), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(desc, style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12)),
            const SizedBox(height: 8),
            if (w != null)
              for (final (k, v) in weaponStats(w, lv))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Text(k, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
                    const Spacer(),
                    Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                )
            else
              Text('当前增幅：${passiveBonusInfo(p!, lv)}',
                  style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

// ============ 通用 ============
const TextStyle _bigTitle = TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold);

Widget _scrim(Widget child) {
  return Container(
    color: Colors.black.withValues(alpha: 0.72),
    alignment: Alignment.center,
    child: child,
  );
}

Widget _btn(String text, VoidCallback onTap, {bool dark = false}) {
  return SizedBox(
    width: 240,
    height: 48,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF2A3040), Color(0xFF1E2430)]
              : const [Color(0xFF9C6BFF), Color(0xFF7E57C2)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: (dark ? const Color(0xFF000000) : const Color(0xFF7E57C2))
                .withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ),
  );
}

// 广告奖励按钮（金色，用于复活/金币/道具等激励入口）
Widget _adBtn(String text, VoidCallback onTap) {
  return SizedBox(
    width: 240,
    height: 48,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF8F00)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x66FFB300), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(text,
                style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ),
  );
}
