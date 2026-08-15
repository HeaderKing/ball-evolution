import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'audio.dart';
import 'config.dart';
import 'entities.dart';
import 'pay.dart';
import 'save.dart';

enum GamePhase { menu, playing, levelup, paused, gameover }

// 空间哈希网格：把怪物按格子组织，碰撞只查相邻格子，避免 O(n²)
class _SpatialGrid {
  static const double _cell = 64;
  final Map<int, List<Monster>> _cells = {};

  int _key(int cx, int cy) => (cx & 0xFFFF) << 16 | (cy & 0xFFFF);

  void clear() => _cells.clear();

  void add(Monster m) {
    final k = _key((m.x / _cell).floor(), (m.y / _cell).floor());
    (_cells[k] ??= []).add(m);
  }

  Iterable<Monster> query(double x, double y, double r) sync* {
    final minCx = ((x - r) / _cell).floor();
    final maxCx = ((x + r) / _cell).floor();
    final minCy = ((y - r) / _cell).floor();
    final maxCy = ((y + r) / _cell).floor();
    for (int cx = minCx; cx <= maxCx; cx++) {
      for (int cy = minCy; cy <= maxCy; cy++) {
        final list = _cells[_key(cx, cy)];
        if (list != null) yield* list;
      }
    }
  }
}

enum ChoiceKind { weapon, passive, heal, maxhp, evolve }

class UpgradeChoice {
  final ChoiceKind kind;
  final WeaponType? weapon;
  final PassiveType? passive;
  final int level;
  final EvolutionRecipe? evolve;
  UpgradeChoice.weapon(this.weapon, this.level)
      : kind = ChoiceKind.weapon,
        passive = null,
        evolve = null;
  UpgradeChoice.passive(this.passive, this.level)
      : kind = ChoiceKind.passive,
        weapon = null,
        evolve = null;
  UpgradeChoice.heal()
      : kind = ChoiceKind.heal,
        weapon = null,
        passive = null,
        level = 0,
        evolve = null;
  UpgradeChoice.maxhp()
      : kind = ChoiceKind.maxhp,
        weapon = null,
        passive = null,
        level = 0,
        evolve = null;
  UpgradeChoice.evolve(this.evolve)
      : kind = ChoiceKind.evolve,
        weapon = null,
        passive = null,
        level = 0;

  String title() => switch (kind) {
        ChoiceKind.weapon => '${weaponDefs[weapon!]!.name} Lv.$level',
        ChoiceKind.passive => passiveDefs[passive!]!.name,
        ChoiceKind.heal => '生命回复',
        ChoiceKind.maxhp => '生命上限提升',
        ChoiceKind.evolve => '进化：${weaponDefs[evolve!.result]!.name}',
      };

  String description() => switch (kind) {
        ChoiceKind.weapon => weaponDefs[weapon!]!.desc,
        ChoiceKind.passive => passiveDefs[passive!]!.desc,
        ChoiceKind.heal => '回复最大生命的 50%',
        ChoiceKind.maxhp => '生命上限 +15 并回复 15',
        ChoiceKind.evolve =>
          '${weaponDefs[evolve!.baseWeapon]!.name} 满级 + ${passiveDefs[evolve!.passive]!.name}',
      };

  int rarity() => switch (kind) {
        ChoiceKind.weapon => weaponDefs[weapon!]!.rarity,
        ChoiceKind.passive => passiveDefs[passive!]!.rarity,
        ChoiceKind.heal => 0,
        ChoiceKind.maxhp => 0,
        ChoiceKind.evolve => 3,
      };

  Color color() => switch (kind) {
        ChoiceKind.weapon => weaponDefs[weapon!]!.color,
        ChoiceKind.passive => const Color(0xFF90A4AE),
        ChoiceKind.heal => const Color(0xFFEF5350),
        ChoiceKind.maxhp => const Color(0xFFEC407A),
        ChoiceKind.evolve => const Color(0xFFFFD54F),
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
  bool seenTutorial = false; // 是否看过新手引导
  List<int> seenMonsters = []; // 已击杀过的怪物种类（图鉴解锁）
  String challengeDate = ''; // 每日挑战日期（YYYY-MM-DD）
  int challengeKills = 0; // 本日累计击杀
  int challengeMaxLevel = 0; // 本日最高等级
  int challengeTimeSec = 0; // 本日累计存活秒
  List<int> challengeDone = [0, 0, 0]; // 已完成领取的挑战
}

// 玩家设置（持久化）
class GameSettings {
  bool sound = true;
  double sfxVolume = 0.6;
  double bgmVolume = 0.32;
  bool vibration = true;
  bool screenShake = true;
  bool hitStop = true;
  bool damageNumbers = true;

  Map<String, dynamic> toJson() => {
        'sound': sound,
        'sfxVolume': sfxVolume,
        'bgmVolume': bgmVolume,
        'vibration': vibration,
        'screenShake': screenShake,
        'hitStop': hitStop,
        'damageNumbers': damageNumbers,
      };

  void fromJson(Map<String, dynamic> j) {
    sound = j['sound'] ?? true;
    sfxVolume = ((j['sfxVolume'] ?? 0.6) as num).toDouble().clamp(0, 1);
    bgmVolume = ((j['bgmVolume'] ?? 0.32) as num).toDouble().clamp(0, 1);
    vibration = j['vibration'] ?? true;
    screenShake = j['screenShake'] ?? true;
    hitStop = j['hitStop'] ?? true;
    damageNumbers = j['damageNumbers'] ?? true;
  }
}

class GameState {
  /// 测试开关：为 true 时只写内存，不落盘（避免污染真实存档）
  static bool debugNoSave = false;
  GamePhase phase = GamePhase.menu;
  final GameSettings settings = GameSettings();
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
  double frostBoltTimer = 0, gatlingTimer = 0, giantAxeTimer = 0, stormTimer = 0;
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
  final Map<WeaponType, double> weaponDmg = {}; // 本局每武器总伤害
  int bestCombo = 0; // 本局最长连杀
  int _combo = 0;

  List<UpgradeChoice> pendingChoices = [];
  double viewW = 800, viewH = 600;

  final _SpatialGrid _grid = _SpatialGrid();

  final Random rng = Random();
  Map<String, dynamic> _store = {};

  GameState() {
    final raw = readSave();
    if (raw != null && raw.isNotEmpty) {
      try {
        _store = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    final saveV = (_store['version'] ?? 1) as int;
    if (saveV < kSaveVersion) _migrateSave(saveV);
    _store['version'] = kSaveVersion;
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
      meta.seenTutorial = m['seenTutorial'] == true;
      final os = m['ownedSkins'];
      if (os is List) meta.ownedSkins = List<int>.from(os);
      if (!meta.ownedSkins.contains(0)) meta.ownedSkins.add(0);
      final sm = m['seenMonsters'];
      if (sm is List) meta.seenMonsters = List<int>.from(sm);
      meta.challengeDate = m['challengeDate'] ?? '';
      meta.challengeKills = (m['challengeKills'] ?? 0) as int;
      meta.challengeMaxLevel = (m['challengeMaxLevel'] ?? 0) as int;
      meta.challengeTimeSec = (m['challengeTimeSec'] ?? 0) as int;
      final cd = m['challengeDone'];
      if (cd is List) meta.challengeDone = List<int>.from(cd);
      while (meta.challengeDone.length < 3) {
        meta.challengeDone.add(0);
      }
    }
    final st = _store['settings'];
    if (st is Map<String, dynamic>) settings.fromJson(st);
    _checkDailyReset();
  }

  // 跨天自动重置每日挑战
  void _checkDailyReset() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (meta.challengeDate != today) {
      meta.challengeDate = today;
      meta.challengeKills = 0;
      meta.challengeMaxLevel = 0;
      meta.challengeTimeSec = 0;
      meta.challengeDone = [0, 0, 0];
    }
  }

  // 存档版本迁移。v1 → v2：新增字段（settings/挑战/图鉴/引导）由默认值兜底，
  // 无需额外转换；后续版本在此补充迁移逻辑。
  void _migrateSave(int from) {
    // 预留迁移钩子
  }

  // ---------- 主循环 ----------
  void update(double dt, Offset dir) {
    if (phase != GamePhase.playing || frozen) return;
    if (hitStop > 0) {
      hitStop -= dt;
      if (settings.hitStop) return;
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
    _rebuildGrid();
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
    if (player.weaponLevel(WeaponType.orbit) > 0 ||
        player.weaponLevel(WeaponType.holyOrbit) > 0) {
      orbitAngle += (player.weaponLevel(WeaponType.holyOrbit) > 0
              ? holyOrbitParam(player.weaponLevel(WeaponType.holyOrbit))
              : orbitParam(player.weaponLevel(WeaponType.orbit)))
          .angSpeed * dt;
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
            damageMonster(m, p.dmg * player.damageMult(), crit: false, kb: 0, source: WeaponType.aura);
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
    if (player.weaponLevel(WeaponType.frostBolt) > 0) {
      frostBoltTimer -= dt;
      while (frostBoltTimer <= 0) {
        final p = frostBoltParam(player.weaponLevel(WeaponType.frostBolt));
        frostBoltTimer += p.interval * haste;
        fireFrostBolt(p);
      }
    }
    if (player.weaponLevel(WeaponType.gatling) > 0) {
      gatlingTimer -= dt;
      while (gatlingTimer <= 0) {
        final p = gatlingParam(player.weaponLevel(WeaponType.gatling));
        gatlingTimer += p.interval * haste;
        fireGatling(p);
      }
    }
    if (player.weaponLevel(WeaponType.giantAxe) > 0) {
      giantAxeTimer -= dt;
      while (giantAxeTimer <= 0) {
        final p = giantAxeParam(player.weaponLevel(WeaponType.giantAxe));
        giantAxeTimer += p.interval * haste;
        fireGiantAxe(p);
      }
    }
    if (player.weaponLevel(WeaponType.storm) > 0) {
      stormTimer -= dt;
      while (stormTimer <= 0) {
        final p = stormParam(player.weaponLevel(WeaponType.storm));
        stormTimer += p.interval * haste;
        fireStorm(p);
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
          crit: rollCrit(),
          source: WeaponType.bolt));
    }
  }

  void fireAxe(AxeParam p, {WeaponType? src}) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('axe', 'sfx_axe');
    final rr = p.radius * areaMult();
    axeT = 0.3;
    axeAngle = rng.nextDouble() * 2 * pi;
    axeFxRadius = rr;
    for (final m in monsters) {
      if (m.dead) continue;
      if (dist(player.x, player.y, m.x, m.y) <= rr + m.radius) {
        damageMonster(m, dmg, crit: rollCrit(), kb: 90, source: src ?? WeaponType.axe);
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

  void fireLightning(LightningParam p, {WeaponType? src}) {
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
      damageMonster(m, dmg, crit: rollCrit(), kb: 30, source: src ?? WeaponType.lightning);
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
        damageMonster(m, dmg, crit: rollCrit(), kb: 40, source: WeaponType.frost);
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
          speed: spd,
          source: WeaponType.homing));
    }
  }

  void fireHoly(HolyParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('holy', 'sfx_holy');
    final r = p.radius * areaMult();
    for (final m in monsters) {
      if (m.dead) continue;
      if (dist(player.x, player.y, m.x, m.y) <= r + m.radius) {
        damageMonster(m, dmg, crit: rollCrit(), kb: 120, source: WeaponType.holy);
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
        damageMonster(m, dmg, crit: rollCrit(), kb: 20, source: WeaponType.laser);
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
      damageMonster(m, dmg, crit: rollCrit(), kb: 60, source: WeaponType.scythe);
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
          crit: rollCrit(), source: WeaponType.gun));
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
        damageMonster(m, dmg, crit: rollCrit(), kb: 160, source: WeaponType.staff);
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
          origin: Offset(player.x, player.y), source: WeaponType.blade));
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
          crit: rollCrit(), crescent: true, angle: a, source: WeaponType.sword));
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
        damageMonster(m, dmg, crit: rollCrit(), kb: 40, source: WeaponType.fists);
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

  // ===== 进化武器 =====
  void fireFrostBolt(BoltParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('frostBolt', 'sfx_bolt');
    final target = nearestMonster(480);
    double base = player.facing;
    if (target != null) base = atan2(target.y - player.y, target.x - player.x);
    for (int i = 0; i < p.count; i++) {
      final a = base + (i - (p.count - 1) / 2) * 0.14;
      projectiles.add(Projectile(
          x: player.x, y: player.y,
          vx: cos(a) * p.speed, vy: sin(a) * p.speed,
          damage: dmg, radius: 5.5 + p.lv * 0.35, pierce: p.pierce,
          life: 1.8, crit: rollCrit(), freeze: true, source: WeaponType.frostBolt));
    }
  }

  void fireGatling(GunParam p) {
    final dmg = p.dmg * player.damageMult();
    AudioManager.I.playWeapon('gatling', 'sfx_gun');
    final target = nearestMonster(520);
    final base = target != null
        ? atan2(target.y - player.y, target.x - player.x)
        : player.facing;
    final count = p.lv >= 5 ? 3 : 2;
    for (int i = 0; i < count; i++) {
      final a = base + (i - (count - 1) / 2) * 0.06;
      projectiles.add(Projectile(
          x: player.x, y: player.y,
          vx: cos(a) * p.speed, vy: sin(a) * p.speed,
          damage: dmg, radius: 4 + p.lv * 0.3, pierce: 1, life: 0.9,
          crit: rollCrit(), source: WeaponType.gatling));
    }
  }

  // 巨斧/风暴闪电：复用战斧/闪电链逻辑，数值由进化参数决定
  void fireGiantAxe(AxeParam p) => fireAxe(p, src: WeaponType.giantAxe);
  void fireStorm(LightningParam p) => fireLightning(p, src: WeaponType.storm);

  void updateVenom(double dt) {
    for (final z in venomZones) {
      z.timer -= dt;
      for (final m in monsters) {
        if (m.dead) continue;
        if (dist(z.x, z.y, m.x, m.y) <= z.radius + m.radius) {
          m.hitTimer = max(m.hitTimer, 0.1);
          weaponDmg[WeaponType.venom] =
              (weaponDmg[WeaponType.venom] ?? 0) + z.dmg * dt;
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
      {required bool crit, double kb = 50, WeaponType? source}) {
    if (m.dead) return;
    AudioManager.I.playHit();
    final critMult = kCritMult + 0.3 * player.passiveLevel(PassiveType.critDmg);
    var dmg = crit ? rawDmg * critMult : rawDmg;
    if (m.weakT > 0) dmg *= 1.5; // 虚弱：受伤加深 50%
    if (m.isBoss && m.stoneArmor > 0) dmg *= 0.3; // 磐石护体：减伤 70%
    if (source != null) {
      weaponDmg[source] = (weaponDmg[source] ?? 0) + dmg;
    }
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
    if (settings.damageNumbers) {
      floatTexts.add(FloatText(
          x: m.x + (rng.nextDouble() - 0.5) * 12,
          y: m.y - m.radius - 6,
          text: crit ? '${dmg.toStringAsFixed(0)}!' : dmg.toStringAsFixed(0),
          color: crit ? const Color(0xFFFFD54F) : const Color(0xFFFFFFFF),
          size: crit ? 17 : 13));
    }
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
    meta.challengeKills++; // 每日挑战：累计击杀
    _combo++;
    if (_combo > bestCombo) bestCombo = _combo;
    if (!meta.seenMonsters.contains(m.kind.index)) {
      meta.seenMonsters.add(m.kind.index); // 图鉴解锁
    }
    if (m.isBoss) {
      hitStop = 0.1;
      if (settings.screenShake) shake = 14;
      // Boss 击杀后若无其他 Boss 存活，切回战斗 BGM
      if (!monsters.any((o) => o.isBoss && !o.dead)) {
        AudioManager.I.playBgm('bgm.mp3');
      }
    } else if (m.isElite) {
      hitStop = 0.05;
      if (settings.screenShake) shake = 8;
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
        damageMonster(attacker, tp.dmg * player.damageMult(),
            crit: rollCrit(), kb: 60, source: WeaponType.thorns);
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
    if (settings.vibration) {
      HapticFeedback.mediumImpact().catchError((_) {}); // 手机震动
    }
    player.hp -= dmg;
    _combo = 0; // 受击打断连杀
    player.invuln = kPlayerInvuln;
    if (settings.screenShake) shake = 18;
    hurtT = 0.4;
    if (settings.damageNumbers) {
      floatTexts.add(FloatText(
          x: player.x, y: player.y - 28,
          text: '-${dmg.toStringAsFixed(0)}',
          color: const Color(0xFFFF5252), size: 17));
    }
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

      // 环绕剑伤害（含进化圣剑环绕）
      final orbitLv = player.weaponLevel(WeaponType.orbit);
      final holyLv = player.weaponLevel(WeaponType.holyOrbit);
      if (orbitLv > 0 || holyLv > 0) {
        final o = holyLv > 0 ? holyOrbitParam(holyLv) : orbitParam(orbitLv);
        final n = o.count;
        for (int i = 0; i < n; i++) {
          final a = orbitAngle + i * 2 * pi / n;
          final ox = px + cos(a) * o.radius;
          final oy = py + sin(a) * o.radius;
          if (dist(ox, oy, m.x, m.y) <= m.radius + 7 && m.orbitCd <= 0) {
            m.orbitCd = 0.35;
            damageMonster(m, o.dmg * player.damageMult(),
                crit: rollCrit(), kb: 20,
                source: holyLv > 0 ? WeaponType.holyOrbit : WeaponType.orbit);
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
      // Boss 专属技能（三 Boss 机制差异化）
      if (m.isBoss) {
        m.weakT = max(0, m.weakT - dt);
        m.stoneArmor = max(0, m.stoneArmor - dt);
        m.blinkT = max(0, m.blinkT - dt);
        m.bossDropTimer -= dt;
        if (m.bossDropTimer <= 0) {
          m.bossDropTimer = 12;
          const buffKinds = ['shield', 'power', 'haste'];
          pickups.add(Pickup(x: m.x, y: m.y, value: 1, kind: buffKinds[rng.nextInt(3)]));
        }
        _updateBossSkill(m, dt, px, py);
      }
    }
  }

  // ---------- Boss 专属技能 ----------
  void _updateBossSkill(Monster m, double dt, double px, double py) {
    // 狼王扑击：高速冲向玩家，路径上接触伤害
    if (m.pounceT > 0) {
      m.pounceT -= dt;
      m.x += m.pounceVx * dt;
      m.y += m.pounceVy * dt;
      if (dist(m.x, m.y, px, py) <= m.radius + player.radius() &&
          m.contactTimer <= 0) {
        m.contactTimer = 0.6;
        hurtPlayer(m.damage * 0.85, fromX: m.x, fromY: m.y);
      }
      if (rng.nextDouble() < 0.5) {
        particles.add(Particle(
            x: m.x + (rng.nextDouble() - 0.5) * m.radius,
            y: m.y + (rng.nextDouble() - 0.5) * m.radius,
            vx: -m.pounceVx * 0.15,
            vy: -m.pounceVy * 0.15,
            life: 0.3,
            size: 3,
            color: const Color(0xFFFFA726)));
      }
      return;
    }
    // 幽灵王冰环扩散
    if (m.iceRingR > 0) {
      m.iceRingR += 320 * dt;
      final dP = dist(m.x, m.y, px, py);
      const ringWidth = 30.0;
      if (dP <= m.iceRingR && dP > m.iceRingR - ringWidth) {
        player.slow = max(player.slow, 2.0);
        hurtPlayer(m.damage * 0.9, fromX: m.x, fromY: m.y);
      }
      if (m.iceRingR > 340) m.iceRingR = 0;
      return;
    }
    if (m.skillWarn > 0) {
      m.skillWarn -= dt;
      if (m.skillWarn <= 0) {
        m.weakT = 3.0; // 放完技能进入虚弱
        _execBossSkill(m, px, py);
      }
    } else {
      m.skillTimer -= dt;
      if (m.skillTimer <= 0) {
        m.skillTimer = 4.5;
        m.skillIdx = 1 - m.skillIdx; // 两个技能轮换
        _warnBossSkill(m, px, py);
      }
    }
  }

  void _warnBossSkill(Monster m, double px, double py) {
    switch (m.kind) {
      case MonsterKind.golem:
        if (m.skillIdx == 0) { // 震地
          m.warnRadius = 280;
          m.warnColor = const Color(0xFFFF5252);
          m.skillWarn = 0.9;
        } else { // 磐石护体
          m.warnRadius = m.radius + 14;
          m.warnColor = const Color(0xFF90CAF9);
          m.skillWarn = 0.6;
        }
        break;
      case MonsterKind.wolf:
        if (m.skillIdx == 0) { // 狼嚎
          m.warnRadius = 150;
          m.warnColor = const Color(0xFFFFA726);
          m.skillWarn = 0.8;
        } else { // 扑击（方向线预警）
          m.warnRadius = 0;
          m.warnColor = const Color(0xFFFF8A65);
          m.skillWarn = 0.6;
        }
        break;
      case MonsterKind.ghost:
        if (m.skillIdx == 0) { // 冰霜之环
          m.warnRadius = 180;
          m.warnColor = const Color(0xFF80DEEA);
          m.skillWarn = 0.8;
        } else { // 幻影瞬移
          m.warnRadius = m.radius + 14;
          m.warnColor = const Color(0xFFAB47BC);
          m.skillWarn = 0.7;
        }
        break;
      default:
        m.warnRadius = 240;
        m.warnColor = const Color(0xFFFF5252);
        m.skillWarn = 0.9;
    }
  }

  void _execBossSkill(Monster m, double px, double py) {
    switch (m.kind) {
      case MonsterKind.golem:
        if (m.skillIdx == 0) {
          // 震地：大范围重击 + 屏幕震动
          if (settings.screenShake) shake = max(shake, 24);
          AudioManager.I.play('sfx_boss');
          if (dist(m.x, m.y, px, py) <= m.warnRadius) {
            hurtPlayer(m.damage * 1.1, fromX: m.x, fromY: m.y);
          }
          for (int i = 0; i < 30; i++) {
            final a = i / 30 * 2 * pi;
            particles.add(Particle(
                x: m.x + cos(a) * m.warnRadius,
                y: m.y + sin(a) * m.warnRadius,
                vx: cos(a) * -160,
                vy: sin(a) * -160,
                life: 0.5,
                size: 3.6,
                color: const Color(0xFFFF5252)));
          }
        } else {
          // 磐石护体：4 秒大幅减伤
          m.stoneArmor = 4.0;
          for (int i = 0; i < 16; i++) {
            final a = i / 16 * 2 * pi;
            particles.add(Particle(
                x: m.x + cos(a) * (m.radius + 4),
                y: m.y + sin(a) * (m.radius + 4),
                vx: cos(a) * -60,
                vy: sin(a) * -60,
                life: 0.6,
                size: 3,
                color: const Color(0xFF90CAF9)));
          }
        }
        break;
      case MonsterKind.wolf:
        if (m.skillIdx == 0) {
          // 狼嚎：召唤一群小狼
          AudioManager.I.play('sfx_boss');
          for (int i = 0; i < 4; i++) {
            final a = rng.nextDouble() * 2 * pi;
            final r = 90 + rng.nextDouble() * 60;
            _spawnMinion(MonsterKind.wolf, m.x + cos(a) * r, m.y + sin(a) * r);
          }
          for (int i = 0; i < 14; i++) {
            final a = i / 14 * 2 * pi;
            particles.add(Particle(
                x: m.x + cos(a) * 150,
                y: m.y + sin(a) * 150,
                vx: cos(a) * -100,
                vy: sin(a) * -100,
                life: 0.4,
                size: 3,
                color: const Color(0xFFFFA726)));
          }
        } else {
          // 扑击：朝玩家高速突进
          final d = dist(m.x, m.y, px, py);
          if (d > 1) {
            m.pounceVx = (px - m.x) / d * 560;
            m.pounceVy = (py - m.y) / d * 560;
          } else {
            m.pounceVx = cos(player.facing) * 560;
            m.pounceVy = sin(player.facing) * 560;
          }
          m.pounceT = 0.75;
        }
        break;
      case MonsterKind.ghost:
        if (m.skillIdx == 0) {
          // 冰霜之环：扩散冰环减速玩家
          m.iceRingR = 20;
          AudioManager.I.play('sfx_bolt');
        } else {
          // 幻影瞬移：闪到玩家身边并范围伤害
          m.blinkT = 0.35;
          final a = rng.nextDouble() * 2 * pi;
          final r = 60 + rng.nextDouble() * 50;
          final nx = px + cos(a) * r, ny = py + sin(a) * r;
          for (int i = 0; i < 16; i++) {
            final aa = rng.nextDouble() * 2 * pi;
            particles.add(Particle(
                x: m.x + cos(aa) * m.radius,
                y: m.y + sin(aa) * m.radius,
                vx: cos(aa) * 150,
                vy: sin(aa) * 150,
                life: 0.4,
                size: 3.4,
                color: const Color(0xFFAB47BC)));
          }
          m.x = nx;
          m.y = ny;
          if (dist(nx, ny, px, py) <= 120) {
            hurtPlayer(m.damage * 0.9, fromX: nx, fromY: ny);
          }
          for (int i = 0; i < 16; i++) {
            final aa = rng.nextDouble() * 2 * pi;
            particles.add(Particle(
                x: nx + cos(aa) * m.radius,
                y: ny + sin(aa) * m.radius,
                vx: cos(aa) * 150,
                vy: sin(aa) * 150,
                life: 0.4,
                size: 3.4,
                color: const Color(0xFFAB47BC)));
          }
        }
        break;
      default:
        break;
    }
  }

  // 召唤类技能：在指定位置生成普通怪（不记 Boss 击杀）
  void _spawnMinion(MonsterKind kind, double x, double y) {
    if (monsters.length >= 240) return;
    final def = monsterDefs[kind]!;
    final hp = def.hp * (1 + (player.level - 1) * 0.12) * (1 + time / 120);
    final dmg = player.maxHp * (def.damage / 170) * (1 + time / 330);
    monsters.add(Monster(
        kind: kind,
        x: x,
        y: y,
        hp: hp,
        speed: def.speed,
        damage: dmg,
        radius: def.radius,
        xp: def.xp,
        gold: def.gold,
        color: def.color)
      ..level = player.level);
  }

  void _rebuildGrid() {
    _grid.clear();
    for (final m in monsters) {
      if (!m.dead) _grid.add(m);
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
      // 网格查询候选怪，避免全量双层循环
      for (final m in _grid.query(p.x, p.y, p.radius + 56)) {
        if (m.dead) continue;
        final r = m.radius + p.radius;
        final dx = p.x - m.x, dy = p.y - m.y;
        if (dx * dx + dy * dy <= r * r) {
          damageMonster(m, p.damage, crit: p.crit, kb: 34, source: p.source);
          if (p.freeze) m.slow = max(m.slow, 1.5); // 寒冰飞弹：命中冰冻减速
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
            AudioManager.I.playPickup();
            break;
          case 'gold':
            gold += pk.value;
            AudioManager.I.playPickup();
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
    // 进化配方：基础武器满级 + 指定被动达标 → 合成进化武器
    for (final ev in evolutions) {
      if (player.weaponLevel(ev.baseWeapon) >= ev.baseLevel &&
          player.passiveLevel(ev.passive) >= ev.passiveLevel &&
          player.weaponLevel(ev.result) == 0) {
        pool.add(UpgradeChoice.evolve(ev));
      }
    }

    double weightOf(UpgradeChoice c) => switch (c.kind) {
          ChoiceKind.weapon => player.weapons.length < 3 ? 3.6 : 1.6,
          ChoiceKind.passive => player.passives.length < 3 ? 2.2 : 1.2,
          ChoiceKind.heal => 0.7,
          ChoiceKind.maxhp => 0.7,
          ChoiceKind.evolve => 8.0,
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
    // 进化补偿：配方已满足则三选一必含一个进化选项，保证可见
    final evPool = pool.where((c) => c.kind == ChoiceKind.evolve).toList();
    if (evPool.isNotEmpty && !result.any((c) => c.kind == ChoiceKind.evolve)) {
      result[result.length - 1] = evPool[rng.nextInt(evPool.length)];
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
      case ChoiceKind.evolve:
        final ev = c.evolve!;
        player.weapons.remove(ev.baseWeapon); // 基础武器被进化武器取代
        player.weapons[ev.result] = 1;
        AudioManager.I.play('sfx_levelup', file: 'sfx_levelup.wav');
        floatTexts.add(FloatText(
            x: player.x, y: player.y - 30, text: '进化！${weaponDefs[ev.result]!.name}',
            color: const Color(0xFFFFD54F), size: 18));
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
    frostBoltTimer = 0;
    gatlingTimer = 0;
    giantAxeTimer = 0;
    stormTimer = 0;
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
    if (player.level > meta.challengeMaxLevel) meta.challengeMaxLevel = player.level;
    meta.challengeTimeSec += time.round();
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
      'seenTutorial': meta.seenTutorial,
      'seenMonsters': meta.seenMonsters,
      'challengeDate': meta.challengeDate,
      'challengeKills': meta.challengeKills,
      'challengeMaxLevel': meta.challengeMaxLevel,
      'challengeTimeSec': meta.challengeTimeSec,
      'challengeDone': meta.challengeDone,
    };
    _store['settings'] = settings.toJson();
    _store['version'] = kSaveVersion;
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

  // 每日挑战进度（0=击杀 1=等级 2=存活分钟）
  int challengeProgress(int i) => switch (i) {
        0 => meta.challengeKills,
        1 => meta.challengeMaxLevel,
        2 => meta.challengeTimeSec ~/ 60,
        _ => 0,
      };

  bool buyChallenge(int i) {
    if (i < 0 || i >= dailyChallenges.length) return false;
    if (meta.challengeDone[i] == 1) return false;
    if (challengeProgress(i) < dailyChallenges[i].target) return false;
    meta.challengeDone[i] = 1;
    meta.gold += dailyChallenges[i].reward;
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
