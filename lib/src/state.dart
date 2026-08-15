import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'audio.dart';
import 'config.dart';
import 'entities.dart';
import 'pay.dart';
import 'save.dart';

enum GamePhase { menu, playing, levelup, paused, gameover }

enum ChoiceKind { weapon, passive, heal, maxhp }

class UpgradeChoice {
  final ChoiceKind kind;
  final WeaponType? weapon;
  final PassiveType? passive;
  final int level;
  UpgradeChoice.weapon(this.weapon, this.level)
      : kind = ChoiceKind.weapon,
        passive = null;
  UpgradeChoice.passive(this.passive, this.level)
      : kind = ChoiceKind.passive,
        weapon = null;
  UpgradeChoice.heal()
      : kind = ChoiceKind.heal,
        weapon = null,
        passive = null,
        level = 0;
  UpgradeChoice.maxhp()
      : kind = ChoiceKind.maxhp,
        weapon = null,
        passive = null,
        level = 0;

  String title() => switch (kind) {
        ChoiceKind.weapon => '${weaponDefs[weapon!]!.name} Lv.$level',
        ChoiceKind.passive => passiveDefs[passive!]!.name,
        ChoiceKind.heal => '生命回复',
        ChoiceKind.maxhp => '生命上限提升',
      };

  String description() => switch (kind) {
        ChoiceKind.weapon => weaponDefs[weapon!]!.desc,
        ChoiceKind.passive => passiveDefs[passive!]!.desc,
        ChoiceKind.heal => '回复最大生命的 50%',
        ChoiceKind.maxhp => '生命上限 +15 并回复 15',
      };

  int rarity() => switch (kind) {
        ChoiceKind.weapon => weaponDefs[weapon!]!.rarity,
        ChoiceKind.passive => passiveDefs[passive!]!.rarity,
        ChoiceKind.heal => 0,
        ChoiceKind.maxhp => 0,
      };

  Color color() => switch (kind) {
        ChoiceKind.weapon => weaponDefs[weapon!]!.color,
        ChoiceKind.passive => const Color(0xFF90A4AE),
        ChoiceKind.heal => const Color(0xFFEF5350),
        ChoiceKind.maxhp => const Color(0xFFEC407A),
      };
}

class MetaProgress {
  double gold = 0;
  int bestLevel = 0;
  double bestTime = 0;
  List<int> metaBought = [0, 0, 0, 0, 0, 0]; // 生命/速度/力量/攻速/暴击/吸血
  bool monthlyCard = false;
  int adsWatched = 0;
  int selectedSkin = 0;
  List<int> ownedSkins = [0];
}

class GameState {
  /// 测试开关：为 true 时只写内存，不落盘（避免污染真实存档）
  static bool debugNoSave = false;
  GamePhase phase = GamePhase.menu;
  final Player player = Player();
  final List<Monster> monsters = [];
  final List<Projectile> projectiles = [];
  final List<Pickup> pickups = [];
  final List<Particle> particles = [];
  final List<FloatText> floatTexts = [];
  final MetaProgress meta = MetaProgress();

  double time = 0;
  int kills = 0;
  double gold = 0;
  double shake = 0;

  double spawnTimer = 0.8;
  double bossTimer = kBossEvery;
  double eliteTimer = kEliteEvery;
  double orbitAngle = 0;
  double boltTimer = 0, axeTimer = 0, lightningTimer = 0, auraTick = 0;
  double frostTimer = 0, homingTimer = 0, holyTimer = 0, laserTimer = 0;
  double laserAngle = 0, laserLen = 0, laserWidth = 6, laserT = 0;
  double lightningT = 0;
  List<Offset> lightningFx = [];
  double axeT = 0, axeAngle = 0, axeFxRadius = 120;
  double staffT = 0, staffAngle = 0, staffFxR = 100;
  double fistT = 0;
  int fistSideFx = 0;
  double scytheTimer = 0, venomTimer = 0;
  double gunTimer = 0, staffTimer = 0, bladeTimer = 0, swordTimer = 0, fistsTimer = 0;
  int fistsSide = 0;
  final List<VenomZone> venomZones = [];
  int bossCount = 0;
  int reviveLeft = kRevivePerRun;
  double hitStop = 0; // 顿帧：冻结世界制造打击感
  double hurtT = 0; // 受击红闪
  bool frozen = false; // 查看面板时暂停模拟
  double flash = 0;
  double autosaveTimer = 0;

  List<UpgradeChoice> pendingChoices = [];
  double viewW = 800, viewH = 600;

  final Random rng = Random();
  Map<String, dynamic> _store = {};

  GameState() {
    final raw = readSave();
    if (raw != null && raw.isNotEmpty) {
      try {
        _store = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    final m = _store['meta'];
    if (m != null) {
      meta.gold = ((m['gold'] ?? 0) as num).toDouble();
      meta.bestLevel = (m['bestLevel'] ?? 0) as int;
      meta.bestTime = ((m['bestTime'] ?? 0) as num).toDouble();
      final mb = m['metaBought'];
      if (mb is List) meta.metaBought = List<int>.from(mb);
      while (meta.metaBought.length < 6) {
        meta.metaBought.add(0);
      }
      meta.monthlyCard = m['monthlyCard'] == true;
      meta.adsWatched = (m['adsWatched'] ?? 0) as int;
      meta.selectedSkin = (m['selectedSkin'] ?? 0) as int;
      final os = m['ownedSkins'];
      if (os is List) meta.ownedSkins = List<int>.from(os);
      if (!meta.ownedSkins.contains(0)) meta.ownedSkins.add(0);
    }
  }

  // ---------- 主循环 ----------
  void update(double dt, Offset dir) {
    if (phase != GamePhase.playing || frozen) return;
    if (hitStop > 0) {
      hitStop -= dt;
      return;
    }
    time += dt;
    player.invuln = max(0, player.invuln - dt);
    shake = max(0, shake - dt * 28);
    flash = max(0, flash - dt);
    laserT = max(0, laserT - dt);
    lightningT = max(0, lightningT - dt);
    axeT = max(0, axeT - dt);
    staffT = max(0, staffT - dt);
    fistT = max(0, fistT - dt);
    final regen = player.passiveLevel(PassiveType.regen);
    if (regen > 0) player.heal(player.regenPerSec() * dt);
    hurtT = max(0, hurtT - dt);
    // 玩家异常状态与临时增益
    player.slow = max(0, player.slow - dt);
    player.shieldT = max(0, player.shieldT - dt);
    player.powerT = max(0, player.powerT - dt);
    player.hasteT = max(0, player.hasteT - dt);
    player.burn = max(0, player.burn - dt);
    if (player.burn > 0) _directDamage(kBurnDps * dt);

    // 玩家移动
    var dx = dir.dx, dy = dir.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len > 0.001) {
      dx /= len;
      dy /= len;
      player.facing = atan2(dy, dx);
    }
    player.x += dx * player.moveSpeed() * dt;
    player.y += dy * player.moveSpeed() * dt;

    weaponsUpdate(dt);
    updateMonsters(dt);
    updateProjectiles(dt);
    updatePickups(dt);
    updateVenom(dt);
    updateFx(dt);
    spawning(dt);
    cleanup();

    // 升级判定
    if (player.xp >= player.xpNeed) {
      player.xp -= player.xpNeed;
      player.level += 1;
      player.xpNeed = xpNeeded(player.level);
      player.addMaxHp(levelUpHp(player.level)); // 阶梯提升生命上限并回复
      AudioManager.I.play('sfx_levelup');
      pendingChoices = generateChoices();
      phase = GamePhase.levelup;
    }

    autosaveTimer += dt;
    if (autosaveTimer >= 10) {
      autosaveTimer = 0;
      saveRun();
    }
  }

  // ---------- 武器 ----------
  void weaponsUpdate(double dt) {
    final haste = player.hasteMult();

    if (player.weaponLevel(WeaponType.bolt) > 0) {
      boltTimer -= dt;
      while (boltTimer <= 0) {
        final p = boltParam(player.weaponLevel(WeaponType.bolt));
        boltTimer += p.interval * haste;
        fireBolt(p);
      }
    }
    if (player.weaponLevel(WeaponType.axe) > 0) {
      axeTimer -= dt;
      while (axeTimer <= 0) {
        final p = axeParam(player.weaponLevel(WeaponType.axe));
        axeTimer += p.interval * haste;
        fireAxe(p);
      }
    }
    if (player.weaponLevel(WeaponType.lightning) > 0) {
      lightningTimer -= dt;
      while (lightningTimer <= 0) {
        final p = lightningParam(player.weaponLevel(WeaponType.lightning));
        lightningTimer += p.interval * haste;
        fireLightning(p);
      }
    }
    if (player.weaponLevel(WeaponType.orbit) > 0) {
      orbitAngle += orbitParam(player.weaponLevel(WeaponType.orbit)).angSpeed * dt;
    }
    if (player.weaponLevel(WeaponType.aura) > 0) {
      auraTick -= dt;
      final p = auraParam(player.weaponLevel(WeaponType.aura));
      if (auraTick <= 0) {
        auraTick = 0.25;
        for (final m in monsters) {
          if (m.dead) continue;
          if (dist(player.x, player.y, m.x, m.y) <=
              p.radius * areaMult() + m.radius) {
            damageMonster(m, p.dmg * player.damageMult(), crit: false, kb: 0);
          }
        }
        for (int i = 0; i < 6; i++) {
          final a = rng.nextDouble() * 2 * pi;
          final r = p.radius * (0.9 + rng.nextDouble() * 0.2);
          particles.add(Particle(
              x: player.x + cos(a) * r,
              y: player.y + sin(a) * r,
              vx: cos(a) * 40,
              vy: sin(a) * 40,
              life: 0.3,
              size: 3,
              color: const Color(0xFFFF7043)));
        }
      }
    }
    if (player.weaponLevel(WeaponType.frost) > 0) {
      frostTimer -= dt;
      while (frostTimer <= 0) {
        final p = frostParam(player.weaponLevel(WeaponType.frost));
        frostTimer += p.interval * haste;
        fireFrost(p);
      }
    }
    if (player.weaponLevel(WeaponType.homing) > 0) {
      homingTimer -= dt;
      while (homingTimer <= 0) {
        final p = homingParam(player.weaponLevel(WeaponType.homing));
        homingTimer += p.interval * haste;
        fireHoming(p);
      }
    }
    if (player.weaponLevel(WeaponType.holy) > 0) {
      holyTimer -= dt;
      while (holyTimer <= 0) {
        final p = holyParam(player.weaponLevel(WeaponType.holy));
        holyTimer += p.interval * haste;
        fireHoly(p);
      }
    }
    if (player.weaponLevel(WeaponType.laser) > 0) {
      laserTimer -= dt;
      while (laserTimer <= 0) {
        final p = laserParam(player.weaponLevel(WeaponType.laser));
        laserTimer += p.interval * haste;
        fireLaser(p);
      }
    }
    if (player.weaponLevel(WeaponType.scythe) > 0) {
      scytheTimer -= dt;
      while (scytheTimer <= 0) {
        final p = scytheParam(player.weaponLevel(WeaponType.scythe));
        scytheTimer += p.interval * haste;
        fireScythe(p);
      }
    }
    if (player.weaponLevel(WeaponType.venom) > 0) {
      venomTimer -= dt;
      while (venomTimer <= 0) {
        final p = venomParam(player.weaponLevel(WeaponType.venom));
        venomTimer += p.interval * haste;
        placeVenom(p);
      }
    }
    if (player.weaponLevel(WeaponType.gun) > 0) {
      gunTimer -= dt;
      while (gunTimer <= 0) {
        final p = gunParam(player.weaponLevel(WeaponType.gun));
        gunTimer += p.interval * haste;
        fireGun(p);
      }
    }
    if (player.weaponLevel(WeaponType.staff) > 0) {
      staffTimer -= dt;
      while (staffTimer <= 0) {
        final p = staffParam(player.weaponLevel(WeaponType.staff));
        staffTimer += p.interval * haste;
        fireStaff(p);
      }
    }
    if (player.weaponLevel(WeaponType.blade) > 0) {
      bladeTimer -= dt;
      while (bladeTimer <= 0) {
        final p = bladeParam(player.weaponLevel(WeaponType.blade));
        bladeTimer += p.interval * haste;
        fireBlade(p);
      }
    }
    if (player.weaponLevel(WeaponType.sword) > 0) {
      swordTimer -= dt;
      while (swordTimer <= 0) {
        final p = swordParam(player.weaponLevel(WeaponType.sword));
        swordTimer += p.interval * haste;
        fireSword(p);
      }
    }
    if (player.weaponLevel(WeaponType.fists) > 0) {
      fistsTimer -= dt;
      while (fistsTimer <= 0) {
        final p = fistsParam(player.weaponLevel(WeaponType.fists));
        fistsTimer += p.interval * haste;
        fireFists(p);
      }
    }
  }

  void fireBolt(BoltParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('bolt', 'sfx_bolt');
    final target = nearestMonster(460);
    double base = player.facing;
    if (target != null) base = atan2(target.y - player.y, target.x - player.x);
    for (int i = 0; i < p.count; i++) {
      final a = base + (i - (p.count - 1) / 2) * 0.14;
      projectiles.add(Projectile(
          x: player.x,
          y: player.y,
          vx: cos(a) * p.speed,
          vy: sin(a) * p.speed,
          damage: dmg,
          radius: 4.5 + p.lv * 0.35,
          pierce: p.pierce,
          life: 1.6,
          crit: rollCrit()));
    }
  }

  void fireAxe(AxeParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('axe', 'sfx_axe');
    final rr = p.radius * areaMult();
    axeT = 0.3;
    axeAngle = rng.nextDouble() * 2 * pi;
    axeFxRadius = rr;
    for (final m in monsters) {
      if (m.dead) continue;
      if (dist(player.x, player.y, m.x, m.y) <= rr + m.radius) {
        damageMonster(m, dmg, crit: rollCrit(), kb: 90);
      }
    }
    for (int i = 0; i < 18; i++) {
      final a = i / 18 * 2 * pi;
      particles.add(Particle(
          x: player.x + cos(a) * rr,
          y: player.y + sin(a) * p.radius,
          vx: cos(a) * -80,
          vy: sin(a) * -80,
          life: 0.32,
          size: 3.2,
          color: const Color(0xFFEF9A9A)));
    }
  }

  void fireLightning(LightningParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('lightning', 'sfx_lightning');
    final chain = <Monster>[];
    Monster? cur = nearestMonster(p.range);
    while (cur != null && chain.length <= p.chains) {
      if (chain.contains(cur)) break;
      chain.add(cur);
      Monster? next;
      double best = p.chainRange;
      for (final m in monsters) {
        if (m.dead || chain.contains(m)) continue;
        final d = dist(cur.x, cur.y, m.x, m.y);
        if (d < best) {
          best = d;
          next = m;
        }
      }
      cur = next;
    }
    for (final m in chain) {
      damageMonster(m, dmg, crit: rollCrit(), kb: 30);
    }
    // 闪电折线特效
    lightningT = 0.25;
    final pts = <Offset>[Offset(player.x, player.y)];
    for (final m in chain) {
      pts.add(Offset(m.x + (rng.nextDouble() - 0.5) * 16, m.y + (rng.nextDouble() - 0.5) * 16));
    }
    lightningFx = pts;
    for (int i = 1; i < chain.length; i++) {
      for (int k = 0; k < 5; k++) {
        final t = k / 4.0;
        final x = chain[i - 1].x + (chain[i].x - chain[i - 1].x) * t +
            (rng.nextDouble() - 0.5) * 14;
        final y = chain[i - 1].y + (chain[i].y - chain[i - 1].y) * t +
            (rng.nextDouble() - 0.5) * 14;
        particles.add(Particle(
            x: x, y: y, vx: 0, vy: 0, life: 0.22, size: 2.6,
            color: const Color(0xFFFFEE58)));
      }
    }
  }

  void fireFrost(FrostParam p) {
    final dmg = p.dmg * player.damageMult();
    final r = p.radius * areaMult();
    for (final m in monsters) {
      if (m.dead) continue;
      if (dist(player.x, player.y, m.x, m.y) <= r + m.radius) {
        m.slow = 2.0;
        damageMonster(m, dmg, crit: rollCrit(), kb: 40);
      }
    }
    for (int i = 0; i < 22; i++) {
      final a = i / 22 * 2 * pi;
      particles.add(Particle(
          x: player.x + cos(a) * r,
          y: player.y + sin(a) * r,
          vx: cos(a) * -90,
          vy: sin(a) * -90,
          life: 0.4,
          size: 3.5,
          color: const Color(0xFF80DEEA)));
    }
  }

  void fireHoming(HomingParam p) {
    final dmg = p.dmg * player.damageMult();
    for (int i = 0; i < p.count; i++) {
      final a = player.facing + (i - (p.count - 1) / 2) * 0.3;
      final spd = p.speed * (1 + rng.nextDouble() * 0.1);
      projectiles.add(Projectile(
          x: player.x,
          y: player.y,
          vx: cos(a) * spd,
          vy: sin(a) * spd,
          damage: dmg,
          radius: 4 + p.lv * 0.3,
          pierce: 0,
          life: 3.0,
          crit: rollCrit(),
          homing: true,
          speed: spd));
    }
  }

  void fireHoly(HolyParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('holy', 'sfx_holy');
    final r = p.radius * areaMult();
    for (final m in monsters) {
      if (m.dead) continue;
      if (dist(player.x, player.y, m.x, m.y) <= r + m.radius) {
        damageMonster(m, dmg, crit: rollCrit(), kb: 120);
      }
    }
    flash = 0.25;
    for (int i = 0; i < 26; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final rr = r * rng.nextDouble();
      particles.add(Particle(
          x: player.x + cos(a) * rr,
          y: player.y + sin(a) * rr,
          vx: cos(a) * 40,
          vy: sin(a) * 40,
          life: 0.5,
          size: 4,
          color: const Color(0xFFFFF59D)));
    }
  }

  void fireLaser(LaserParam p) {
    final dmg = p.dmg * player.damageMult();
    final t = nearestMonster(p.length);
    final a = t != null ? atan2(t.y - player.y, t.x - player.x) : player.facing;
    laserAngle = a;
    laserLen = p.length;
    laserWidth = p.width;
    laserT = 0.16;
    for (int i = 0; i < 5; i++) {
      final j = (rng.nextDouble() - 0.5) * 0.6;
      particles.add(Particle(
          x: player.x, y: player.y,
          vx: cos(a + j) * 260, vy: sin(a + j) * 260,
          life: 0.15, size: 3, color: const Color(0xFF4FC3F7)));
    }
    final dx = cos(a), dy = sin(a);
    for (final m in monsters) {
      if (m.dead) continue;
      final rx = m.x - player.x, ry = m.y - player.y;
      final proj = rx * dx + ry * dy;
      if (proj < 0 || proj > p.length) continue;
      final perp = (rx * dy - ry * dx).abs();
      if (perp <= p.width / 2 + m.radius) {
        damageMonster(m, dmg, crit: rollCrit(), kb: 20);
      }
    }
  }

  void fireScythe(ScytheParam p) {
    final dmg = p.dmg * player.damageMult();
    final r = p.radius * areaMult();
    final base = player.facing;
    const arc = 0.8 * pi;
    axeT = 0.25;
    axeAngle = base - arc / 2;
    axeFxRadius = r;
    for (final m in monsters) {
      if (m.dead) continue;
      final rx = m.x - player.x, ry = m.y - player.y;
      final d = sqrt(rx * rx + ry * ry);
      if (d > r + m.radius) continue;
      var ang = atan2(ry, rx) - base;
      while (ang > pi) {
        ang -= 2 * pi;
      }
      while (ang < -pi) {
        ang += 2 * pi;
      }
      if (ang.abs() > arc / 2 + 0.3) continue;
      damageMonster(m, dmg, crit: rollCrit(), kb: 60);
    }
  }

  void placeVenom(VenomParam p) {
    final r = p.radius * areaMult();
    venomZones.add(VenomZone(
        x: player.x, y: player.y,
        radius: r,
        timer: p.duration,
        dmg: p.dmg * player.damageMult()));
    for (int i = 0; i < 8; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final rr = r * rng.nextDouble();
      particles.add(Particle(
          x: player.x + cos(a) * rr, y: player.y + sin(a) * rr,
          vx: (rng.nextDouble() - 0.5) * 40, vy: (rng.nextDouble() - 0.5) * 40,
          life: 0.6, size: 3, color: const Color(0xFF9CCC65)));
    }
  }

  void fireGun(GunParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('gun', 'sfx_gun');
    final target = nearestMonster(480);
    final base = target != null ? atan2(target.y - player.y, target.x - player.x) : player.facing;
    final count = p.lv >= 10 ? 2 : 1; // 满级双发
    for (int i = 0; i < count; i++) {
      final a = base + (i - (count - 1) / 2) * 0.08;
      projectiles.add(Projectile(
          x: player.x, y: player.y,
          vx: cos(a) * p.speed, vy: sin(a) * p.speed,
          damage: dmg, radius: 3.5 + p.lv * 0.3, pierce: 0, life: 1.0,
          crit: rollCrit()));
    }
  }

  void fireStaff(StaffParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('staff', 'sfx_staff');
    final r = p.radius * areaMult();
    staffT = 0.35;
    staffAngle = rng.nextDouble() * 2 * pi;
    staffFxR = r;
    for (final m in monsters) {
      if (m.dead) continue;
      if (dist(player.x, player.y, m.x, m.y) <= r + m.radius) {
        damageMonster(m, dmg, crit: rollCrit(), kb: 160);
      }
    }
    for (int i = 0; i < 14; i++) {
      final a = i / 14 * 2 * pi;
      particles.add(Particle(
          x: player.x + cos(a) * r, y: player.y + sin(a) * r,
          vx: cos(a) * -70, vy: sin(a) * -70,
          life: 0.3, size: 3, color: const Color(0xFFA1887F)));
    }
  }

  void fireBlade(BladeParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('blade', 'sfx_blade');
    final count = p.lv >= 10 ? p.count + 1 : p.count; // 满级多一把
    for (int i = 0; i < count; i++) {
      final a = player.facing + (i - (count - 1) / 2) * 0.7;
      projectiles.add(Projectile(
          x: player.x, y: player.y,
          vx: cos(a) * p.speed, vy: sin(a) * p.speed,
          damage: dmg, radius: 6 + p.lv * 0.3, pierce: 999, life: 4.0,
          crit: rollCrit(), boomerang: true, speed: p.speed, range: p.range,
          origin: Offset(player.x, player.y)));
    }
  }

  void fireSword(SwordParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('sword', 'sfx_sword');
    final target = nearestMonster(500);
    final base = target != null ? atan2(target.y - player.y, target.x - player.x) : player.facing;
    final waves = p.lv >= 10 ? p.waves + 1 : p.waves; // 满级多一道剑气
    for (int i = 0; i < waves; i++) {
      final a = base + (i - (waves - 1) / 2) * 0.5;
      projectiles.add(Projectile(
          x: player.x, y: player.y,
          vx: cos(a) * p.speed, vy: sin(a) * p.speed,
          damage: dmg, radius: 10 + p.lv * 0.5, pierce: 999, life: 1.5,
          crit: rollCrit(), crescent: true, angle: a));
    }
  }

  void fireFists(FistsParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('fists', 'sfx_fists');
    final r = p.radius * areaMult();
    fistsSide = 1 - fistsSide;
    fistT = 0.15;
    fistSideFx = fistsSide;
    final ang = player.facing + (fistsSide == 0 ? -1 : 1) * pi / 2;
    for (final m in monsters) {
      if (m.dead) continue;
      final d = dist(m.x, m.y, player.x, player.y);
      if (d > r + m.radius || d <= 0.01) continue;
      final dx = (m.x - player.x) / d, dy = (m.y - player.y) / d;
      if (dx * cos(ang) + dy * sin(ang) > 0.4) {
        damageMonster(m, dmg, crit: rollCrit(), kb: 40);
      }
    }
    for (int i = 0; i < 4; i++) {
      final a = ang + (rng.nextDouble() - 0.5) * 0.4;
      particles.add(Particle(
          x: player.x + cos(a) * r, y: player.y + sin(a) * r,
          vx: cos(a) * 140, vy: sin(a) * 140,
          life: 0.18, size: 5, color: const Color(0xFFFF8A65)));
    }
  }

  void updateVenom(double dt) {
    for (final z in venomZones) {
      z.timer -= dt;
      for (final m in monsters) {
        if (m.dead) continue;
        if (dist(z.x, z.y, m.x, m.y) <= z.radius + m.radius) {
          m.hitTimer = max(m.hitTimer, 0.1);
          m.hp -= z.dmg * dt;
          if (m.hp <= 0) killMonster(m);
        }
      }
    }
    venomZones.removeWhere((z) => z.timer <= 0);
  }

  void _directDamage(double dmg) {
    player.hp -= dmg;
    if (player.hp <= 0) {
      player.hp = 0;
      gameOver();
    }
  }

  // ---------- 伤害 ----------
  double areaMult() => 1 + 0.10 * (player.passiveLevel(PassiveType.area));

  bool rollCrit() => rng.nextDouble() < player.critChance();

  void damageMonster(Monster m, double rawDmg,
      {required bool crit, double kb = 50}) {
    if (m.dead) return;
    AudioManager.I.playHit();
    final critMult = kCritMult + 0.3 * player.passiveLevel(PassiveType.critDmg);
    var dmg = crit ? rawDmg * critMult : rawDmg;
    if (m.weakT > 0) dmg *= 1.5; // 虚弱：受伤加深 50%
    m.hp -= dmg;
    m.hitTimer = 0.12;
    if (rng.nextDouble() < 0.06 * player.passiveLevel(PassiveType.stun)) {
      m.stun = max(m.stun, 0.8);
    }
    final ls = player.lifesteal();
    if (ls > 0) player.heal(dmg * ls);
    final kbEff = m.isBoss ? 0.0 : (m.isElite ? kb * 0.3 : kb);
    if (kbEff > 0) {
      final ang = atan2(m.y - player.y, m.x - player.x);
      m.x += cos(ang) * kbEff;
      m.y += sin(ang) * kbEff;
    }
    floatTexts.add(FloatText(
        x: m.x + (rng.nextDouble() - 0.5) * 12,
        y: m.y - m.radius - 6,
        text: crit ? '${dmg.toStringAsFixed(0)}!' : dmg.toStringAsFixed(0),
        color: crit ? const Color(0xFFFFD54F) : const Color(0xFFFFFFFF),
        size: crit ? 17 : 13));
    if (m.hp <= 0) {
      killMonster(m);
    } else {
      particles.add(Particle(
          x: m.x, y: m.y,
          vx: (rng.nextDouble() - 0.5) * 90,
          vy: (rng.nextDouble() - 0.5) * 90,
          life: 0.25, size: 3, color: const Color(0x80FFFFFF)));
    }  }

  void killMonster(Monster m) {
    m.dead = true;
    kills++;
    if (m.isBoss) {
      hitStop = 0.1;
      shake = 14;
      // Boss 击杀后若无其他 Boss 存活，切回战斗 BGM
      if (!monsters.any((o) => o.isBoss && !o.dead)) {
        AudioManager.I.playBgm('bgm.mp3');
      }
    } else if (m.isElite) {
      hitStop = 0.05;
      shake = 8;
    }
    AudioManager.I.play('sfx_kill', file: 'sfx_kill.ogg');
    final wealth = player.passiveLevel(PassiveType.wealth);
    final g = (m.gold * (1 + 0.20 * wealth)).round();
    gold += g;
    // 击杀直接获得经验（不掉落经验宝石）
    player.xp += m.xp * player.xpMult();
    floatTexts.add(FloatText(
        x: m.x, y: m.y - m.radius - 20, text: '+${m.xp}',
        color: const Color(0xFF90CAF9), size: 11));
    if (rng.nextDouble() < kGoldDropChance) {
      pickups.add(Pickup(
          x: m.x + (rng.nextDouble() - 0.5) * 24,
          y: m.y + (rng.nextDouble() - 0.5) * 24,
          value: g,
          kind: 'gold'));
    }
    if (rng.nextDouble() <
        (m.isBoss ? 1.0 : m.isElite ? 0.5 : kHeartDropChance)) {
      pickups.add(Pickup(x: m.x, y: m.y, value: 1, kind: 'heart'));
    }
    // 临时增益道具掉落
    final buffChance = m.isBoss
        ? kBuffDropChanceBoss
        : m.isElite
            ? kBuffDropChanceElite
            : kBuffDropChance;
    if (rng.nextDouble() < buffChance) {
      const buffKinds = ['shield', 'power', 'haste'];
      pickups.add(Pickup(
          x: m.x, y: m.y, value: 1, kind: buffKinds[rng.nextInt(buffKinds.length)]));
    }
    // 爆裂被动：击杀时小范围爆炸
    final explodeLv = player.passiveLevel(PassiveType.explode);
    if (explodeLv > 0) {
      for (final o in monsters) {
        if (o.dead || identical(o, m)) continue;
        if (dist(m.x, m.y, o.x, o.y) <= 70 * areaMult()) {
          damageMonster(o, 10.0 * explodeLv * player.damageMult(), crit: false, kb: 40);
        }
      }
    }
    for (int i = 0; i < 8; i++) {
      particles.add(Particle(
          x: m.x, y: m.y,
          vx: (rng.nextDouble() - 0.5) * 180,
          vy: (rng.nextDouble() - 0.5) * 180,
          life: 0.4, size: 3.5, color: m.color));
    }
  }

  void hurtPlayer(double dmg, {required double fromX, required double fromY}) {
    if (player.invuln > 0) return;
    // 闪避：概率免疫伤害
    if (rng.nextDouble() < 0.05 * player.passiveLevel(PassiveType.evade)) {
      player.invuln = 0.2;
      return;
    }
    // 荆棘护盾：受击反伤最近的敌人
    final thornLv = player.weaponLevel(WeaponType.thorns);
    if (thornLv > 0) {
      final tp = thornsParam(thornLv);
      Monster? attacker;
      double best = tp.range;
      for (final m in monsters) {
        if (m.dead) continue;
        final d = dist(fromX, fromY, m.x, m.y);
        if (d < best) {
          best = d;
          attacker = m;
        }
      }
      if (attacker != null) {
        damageMonster(attacker, tp.dmg * player.damageMult(), crit: rollCrit(), kb: 60);
      }
    }
    if (player.shieldT > 0) {
      player.invuln = 0.4;
      floatTexts.add(FloatText(
          x: player.x, y: player.y - 24, text: '格挡',
          color: const Color(0xFF64B5F6), size: 15));
      return;
    }
    AudioManager.I.play('sfx_hurt', file: 'sfx_hurt.ogg', volume: 0.5);
    HapticFeedback.mediumImpact().catchError((_) {}); // 手机震动
    player.hp -= dmg;
    player.invuln = kPlayerInvuln;
    shake = 18;
    hurtT = 0.4;
    floatTexts.add(FloatText(
        x: player.x, y: player.y - 28,
        text: '-${dmg.toStringAsFixed(0)}',
        color: const Color(0xFFFF5252), size: 17));
    particles.add(Particle(
        x: player.x, y: player.y, vx: 0, vy: 0, life: 0.4, size: 14,
        color: const Color(0xFFFF1744)));
    if (player.hp <= 0) {
      player.hp = 0;
      gameOver();
    }
  }

  // ---------- 怪物 ----------
  void updateMonsters(double dt) {
    final px = player.x, py = player.y;
    for (final m in monsters) {
      if (m.dead) continue;
      m.hitTimer = max(0, m.hitTimer - dt);
      m.contactTimer = max(0, m.contactTimer - dt);
      m.orbitCd = max(0, m.orbitCd - dt);
      m.slow = max(0, m.slow - dt);
      m.stun = max(0, m.stun - dt);
      final d = dist(m.x, m.y, px, py);
      final spd = m.speed * monsterSpeedMult(time) * (1 + (player.level - 1) * 0.01) *
          (m.slow > 0 ? 0.45 : 1.0);
      if (d > 1 && m.stun <= 0) {
        final ang = atan2(py - m.y, px - m.x) + sin(m.wobble) * 0.25;
        m.x += cos(ang) * spd * dt;
        m.y += sin(ang) * spd * dt;
      }
      m.wobble += dt * (m.isBoss ? 3 : 6);
      // 远程怪射击
      if (m.kind == MonsterKind.archer && m.stun <= 0) {
        m.shotCd -= dt;
        if (m.shotCd <= 0 && d <= kArcherRange) {
          m.shotCd = kArcherShotInterval;
          final ang = atan2(py - m.y, px - m.x);
          projectiles.add(Projectile(
              x: m.x, y: m.y,
              vx: cos(ang) * kArcherShotSpeed, vy: sin(ang) * kArcherShotSpeed,
              damage: m.damage * 0.8, radius: 4, pierce: 0, life: 2.5,
              crit: false, hostile: true));
        }
      }

      // 环绕剑伤害
      if (player.weaponLevel(WeaponType.orbit) > 0) {
        final o = orbitParam(player.weaponLevel(WeaponType.orbit));
        final n = o.count;
        for (int i = 0; i < n; i++) {
          final a = orbitAngle + i * 2 * pi / n;
          final ox = px + cos(a) * o.radius;
          final oy = py + sin(a) * o.radius;
          if (dist(ox, oy, m.x, m.y) <= m.radius + 7 && m.orbitCd <= 0) {
            m.orbitCd = 0.35;
            damageMonster(m, o.dmg * player.damageMult(),
                crit: rollCrit(), kb: 20);
          }
        }
      }

      // 接触伤害
      if (d <= m.radius + player.radius() &&
          m.contactTimer <= 0 &&
          time >= kGracePeriod) {
        m.contactTimer = 0.8;
        hurtPlayer(m.damage, fromX: m.x, fromY: m.y);
        if (m.kind == MonsterKind.iceling) {
          player.slow = max(player.slow, kIceSlowTime);
        } else if (m.kind == MonsterKind.fireling) {
          player.burn = max(player.burn, kFireBurnTime);
        }
      }
      // Boss 技能：预警圈后范围伤害，放完进入虚弱
      if (m.isBoss) {
        m.weakT = max(0, m.weakT - dt);
        m.bossDropTimer -= dt;
        if (m.bossDropTimer <= 0) {
          m.bossDropTimer = 12;
          const buffKinds = ['shield', 'power', 'haste'];
          pickups.add(Pickup(x: m.x, y: m.y, value: 1, kind: buffKinds[rng.nextInt(3)]));
        }
        if (m.skillWarn > 0) {
          m.skillWarn -= dt;
          if (m.skillWarn <= 0) {
            m.weakT = 3.0; // 放完技能虚弱
            if (dist(m.x, m.y, px, py) <= 240) {
              hurtPlayer(m.damage * 0.9, fromX: m.x, fromY: m.y);
            }
            for (int i = 0; i < 20; i++) {
              final a = i / 20 * 2 * pi;
              particles.add(Particle(
                  x: m.x + cos(a) * 240,
                  y: m.y + sin(a) * 240,
                  vx: cos(a) * -120,
                  vy: sin(a) * -120,
                  life: 0.5,
                  size: 3.5,
                  color: const Color(0xFFFF5252)));
            }
          }
        } else {
          m.skillTimer -= dt;
          if (m.skillTimer <= 0) {
            m.skillTimer = 4.0;
            m.skillWarn = 0.9;
          }
        }
      }
    }
  }

  void updateProjectiles(double dt) {
    for (final p in projectiles) {
      if (p.boomerang) {
        p.traveled += p.speed * dt;
        if (!p.returning && p.traveled >= p.range) p.returning = true;
        if (p.returning) {
          final a = atan2(player.y - p.y, player.x - p.x);
          p.vx = cos(a) * p.speed;
          p.vy = sin(a) * p.speed;
          final rr = player.radius() + 10;
          final ddx = p.x - player.x, ddy = p.y - player.y;
          if (ddx * ddx + ddy * ddy <= rr * rr) p.life = 0;
        }
      }
      if (p.homing) {
        final t = nearestMonster(900);
        if (t != null) {
          final a = atan2(t.y - p.y, t.x - p.x);
          p.vx = cos(a) * p.speed;
          p.vy = sin(a) * p.speed;
        }
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) continue;
      if (p.hostile) {
        final pr = player.radius() + 4;
        final dx = p.x - player.x, dy = p.y - player.y;
        if (dx * dx + dy * dy <= pr * pr) {
          hurtPlayer(p.damage, fromX: p.x, fromY: p.y);
          p.life = 0;
        }
        continue;
      }
      for (final m in monsters) {
        if (m.dead) continue;
        final r = m.radius + p.radius;
        final dx = p.x - m.x, dy = p.y - m.y;
        if (dx * dx + dy * dy <= r * r) {
          damageMonster(m, p.damage, crit: p.crit, kb: 34);
          p.pierceUsed++;
          if (p.pierceUsed > p.pierce) {
            p.life = 0;
            break;
          }
        }
      }
    }
  }

  // ---------- 拾取 ----------
  void updatePickups(double dt) {
    final mag = player.magnetRange();
    for (final pk in pickups) {
      if (pk.collected) continue;
      final d = dist(pk.x, pk.y, player.x, player.y);
      if (d <= mag) {
        final ang = atan2(player.y - pk.y, player.x - pk.x);
        pk.x += cos(ang) * kPickupSpeed * dt;
        pk.y += sin(ang) * kPickupSpeed * dt;
      }
      if (dist(pk.x, pk.y, player.x, player.y) <= player.radius() + 9) {
        pk.collected = true;
        switch (pk.kind) {
          case 'xp':
            player.xp += pk.value * player.xpMult();
            break;
          case 'gold':
            gold += pk.value;
            break;
          case 'heart':
            player.heal(30);
            AudioManager.I.play('sfx_heal');
            break;
          case 'shield':
            player.shieldT = max(player.shieldT, kShieldDuration);
            AudioManager.I.play('sfx_pickup');
            floatTexts.add(FloatText(
                x: player.x, y: player.y - 22, text: '护盾！',
                color: const Color(0xFF64B5F6), size: 16));
            break;
          case 'power':
            player.powerT = max(player.powerT, kPowerDuration);
            AudioManager.I.play('sfx_pickup');
            floatTexts.add(FloatText(
                x: player.x, y: player.y - 22, text: '爆发！',
                color: const Color(0xFFFF8A65), size: 16));
            break;
          case 'haste':
            player.hasteT = max(player.hasteT, kHasteDuration);
            AudioManager.I.play('sfx_pickup');
            floatTexts.add(FloatText(
                x: player.x, y: player.y - 22, text: '疾风！',
                color: const Color(0xFFFFD54F), size: 16));
            break;
        }
      }
    }
  }

  void updateFx(double dt) {
    for (final pt in particles) {
      pt.x += pt.vx * dt;
      pt.y += pt.vy * dt;
      pt.life -= dt;
    }
    for (final ft in floatTexts) {
      ft.y -= 42 * dt;
      ft.life -= dt;
    }
  }

  void cleanup() {
    monsters.removeWhere((m) => m.dead);
    projectiles.removeWhere((p) => p.life <= 0);
    pickups.removeWhere((p) => p.collected);
    if (particles.length > 360) particles.removeRange(0, particles.length - 360);
    if (floatTexts.length > 40) floatTexts.removeRange(0, floatTexts.length - 40);
    particles.removeWhere((p) => p.life <= 0);
    floatTexts.removeWhere((f) => f.life <= 0);
  }

  // ---------- 生成 ----------
  void spawning(double dt) {
    // Boss 存活时暂停生成新怪，击杀后再继续
    final hasBoss = monsters.any((m) => m.isBoss && !m.dead);
    if (hasBoss) return;
    spawnTimer -= dt;
    if (spawnTimer <= 0) {
      spawnTimer = spawnInterval(time);
      final count = spawnCount(time);
      for (int i = 0; i < count; i++) {
        spawnMonster();
      }
    }
    bossTimer -= dt;
    if (bossTimer <= 0) {
      bossTimer = kBossEvery;
      spawnMonster(boss: true);
    }
    eliteTimer -= dt;
    if (eliteTimer <= 0) {
      eliteTimer = kEliteEvery;
      spawnMonster(elite: true);
    }
  }

  void spawnMonster({bool boss = false, bool elite = false}) {
    if (monsters.length >= 240) return; // 上限防止后期卡顿
    MonsterKind kind;
    if (boss) {
      const bossKinds = [MonsterKind.golem, MonsterKind.wolf, MonsterKind.ghost];
      kind = bossKinds[bossCount % bossKinds.length];
      bossCount++;
      AudioManager.I.play('sfx_boss');
      AudioManager.I.playBgm('bgm_boss.wav'); // Boss 战紧张 BGM
    } else {
      kind = weightedKind(tierAt(time).weights);
    }
    final def = monsterDefs[kind]!;
    final dist_ = max(viewW, viewH) * 0.5 + 130;
    final ang = rng.nextDouble() * 2 * pi;
    final x = player.x + cos(ang) * dist_;
    final y = player.y + sin(ang) * dist_;
    var hp = def.hp * (1 + (player.level - 1) * 0.12) * (1 + time / 120);
    // 怪物伤害随玩家生命上限联动（约 4%-12% 生命/次），全程有挑战但不过分
    var dmg = player.maxHp * (def.damage / 170) * (1 + time / 330);
    var radius = def.radius;
    var xpMul = 1.0;
    var goldMul = 1.0;
    if (boss) {
      hp *= kBossHpMul;
      dmg *= kBossDmgMul;
      radius *= kBossRadiusMul;
      xpMul = kBossXpMul;
      goldMul = kBossGoldMul;
    } else if (elite) {
      hp *= kEliteHpMul;
      dmg *= kEliteDmgMul;
      radius *= kEliteRadiusMul;
      xpMul = kEliteXpMul;
      goldMul = kEliteGoldMul;
    }
    final mn = Monster(
        kind: kind,
        x: x,
        y: y,
        hp: hp,
        speed: def.speed,
        damage: dmg,
        radius: radius,
        xp: (def.xp * xpMul).round(),
        gold: (def.gold * goldMul).round(),
        color: def.color,
        elite: elite,
        boss: boss)
      ..level = player.level;
    if (kind == MonsterKind.archer) {
      mn.shotCd = rng.nextDouble() * kArcherShotInterval;
    }
    monsters.add(mn);
  }

  Tier tierAt(double t) {
    for (final tier in spawnTiers) {
      if (t < tier.until) return tier;
    }
    return spawnTiers.last;
  }

  MonsterKind weightedKind(Map<MonsterKind, double> weights) {
    double total = 0;
    for (final w in weights.values) {
      total += w;
    }
    double r = rng.nextDouble() * total;
    for (final e in weights.entries) {
      r -= e.value;
      if (r <= 0) return e.key;
    }
    return weights.keys.first;
  }

  Monster? nearestMonster(double maxDist) {
    Monster? best;
    double bd = maxDist;
    for (final m in monsters) {
      if (m.dead) continue;
      final d = dist(m.x, m.y, player.x, player.y);
      if (d < bd) {
        bd = d;
        best = m;
      }
    }
    return best;
  }

  // ---------- 升级选择 ----------
  List<UpgradeChoice> generateChoices() {
    final pool = <UpgradeChoice>[];
    for (final w in WeaponType.values) {
      final lv = player.weaponLevel(w);
      if (lv < weaponDefs[w]!.maxLevel) pool.add(UpgradeChoice.weapon(w, lv + 1));
    }
    for (final p in PassiveType.values) {
      final lv = player.passiveLevel(p);
      if (lv < passiveDefs[p]!.maxLevel) pool.add(UpgradeChoice.passive(p, lv + 1));
    }
    pool.add(UpgradeChoice.heal());
    pool.add(UpgradeChoice.maxhp());

    double weightOf(UpgradeChoice c) => switch (c.kind) {
          ChoiceKind.weapon => player.weapons.length < 3 ? 3.6 : 1.6,
          ChoiceKind.passive => player.passives.length < 3 ? 2.2 : 1.2,
          ChoiceKind.heal => 0.7,
          ChoiceKind.maxhp => 0.7,
        };

    final avail = List<UpgradeChoice>.of(pool);
    final result = <UpgradeChoice>[];
    while (result.length < 3 && avail.isNotEmpty) {
      double total = 0;
      for (final c in avail) {
        total += weightOf(c);
      }
      double r = rng.nextDouble() * total;
      int idx = 0;
      for (int i = 0; i < avail.length; i++) {
        r -= weightOf(avail[i]);
        if (r <= 0) {
          idx = i;
          break;
        }
      }
      result.add(avail.removeAt(idx));
    }
    return result;
  }

  void applyChoice(UpgradeChoice c) {
    switch (c.kind) {
      case ChoiceKind.weapon:
        player.weapons[c.weapon!] = c.level;
        break;
      case ChoiceKind.passive:
        player.passives[c.passive!] = c.level;
        if (c.passive == PassiveType.hp) {
          player.addMaxHp(player.maxHp * 0.05); // 生命强化：按当前生命 5%
        }
        break;
      case ChoiceKind.heal:
        player.heal(player.maxHp * 0.5);
        break;
      case ChoiceKind.maxhp:
        player.addMaxHp(15);
        break;
    }
    phase = GamePhase.playing;
  }

  // ---------- 流程 ----------
  void startNewRun() {
    player
      ..x = 0
      ..y = 0
      ..hp = kPlayerHp
      ..maxHp = kPlayerHp
      ..level = 1
      ..xp = 0
      ..xpNeed = xpNeeded(1)
      ..invuln = 0
      ..facing = 0
      ..slow = 0
      ..burn = 0
      ..shieldT = 0
      ..powerT = 0
      ..hasteT = 0;
    player.weapons.clear();
    player.passives.clear();
    player.weapons[WeaponType.bolt] = 1; // 开局自带魔法飞弹
    player.metaHpL = meta.metaBought[0];
    player.metaSpeedL = meta.metaBought[1];
    player.metaPowerL = meta.metaBought[2];
    player.metaHasteL = meta.metaBought[3];
    player.metaCritL = meta.metaBought[4];
    player.metaLifestealL = meta.metaBought[5];
    player.skin = meta.selectedSkin;
    player.addMaxHp(0.20 * kPlayerHp * metaSum(player.metaHpL) +
        (player.skinDef.bonus == 'hp' ? player.skinDef.value : 0));
    _resetField();
    phase = GamePhase.playing;
  }

  bool continueRun() {
    final r = _store['run'];
    if (r == null) return false;
    player.x = 0;
    player.y = 0;
    player.level = (r['level'] ?? 1) as int;
    player.xp = ((r['xp'] ?? 0) as num).toDouble();
    player.xpNeed = (r['xpNeed'] ?? xpNeeded(player.level)) as int;
    player.maxHp = ((r['maxHp'] ?? kPlayerHp) as num).toDouble();
    player.hp = ((r['hp'] ?? player.maxHp) as num).toDouble();
    if (player.hp <= 0) player.hp = player.maxHp * 0.5;
    player.invuln = 0;
    player.facing = 0;
    player.slow = 0;
    player.burn = 0;
    player.shieldT = 0;
    player.powerT = 0;
    player.hasteT = 0;
    player.weapons.clear();
    player.passives.clear();
    player.metaHpL = meta.metaBought[0];
    player.metaSpeedL = meta.metaBought[1];
    player.metaPowerL = meta.metaBought[2];
    player.metaHasteL = meta.metaBought[3];
    player.metaCritL = meta.metaBought[4];
    player.metaLifestealL = meta.metaBought[5];
    player.skin = meta.selectedSkin;
    final wm = r['weapons'] as Map? ?? {};
    wm.forEach((k, v) {
      final t = _weaponByName(k as String);
      if (t != null) player.weapons[t] = v as int;
    });
    final pm = r['passives'] as Map? ?? {};
    pm.forEach((k, v) {
      final t = _passiveByName(k as String);
      if (t != null) player.passives[t] = v as int;
    });
    if (player.weapons.isEmpty) player.weapons[WeaponType.bolt] = 1;
    time = ((r['time'] ?? 0) as num).toDouble();
    kills = (r['kills'] ?? 0) as int;
    gold = ((r['gold'] ?? 0) as num).toDouble();
    _resetField();
    phase = GamePhase.playing;
    return true;
  }

  void _resetField() {
    monsters.clear();
    projectiles.clear();
    pickups.clear();
    particles.clear();
    floatTexts.clear();
    pendingChoices.clear();
    spawnTimer = 0.8;
    bossTimer = kBossEvery;
    eliteTimer = kEliteEvery;
    orbitAngle = 0;
    boltTimer = 0;
    axeTimer = 0;
    lightningTimer = 0;
    auraTick = 0;
    frostTimer = 0;
    homingTimer = 0;
    holyTimer = 0;
    laserTimer = 0;
    laserT = 0;
    lightningT = 0;
    lightningFx = [];
    axeT = 0;
    staffT = 0;
    fistT = 0;
    scytheTimer = 0;
    venomTimer = 0;
    gunTimer = 0;
    staffTimer = 0;
    bladeTimer = 0;
    swordTimer = 0;
    fistsTimer = 0;
    fistsSide = 0;
    venomZones.clear();
    bossCount = 0;
    reviveLeft = meta.monthlyCard ? kMonthlyRevives : kRevivePerRun;
    hitStop = 0;
    hurtT = 0;
    flash = 0;
    autosaveTimer = 0;
    shake = 0;
  }

  void gameOver() {
    phase = GamePhase.gameover;
    AudioManager.I.play('sfx_hurt');
    if (player.level > meta.bestLevel) meta.bestLevel = player.level;
    if (time > meta.bestTime) meta.bestTime = time;
    meta.gold += gold;
    saveMeta();
    clearRun();
  }

  // 死亡清档：意外退出才保留存档，死亡不算存档点
  void clearRun() {
    _store.remove('run');
    if (!debugNoSave) writeSave(jsonEncode(_store));
  }

  // 看广告复活：满血 + 清空身边敌人 + 短暂无敌
  void revive() {
    if (reviveLeft <= 0 || phase != GamePhase.gameover) return;
    reviveLeft--;
    player.hp = player.maxHp;
    player.invuln = 2.0;
    player.burn = 0;
    player.slow = 0;
    const clearR = 280.0;
    monsters.removeWhere((m) => dist(m.x, m.y, player.x, player.y) < clearR);
    projectiles.clear();
    pendingChoices.clear();
    phase = GamePhase.playing;
    AudioManager.I.play('sfx_heal');
  }

  // 看广告获得随机临时增益道具
  void grantBuff(String kind) {
    String label;
    if (kind == 'shield') {
      player.shieldT = max(player.shieldT, kShieldDuration);
      label = '护盾！';
    } else if (kind == 'power') {
      player.powerT = max(player.powerT, kPowerDuration);
      label = '爆发！';
    } else {
      player.hasteT = max(player.hasteT, kHasteDuration);
      label = '疾风！';
    }
    floatTexts.add(FloatText(
        x: player.x, y: player.y - 22, text: label,
        color: const Color(0xFFFFFFFF), size: 16));
    AudioManager.I.play('sfx_pickup');
  }

  bool hasRun() => _store['run'] != null;

  // ---------- 存档 ----------
  void saveRun() {
    _store['run'] = {
      'time': time,
      'kills': kills,
      'gold': gold,
      'level': player.level,
      'xp': player.xp,
      'xpNeed': player.xpNeed,
      'hp': player.hp,
      'maxHp': player.maxHp,
      'weapons': {for (final e in player.weapons.entries) e.key.name: e.value},
      'passives': {for (final e in player.passives.entries) e.key.name: e.value},
    };
    if (!debugNoSave) writeSave(jsonEncode(_store));
  }

  void saveMeta() {
    _store['meta'] = {
      'gold': meta.gold,
      'bestLevel': meta.bestLevel,
      'bestTime': meta.bestTime,
      'metaBought': meta.metaBought,
      'monthlyCard': meta.monthlyCard,
      'adsWatched': meta.adsWatched,
      'selectedSkin': meta.selectedSkin,
      'ownedSkins': meta.ownedSkins,
    };
    if (!debugNoSave) writeSave(jsonEncode(_store));
  }

  bool buyMeta(int index) {
    final cost = metaCost(index, meta.metaBought[index]);
    if (meta.gold < cost) return false;
    meta.gold -= cost;
    meta.metaBought[index]++;
    saveMeta();
    return true;
  }

  // 月卡：预留支付接口
  Future<bool> buyMonthlyCard() async {
    final ok = await paymentService.purchaseMonthlyCard();
    if (ok) {
      meta.monthlyCard = true;
      saveMeta();
    }
    return ok;
  }

  void selectSkin(int i) {
    if (meta.ownedSkins.contains(i)) {
      meta.selectedSkin = i;
      saveMeta();
    }
  }

  bool buySkin(int i) {
    if (meta.ownedSkins.contains(i)) return false;
    final s = skins[i];
    if (meta.gold < s.cost) return false;
    meta.gold -= s.cost;
    meta.ownedSkins.add(i);
    meta.selectedSkin = i;
    saveMeta();
    return true;
  }

  WeaponType? _weaponByName(String n) {
    for (final t in WeaponType.values) {
      if (t.name == n) return t;
    }
    return null;
  }

  PassiveType? _passiveByName(String n) {
    for (final t in PassiveType.values) {
      if (t.name == n) return t;
    }
    return null;
  }

  double dist(double x1, double y1, double x2, double y2) =>
      sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
}

/// 把屏幕坐标的按住点换算成世界目标并返回归一化移动方向；
/// 目标离玩家足够近时返回零向量（停住）。
Offset holdDirection(Offset playerPos, Offset holdScreen, double viewW, double viewH) {
  final dx = holdScreen.dx - viewW / 2;
  final dy = holdScreen.dy - viewH / 2;
  final d = sqrt(dx * dx + dy * dy);
  if (d < 26) return Offset.zero;
  return Offset(dx / d, dy / d);
}
