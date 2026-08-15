import 'dart:math';
import 'package:flutter/material.dart';
import 'config.dart';
import 'state.dart';

class GamePainter extends CustomPainter {
  final GameState game;

  GamePainter(this.game) : super(repaint: null);

  // 相机缩放：<1 显示更大范围
  static const double kZoom = 0.78;

  @override
  void paint(Canvas canvas, Size size) {
    game.viewW = size.width;
    game.viewH = size.height;
    final cx = size.width / 2, cy = size.height / 2;

    canvas.save();
    if (game.shake > 0) {
      final s = game.shake;
      canvas.translate(sin(game.time * 70) * s * 0.3, cos(game.time * 60) * s * 0.3);
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0B0E14));
    // 先平移到屏幕中心，再缩放，再减去世界坐标 → 玩家始终在屏幕正中
    canvas.translate(cx, cy);
    canvas.scale(kZoom);
    canvas.translate(-game.player.x, -game.player.y);
    _bgWorld(canvas, size);
    _drawAura(canvas);
    _drawVenom(canvas);
    _drawPickups(canvas);
    _drawMonsters(canvas);
    _drawPlayer(canvas);
    _drawThorns(canvas);
    _drawOrbit(canvas);
    _drawProjectiles(canvas);
    _drawLaser(canvas);
    _drawLightning(canvas);
    _drawAxeFx(canvas);
    _drawStaffFx(canvas);
    _drawFistFx(canvas);
    _drawHolyFlash(canvas);
    _drawParticles(canvas);
    _drawTexts(canvas);
    canvas.restore();

    _drawScreenFx(canvas, size);
  }

  // ---------- 世界背景（网格 + 装饰） ----------
  void _bgWorld(Canvas canvas, Size size) {
    const int cell = 64;
    final p = game.player;
    final halfW = size.width / 2 / kZoom, halfH = size.height / 2 / kZoom;
    final x0 = (p.x - halfW), y0 = (p.y - halfH);
    final x1 = (p.x + halfW), y1 = (p.y + halfH);
    final gx0 = (x0 / cell).floor() * cell.toDouble();
    final gy0 = (y0 / cell).floor() * cell.toDouble();
    final gx1 = (x1 / cell).ceil() * cell.toDouble();
    final gy1 = (y1 / cell).ceil() * cell.toDouble();
    for (double gx = gx0; gx <= gx1; gx += cell.toDouble()) {
      for (double gy = gy0; gy <= gy1; gy += cell.toDouble()) {
        if (((gx / cell).round() + (gy / cell).round()) % 2 != 0) continue;
        final r = Rect.fromLTRB(gx, gy, gx + cell, gy + cell);
        canvas.drawRect(r, Paint()..color = const Color(0xFF10141D));
        _decor(canvas, gx, gy);
      }
    }
    final linePaint = Paint()
      ..color = const Color(0x141F2A3A)
      ..strokeWidth = 1;
    for (double gx = gx0; gx <= gx1; gx += cell) {
      canvas.drawLine(Offset(gx, y0), Offset(gx, y1), linePaint);
    }
    for (double gy = gy0; gy <= gy1; gy += cell) {
      canvas.drawLine(Offset(x0, gy), Offset(x1, gy), linePaint);
    }
  }

  // 确定性装饰：草丛 / 石头 / 树，随格子哈希生成
  void _decor(Canvas canvas, double gx, double gy) {
    final ci = gx ~/ 64, cj = gy ~/ 64;
    final h = _hash(ci, cj);
    final hx = _hash(ci + 7, cj), hy = _hash(ci, cj + 13);
    final base = Offset(gx + 16 + hx * 32, gy + 16 + hy * 32);
    if (h < 0.3) {
      final p = Paint()
        ..color = const Color(0xFF27401F)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 3; i++) {
        final a = -pi / 2 + (h * 3 + i) * 0.5 - 0.5;
        canvas.drawLine(base, base + Offset(cos(a) * 8, sin(a) * 8), p);
      }
    } else if (h < 0.4) {
      canvas.drawCircle(base + const Offset(8, 6), 7, Paint()..color = const Color(0xFF2A2F36));
      canvas.drawCircle(base + const Offset(-6, 2), 5, Paint()..color = const Color(0xFF23272E));
    } else if (h < 0.46) {
      canvas.drawLine(base + const Offset(0, 6), base + const Offset(0, 16),
          Paint()..color = const Color(0xFF3E2F1D)..strokeWidth = 4);
      canvas.drawCircle(base, 13, Paint()..color = const Color(0xFF1E3A28));
      canvas.drawCircle(base + const Offset(-4, -3), 8, Paint()..color = const Color(0xFF24482F));
    }
  }

  double _hash(int a, int b) {
    var h = a * 374761393 + b * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return ((h ^ (h >> 16)) & 0x7fffffff) / 0x7fffffff;
  }

  bool _onScreen(double x, double y) {
    final hw = game.viewW / 2 + 80, hh = game.viewH / 2 + 80;
    return (x - game.player.x).abs() <= hw && (y - game.player.y).abs() <= hh;
  }

  // ---------- 光环 ----------
  void _drawAura(Canvas canvas) {
    if (game.player.weaponLevel(WeaponType.aura) <= 0) return;
    final p = auraParam(game.player.weaponLevel(WeaponType.aura));
    final pulse = 0.92 + 0.08 * sin(game.time * 5);
    final r = p.radius * game.areaMult() * pulse;
    canvas.drawCircle(
        Offset(game.player.x, game.player.y), r,
        Paint()..color = const Color(0x1AFF7043));
    canvas.drawCircle(
        Offset(game.player.x, game.player.y), r,
        Paint()
          ..color = const Color(0x33FF7043)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawCircle(
        Offset(game.player.x, game.player.y), r * 1.15,
        Paint()
          ..color = const Color(0x22FF7043)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  // ---------- 毒圈 ----------
  void _drawVenom(Canvas canvas) {
    for (final z in game.venomZones) {
      if (!_onScreen(z.x, z.y)) continue;
      final o = Offset(z.x, z.y);
      final pulse = 0.9 + 0.1 * sin(game.time * 6 + z.x);
      canvas.drawCircle(o, z.radius * pulse, Paint()..color = const Color(0x229CCC65));
      canvas.drawCircle(o, z.radius * pulse, Paint()
        ..color = const Color(0x66C5E1A5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  // ---------- 拾取物 ----------
  void _drawPickups(Canvas canvas) {
    for (final pk in game.pickups) {
      if (!_onScreen(pk.x, pk.y)) continue;
      final o = Offset(pk.x, pk.y);
      final pulse = 0.8 + 0.2 * sin(game.time * 5 + pk.x);
      switch (pk.kind) {
        case 'xp':
          final p2 = 0.75 + 0.25 * sin(game.time * 6 + pk.x);
          canvas.drawCircle(o, kGemRadius * (1.6 * p2), Paint()..color = const Color(0x22AEE0FF));
          final path = Path()
            ..moveTo(pk.x, pk.y - kGemRadius)
            ..lineTo(pk.x + kGemRadius * 0.7, pk.y)
            ..lineTo(pk.x, pk.y + kGemRadius)
            ..lineTo(pk.x - kGemRadius * 0.7, pk.y)
            ..close();
          canvas.drawPath(path, Paint()..color = const Color(0xFF4FC3F7));
          break;
        case 'gold':
          canvas.drawCircle(o, kGoldRadius * 2.2 * pulse, Paint()..color = const Color(0x33FFD54F));
          canvas.drawCircle(o, kGoldRadius, Paint()..color = const Color(0xFFFFC400));
          canvas.drawCircle(o, kGoldRadius * 0.4, Paint()..color = const Color(0xFFFFF176));
          break;
        case 'heart':
          canvas.drawCircle(o, kHeartRadius * 2.2 * pulse, Paint()..color = const Color(0x33EF5350));
          canvas.drawPath(_heartPath(pk.x, pk.y, kHeartRadius), Paint()..color = const Color(0xFFEF5350));
          break;
        case 'shield':
          canvas.drawCircle(o, kHeartRadius * 2.6 * pulse, Paint()..color = const Color(0x4464B5F6));
          canvas.drawCircle(o, kHeartRadius, Paint()
            ..color = const Color(0xFF64B5F6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
          break;
        case 'power':
          canvas.drawCircle(o, kHeartRadius * 2.6 * pulse, Paint()..color = const Color(0x44FF8A65));
          final blade = Path()
            ..moveTo(o.dx, o.dy - kHeartRadius)
            ..lineTo(o.dx + kHeartRadius * 0.5, o.dy + kHeartRadius)
            ..lineTo(o.dx, o.dy + kHeartRadius * 0.6)
            ..lineTo(o.dx - kHeartRadius * 0.5, o.dy + kHeartRadius)
            ..close();
          canvas.drawPath(blade, Paint()..color = const Color(0xFFFF8A65));
          break;
        case 'haste':
          canvas.drawCircle(o, kHeartRadius * 2.6 * pulse, Paint()..color = const Color(0x44FFD54F));
          canvas.drawCircle(o, kHeartRadius * 0.7, Paint()..color = const Color(0xFFFFD54F));
          canvas.drawLine(o + Offset(-kHeartRadius * 0.9, -kHeartRadius), o + Offset(-kHeartRadius * 0.9, kHeartRadius), Paint()..color = const Color(0xFFFFD54F)..strokeWidth = 2);
          canvas.drawLine(o + Offset(-kHeartRadius * 1.5, -kHeartRadius), o + Offset(-kHeartRadius * 1.5, kHeartRadius), Paint()..color = const Color(0x88FFD54F)..strokeWidth = 2);
          break;
      }
      if (_pickupName(pk.kind).isNotEmpty) {
        _text(canvas, _pickupName(pk.kind), Offset(pk.x, pk.y - 18), 12,
            const Color(0xFFE0E0E0), stroke: const Color(0xAA000000));
      }
    }
  }

  String _pickupName(String kind) => switch (kind) {
        'shield' => '护盾',
        'power' => '爆发',
        'haste' => '疾风',
        _ => '',
      };

  Path _heartPath(double x, double y, double r) {
    final p = Path();
    final top = y - r * 0.8;
    p.moveTo(x, top + r * 0.5);
    p.cubicTo(x - r * 1.2, top - r * 0.2, x - r * 0.3, top - r * 1.4, x, top - r * 0.4);
    p.cubicTo(x + r * 0.3, top - r * 1.4, x + r * 1.2, top - r * 0.2, x, top + r * 0.5);
    return p;
  }

  // ---------- 怪物 ----------
  void _drawMonsters(Canvas canvas) {
    for (final m in game.monsters) {
      if (!_onScreen(m.x, m.y)) continue;
      final o = Offset(m.x, m.y);
      final wob = sin(m.wobble) * (m.isBoss ? 1.5 : 1.0);
      var base = m.color;
      if (m.hitTimer > 0) base = Color.lerp(base, Colors.white, 0.7)!;
      canvas.drawCircle(o, m.radius + wob, Paint()..color = base.withValues(alpha: 0.92));
      canvas.drawCircle(o, m.radius + wob, Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      final ang = atan2(game.player.y - m.y, game.player.x - m.x);
      final ex = cos(ang), ey = sin(ang);
      canvas.drawCircle(o + Offset(ex * m.radius * 0.35, ey * m.radius * 0.35 - m.radius * 0.15), m.radius * 0.2, Paint()..color = Colors.white);
      canvas.drawCircle(o + Offset(ex * m.radius * 0.62, ey * m.radius * 0.62 - m.radius * 0.15), m.radius * 0.12, Paint()..color = const Color(0xFF0B0E14));
      // 冰冻染
      if (m.slow > 0) {
        canvas.drawCircle(o, m.radius + wob, Paint()..color = const Color(0x5080DEEA));
        canvas.drawCircle(o, m.radius + 2, Paint()
          ..color = const Color(0x9980DEEA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }
      // Boss 虚弱（金色）
      if (m.weakT > 0) {
        canvas.drawCircle(o, m.radius + wob, Paint()..color = const Color(0x44FFD54F));
        canvas.drawCircle(o, m.radius + 3, Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
        _text(canvas, '虚弱', Offset(m.x, m.y - m.radius - 26), 12, const Color(0xFFFFD54F),
            stroke: const Color(0xAA000000));
      }
      // 精英/首领光环
      if (m.isBoss) {
        canvas.drawCircle(o, m.radius + 5 + 2 * sin(game.time * 4), Paint()
          ..color = const Color(0x55EF5350)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
        if (m.skillWarn > 0) {
          final pulse = 0.6 + 0.4 * sin(game.time * 14);
          canvas.drawCircle(o, 240 * pulse, Paint()..color = const Color(0x22FF5252));
          canvas.drawCircle(o, 240 * pulse, Paint()
            ..color = const Color(0x99FF5252)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
        }
      } else if (m.isElite) {
        canvas.drawCircle(o, m.radius + 3, Paint()
          ..color = const Color(0x6640C4FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
      // 弓箭手瞄准线预警
      if (m.kind == MonsterKind.archer && m.shotCd <= 0.4 && m.stun <= 0) {
        final ang = atan2(game.player.y - m.y, game.player.x - m.x);
        final t = (1 - m.shotCd / 0.4).clamp(0.2, 1.0);
        canvas.drawLine(o, o + Offset(cos(ang), sin(ang)) * 320, Paint()
          ..color = const Color(0xFFFF5252).withValues(alpha: t)
          ..strokeWidth = 2);
      }
      if (m.hp < m.maxHp || m.isBoss || m.isElite) {
        final w = m.radius * 2;
        final hpY = m.y - m.radius - 9;
        canvas.drawRect(Rect.fromCenter(center: Offset(m.x, hpY), width: w + 2, height: 6),
            Paint()..color = const Color(0xAA000000));
        canvas.drawRect(Rect.fromCenter(center: Offset(m.x, hpY), width: w, height: 4),
            Paint()..color = const Color(0xAA000000));
        canvas.drawRect(Rect.fromCenter(center: Offset(m.x, hpY), width: w * (m.hp / m.maxHp), height: 4),
            Paint()..color = m.isBoss ? const Color(0xFFFF5252) : const Color(0xFF66BB6A));
        if (m.isBoss || m.isElite) {
          _text(canvas, 'Lv.${m.level}', Offset(m.x, hpY - 12), 11, const Color(0xFFFFD54F),
              stroke: const Color(0xAA000000));
        }
      }
    }
  }

  // ---------- 玩家 ----------
  void _drawPlayer(Canvas canvas) {
    final p = game.player;
    if (p.invuln > 0 && (p.invuln * 12).floor() % 2 == 0) return;
    final o = Offset(p.x, p.y);
    final r = p.radius();
    final sc = p.skinDef.color;
    canvas.drawCircle(o, r + 6, Paint()..color = sc.withValues(alpha: 0.13));
    final grad = Paint()
      ..shader = RadialGradient(colors: [const Color(0xFFFFFFFF), sc])
          .createShader(Rect.fromCircle(center: o, radius: r));
    canvas.drawCircle(o, r, grad);
    canvas.drawCircle(o, r, Paint()
      ..color = sc
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    final ex = cos(p.facing), ey = sin(p.facing);
    canvas.drawCircle(o + Offset(ex * r * 0.3, ey * r * 0.3 - 2), r * 0.16, Paint()..color = const Color(0xFF0B0E14));
    canvas.drawCircle(o + Offset(ex * r * 0.3, ey * r * 0.3 - 2), r * 0.08, Paint()..color = Colors.white);
    if (p.level > 1) {
      _text(canvas, 'Lv.${p.level}', Offset(p.x, p.y - r - 14), 13, const Color(0xFF90CAF9),
          stroke: const Color(0xAA000000));
    }
    if (p.slow > 0) {
      canvas.drawCircle(o, r + 2, Paint()
        ..color = const Color(0x6680DEEA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    if (p.burn > 0) {
      canvas.drawCircle(o, r + 4, Paint()..color = const Color(0x44FF5722));
      canvas.drawCircle(o, r + 2, Paint()
        ..color = const Color(0x88FF5722)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
    if (p.powerT > 0) {
      canvas.drawCircle(o, r + 6, Paint()..color = const Color(0x44FF8A65));
    }
    if (p.hasteT > 0) {
      for (int i = 0; i < 3; i++) {
        final a = p.facing + (i - 1) * 0.6;
        canvas.drawLine(o + Offset(cos(a) * (r + 8), sin(a) * (r + 8)),
            o + Offset(cos(a) * (r + 17), sin(a) * (r + 17)),
            Paint()..color = const Color(0xAAFFD54F)..strokeWidth = 2);
      }
    }
    if (p.shieldT > 0) {
      final bubble = r + 10 + 2 * sin(game.time * 6);
      canvas.drawCircle(o, bubble, Paint()..color = const Color(0x2264B5F6));
      canvas.drawCircle(o, bubble, Paint()
        ..color = const Color(0xAA64B5F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    // 受击/增益状态文字
    var sy = p.y - r - 36;
    void st(String t, Color c) {
      _text(canvas, t, Offset(p.x, sy), 11, c, stroke: const Color(0xAA000000));
      sy -= 14;
    }

    if (p.slow > 0) st('减速', const Color(0xFF80DEEA));
    if (p.burn > 0) st('灼烧', const Color(0xFFFF7043));
    if (p.hasteT > 0) st('疾速', const Color(0xFFFFD54F));
    if (p.powerT > 0) st('狂暴', const Color(0xFFFF8A65));
    if (p.shieldT > 0) st('护盾', const Color(0xFF64B5F6));
    if (p.invuln > 0) st('无敌', const Color(0xFFB39DDB));
  }

  // ---------- 环绕剑 ----------
  void _drawOrbit(Canvas canvas) {
    final lv = game.player.weaponLevel(WeaponType.orbit);
    if (lv <= 0) return;
    final o = orbitParam(lv);
    canvas.drawCircle(Offset(game.player.x, game.player.y), o.radius, Paint()
      ..color = const Color(0x119CCC65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    final n = o.count;
    for (int i = 0; i < n; i++) {
      final a = game.orbitAngle + i * 2 * pi / n;
      final x = game.player.x + cos(a) * o.radius;
      final y = game.player.y + sin(a) * o.radius;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(a + pi / 2);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 5, height: 16), const Radius.circular(2.5)),
          Paint()..color = const Color(0xFF9CCC65));
      canvas.restore();
    }
  }

  // ---------- 激光 ----------
  void _drawLaser(Canvas canvas) {
    if (game.laserT <= 0) return;
    final a = (game.laserT / 0.16).clamp(0.0, 1.0);
    final p0 = Offset(game.player.x, game.player.y);
    final p1 = p0 + Offset(cos(game.laserAngle), sin(game.laserAngle)) * game.laserLen;
    canvas.drawLine(p0, p1, Paint()
      ..color = const Color(0x6629B6F6).withValues(alpha: a)
      ..strokeWidth = game.laserWidth * 3);
    canvas.drawLine(p0, p1, Paint()
      ..color = const Color(0xFFB3E5FC).withValues(alpha: a)
      ..strokeWidth = game.laserWidth);
  }

  // ---------- 闪电 ----------
  void _drawLightning(Canvas canvas) {
    if (game.lightningT <= 0 || game.lightningFx.length < 2) return;
    final a = (game.lightningT / 0.25).clamp(0.0, 1.0);
    for (int i = 1; i < game.lightningFx.length; i++) {
      canvas.drawLine(game.lightningFx[i - 1], game.lightningFx[i], Paint()
        ..color = const Color(0xCCFFEE58).withValues(alpha: a)
        ..strokeWidth = 4);
      canvas.drawLine(game.lightningFx[i - 1], game.lightningFx[i], Paint()
        ..color = Colors.white.withValues(alpha: a * 0.9)
        ..strokeWidth = 1.5);
    }
  }

  // ---------- 战斧挥砍 ----------
  void _drawAxeFx(Canvas canvas) {
    if (game.axeT <= 0) return;
    final k = game.axeT / 0.3;
    final c = Offset(game.player.x, game.player.y);
    final r = game.axeFxRadius;
    final start = game.axeAngle - 1.2 * (1 - k);
    final end = game.axeAngle + 1.2 * k;
    // 弧光
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, end - start, false, Paint()
      ..color = const Color(0x99EF5350).withValues(alpha: k)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round);
    // 旋转斧刃（月牙形刀头）
    final ang = game.axeAngle + (k - 0.5) * 1.2;
    final px = c.dx + cos(ang) * r * 0.8, py = c.dy + sin(ang) * r * 0.8;
    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(ang + pi / 2);
    final head = Path()
      ..moveTo(0, -16)
      ..arcToPoint(Offset(0, 16), radius: const Radius.circular(14))
      ..quadraticBezierTo(18, 0, 0, -16);
    canvas.drawPath(head, Paint()..color = const Color(0xFFB71C1C).withValues(alpha: k * 0.9));
    canvas.restore();
  }

  // ---------- 旋风棍 ----------
  void _drawStaffFx(Canvas canvas) {
    if (game.staffT <= 0) return;
    final k = game.staffT / 0.35;
    final c = Offset(game.player.x, game.player.y);
    final r = game.staffFxR;
    final a = game.staffAngle + (1 - k) * 2;
    canvas.drawLine(c + Offset(cos(a), sin(a)) * r * 0.35, c + Offset(cos(a), sin(a)) * r,
        Paint()
          ..color = const Color(0xFFA1887F).withValues(alpha: k)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, 1.1, false, Paint()
      ..color = const Color(0x88A1887F).withValues(alpha: k)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);
  }

  // ---------- 铁拳 ----------
  void _drawFistFx(Canvas canvas) {
    if (game.fistT <= 0) return;
    final k = game.fistT / 0.15;
    final c = Offset(game.player.x, game.player.y);
    final side = game.fistSideFx == 0 ? -1 : 1;
    final ang = game.player.facing + side * pi / 2;
    final r = game.player.radius() + 30;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), ang - 0.6, 1.2, false, Paint()
      ..color = const Color(0xFFFF8A65).withValues(alpha: k)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round);
  }

  // ---------- 圣光十字 ----------
  void _drawHolyFlash(Canvas canvas) {
    if (game.flash <= 0) return;
    final a = (game.flash / 0.25).clamp(0.0, 1.0);
    final p = Offset(game.player.x, game.player.y);
    final len = 130 * (1.5 - a * 0.5);
    final paint = Paint()
      ..color = const Color(0x66FFF59D).withValues(alpha: a)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p - Offset(len, 0), p + Offset(len, 0), paint);
    canvas.drawLine(p - Offset(0, len), p + Offset(0, len), paint);
  }

  // ---------- 荆棘护盾 ----------
  void _drawThorns(Canvas canvas) {
    if (game.player.weaponLevel(WeaponType.thorns) <= 0) return;
    final o = Offset(game.player.x, game.player.y);
    final r = game.player.radius() + 12;
    final pulse = 0.92 + 0.08 * sin(game.time * 5);
    canvas.drawCircle(o, r * pulse, Paint()..color = const Color(0x22C5E1A5));
    canvas.drawCircle(o, r * pulse, Paint()
      ..color = const Color(0x99A5D6A7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    for (int i = 0; i < 8; i++) {
      final a = i * 2 * pi / 8 + game.time * 0.5;
      canvas.drawLine(o + Offset(cos(a) * (r * pulse - 4), sin(a) * (r * pulse - 4)),
          o + Offset(cos(a) * (r * pulse + 6), sin(a) * (r * pulse + 6)),
          Paint()
            ..color = const Color(0xFF81C784)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round);
    }
  }

  // ---------- 投射物 ----------
  void _drawProjectiles(Canvas canvas) {
    for (final pr in game.projectiles) {
      if (!_onScreen(pr.x, pr.y)) continue;
      if (pr.crescent) {
        // 剑气月牙（更大更亮）
        final s = pr.radius * 2;
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.rotate(pr.angle);
        canvas.drawCircle(Offset.zero, s * 1.5, Paint()..color = const Color(0x33B39DDB));
        final path = Path()
          ..moveTo(-s * 0.9, -s * 0.55)
          ..quadraticBezierTo(s * 0.5, 0, -s * 0.9, s * 0.55)
          ..quadraticBezierTo(0, 0, -s * 0.9, -s * 0.55);
        canvas.drawPath(path, Paint()
          ..color = const Color(0xFFB39DDB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.22
          ..strokeCap = StrokeCap.round);
        canvas.restore();
        continue;
      }
      if (pr.boomerang) {
        // 回旋飞刀（旋转四叶刀）
        final s = pr.radius * 3;
        canvas.drawCircle(Offset(pr.x, pr.y), s * 0.9, Paint()..color = const Color(0x2280CBC4));
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.rotate(atan2(pr.vy, pr.vx) + game.time * 9);
        final blade = Path()
          ..moveTo(s * 0.9, 0)
          ..lineTo(-s * 0.35, s * 0.5)
          ..lineTo(-s * 0.6, 0)
          ..lineTo(-s * 0.35, -s * 0.5)
          ..close();
        canvas.drawPath(blade, Paint()..color = const Color(0xFF26A69A));
        canvas.restore();
        continue;
      }
      if (pr.hostile) {
        // 敌方箭：红色箭头 + 预警光晕
        final ang = atan2(pr.vy, pr.vx);
        canvas.drawCircle(Offset(pr.x, pr.y), 11, Paint()..color = const Color(0x33FF5252));
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.rotate(ang);
        final arrow = Path()
          ..moveTo(8, 0)
          ..lineTo(-5, -4.5)
          ..lineTo(-2, 0)
          ..lineTo(-5, 4.5)
          ..close();
        canvas.drawPath(arrow, Paint()..color = const Color(0xFFFF5252));
        canvas.restore();
        continue;
      }
      final col = pr.homing ? const Color(0xFFF48FB1) : const Color(0xFF4FC3F7);
      final glow = pr.homing ? const Color(0x22F48FB1) : const Color(0x22AEE0FF);
      canvas.drawCircle(Offset(pr.x, pr.y), pr.radius * 1.6, Paint()..color = glow);
      canvas.drawCircle(Offset(pr.x, pr.y), pr.radius, Paint()..color = col);
      canvas.drawCircle(Offset(pr.x, pr.y), pr.radius * 0.5, Paint()..color = Colors.white);
    }
  }

  // ---------- 粒子 ----------
  void _drawParticles(Canvas canvas) {
    for (final pt in game.particles) {
      if (!_onScreen(pt.x, pt.y)) continue;
      final a = (pt.life / pt.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(pt.x, pt.y), pt.size * (0.5 + 0.5 * a), Paint()..color = pt.color.withValues(alpha: a));
    }
  }

  // ---------- 浮动文字 ----------
  void _drawTexts(Canvas canvas) {
    for (final ft in game.floatTexts) {
      if (!_onScreen(ft.x, ft.y)) continue;
      final a = (ft.life / ft.maxLife).clamp(0.0, 1.0);
      _text(canvas, ft.text, Offset(ft.x, ft.y), ft.size, ft.color.withValues(alpha: a),
          stroke: const Color(0x99000000));
    }
    if (game.bossTimer <= 3 && game.phase == GamePhase.playing) {
      _text(canvas, '⚠ BOSS 即将来袭 ⚠', Offset(game.player.x, game.player.y - 70), 22,
          const Color(0xFFFF5252), stroke: const Color(0xCC000000));
    }
  }

  // ---------- 屏幕级特效 ----------
  void _drawScreenFx(Canvas canvas, Size size) {
    if (game.flash > 0) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = const Color(0xFFFFF8E1).withValues(alpha: game.flash * 0.6));
    }
    if (game.hurtT > 0) {
      canvas.drawRect(Offset.zero & size, Paint()
        ..color = const Color(0xFFE53935)
            .withValues(alpha: (game.hurtT / 0.4).clamp(0.0, 1.0) * 0.3));
    }
    final r = (game.player.hp / game.player.maxHp).clamp(0.0, 1.0);
    if (r < 0.35) {
      final a = (1 - r / 0.35) * 0.25;
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFB00020).withValues(alpha: a));
    }
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, const Color(0x55000000)],
        stops: const [0.72, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.longestSide / 2)));
  }

  void _text(Canvas canvas, String s, Offset pos, double size, Color color, {Color? stroke}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
            color: color, fontSize: size, fontWeight: FontWeight.bold,
            shadows: stroke != null
                ? [Shadow(color: stroke, blurRadius: 2, offset: const Offset(0, 1))]
                : []),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}
