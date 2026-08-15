import 'dart:math';
import 'dart:ui';
import 'config.dart';

// ============ 实体类 ============

class Player {
  double x = 0, y = 0;
  double hp = kPlayerHp;
  double maxHp = kPlayerHp;
  int level = 1;
  double xp = 0;
  int xpNeed = xpNeeded(1);
  double facing = 0;
  double invuln = 0;
  int skin = 0; // 皮肤
  // 元养成等级（阶梯收益由 metaSum 计算）
  int metaHpL = 0, metaSpeedL = 0, metaPowerL = 0, metaHasteL = 0, metaCritL = 0, metaLifestealL = 0;
  double slow = 0; // 减速
  double burn = 0; // 灼烧剩余时间
  double shieldT = 0; // 护盾（免疫伤害）
  double powerT = 0; // 临时增伤
  double hasteT = 0; // 临时攻速/移速

  final Map<WeaponType, int> weapons = {};
  final Map<PassiveType, int> passives = {};

  SkinDef get skinDef => skins[skin.clamp(0, skins.length - 1)];
  double get _skinSpeed => skinDef.bonus == 'speed' ? skinDef.value : 0;
  double get _skinPower => skinDef.bonus == 'power' ? skinDef.value : 0;
  double get _skinLifesteal => skinDef.bonus == 'lifesteal' ? skinDef.value : 0;

  double moveSpeed() {
    final s = kPlayerSpeed *
        (1 + 0.08 * (passives[PassiveType.speed] ?? 0)) *
        (1 + 0.04 * metaSum(metaSpeedL) + _skinSpeed) *
        (slow > 0 ? 0.5 : 1) *
        (hasteT > 0 ? kSpeedBuffMult : 1);
    return s;
  }

  double damageMult() =>
      (1 + 0.15 * (passives[PassiveType.power] ?? 0)) *
      (1 + 0.08 * metaSum(metaPowerL) + _skinPower) *
      (powerT > 0 ? kPowerAtkMult : 1);

  double hasteMult() => max(0.4,
      (1 - 0.08 * (passives[PassiveType.haste] ?? 0)) * (1 - 0.03 * metaSum(metaHasteL)));

  double critChance() =>
      (kCritChance + 0.08 * (passives[PassiveType.crit] ?? 0) + 0.03 * metaSum(metaCritL))
          .clamp(0.05, 0.9);

  double lifesteal() =>
      0.03 * (passives[PassiveType.lifesteal] ?? 0) +
      0.02 * metaSum(metaLifestealL) +
      _skinLifesteal;

  // 再生：按最大生命百分比（阶梯收益，避免血量膨胀后 +2/s 无感）
  double regenPerSec() => maxHp * 0.015 * (passives[PassiveType.regen] ?? 0);

  double magnetRange() =>
      kPickupMagnetBase * (1 + 0.30 * (passives[PassiveType.magnet] ?? 0));

  double xpMult() => 1 + 0.10 * (passives[PassiveType.magnet] ?? 0);

  int weaponLevel(WeaponType w) => weapons[w] ?? 0;
  int passiveLevel(PassiveType p) => passives[p] ?? 0;

  // 体型随等级增大（最大 1.6 倍）
  double radius() {
    final f = 1 + (level - 1) * 0.03;
    return kPlayerRadius * (f.clamp(1.0, 1.6));
  }

  void heal(double amount) => hp = min(maxHp, hp + amount);

  void addMaxHp(double delta) {
    maxHp += delta;
    hp = min(maxHp, hp + delta);
  }
}

class Monster {
  final MonsterKind kind;
  double x, y;
  double hp, maxHp;
  double speed;
  double damage;
  double radius;
  final int xp;
  final int gold;
  final Color color;
  final bool elite;
  final bool boss;
  int level = 1;
  double shotCd = 0; // 远程怪射击冷却
  double stun = 0; // 眩晕剩余时间
  bool dead = false;
  double hitTimer = 0;
  double contactTimer = 0;
  double orbitCd = 0;
  double slow = 0;
  double skillTimer = 4.0; // Boss 技能冷却
  double skillWarn = 0; // Boss 技能预警倒计时
  double weakT = 0; // Boss 虚弱（受伤加深）
  double bossDropTimer = 8; // Boss 周期性掉道具
  double wobble = 0;

  Monster({
    required this.kind,
    required this.x,
    required this.y,
    required this.hp,
    required this.speed,
    required this.damage,
    required this.radius,
    required this.xp,
    required this.gold,
    required this.color,
    this.elite = false,
    this.boss = false,
  }) : maxHp = hp;

  bool get isElite => elite;
  bool get isBoss => boss;
}

class Projectile {
  double x, y, vx, vy;
  double damage, radius;
  int pierce;
  int pierceUsed = 0;
  double life;
  bool crit;
  bool homing;
  double speed;
  bool hostile; // 敌方弹（射向玩家）
  bool boomerang = false; // 回旋飞刀（往返）
  bool returning = false;
  double traveled = 0;
  double range = 0;
  Offset origin = Offset.zero;
  bool crescent = false; // 剑气（月牙形）
  double angle = 0;
  Projectile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.damage,
    required this.radius,
    required this.pierce,
    required this.life,
    required this.crit,
    this.homing = false,
    this.speed = 0,
    this.hostile = false,
    this.boomerang = false,
    this.range = 0,
    this.origin = Offset.zero,
    this.crescent = false,
    this.angle = 0,
  });
}

class VenomZone {
  double x, y, radius, timer, dmg;
  VenomZone({
    required this.x,
    required this.y,
    required this.radius,
    required this.timer,
    required this.dmg,
  });
}

class Pickup {
  double x, y;
  int value;
  String kind; // xp / gold / heart
  bool collected = false;
  Pickup({required this.x, required this.y, required this.value, required this.kind});
}

class Particle {
  double x, y, vx, vy, life, maxLife, size;
  Color color;
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.color,
  }) : maxLife = life;
}

class FloatText {
  double x, y, life, maxLife;
  String text;
  Color color;
  double size;
  FloatText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    required this.size,
  })  : life = 0.9,
        maxLife = 0.9;
}
