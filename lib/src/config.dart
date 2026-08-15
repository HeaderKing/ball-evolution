import 'dart:math' as math;
import 'dart:ui';

// ============ 全局平衡数值表 ============

// 存档结构版本号（改存档结构时递增并补充迁移逻辑）
const int kSaveVersion = 2;

// 玩家基础属性
const double kPlayerHp = 100;
const double kPlayerSpeed = 230;
const double kPlayerRadius = 16;
const double kPlayerInvuln = 0.7;

// 经验曲线：升到 level 所需经验
int xpNeeded(int level) => (12 + level * 4 + level * level * 0.6).round();

// 升级生命加成：阶梯增长（1-10 级 +100/级，11-20 +1000/级，21-30 +10000/级…）
double levelUpHp(int currentLevel) =>
    100 * math.pow(10, ((currentLevel - 1) ~/ 10)).toDouble();

// 世界难度曲线（随时间的部分；按玩家等级的部分在 state 中叠加）
double monsterHpMult(double t) => 1 + t / 60 * 0.28;
double monsterDmgMult(double t) => 1 + t / 100 * 0.22;
double monsterSpeedMult(double t) => 1 + t / 200 * 0.12;

// 怪物有效等级（随时间提升，用于显示）
int monsterLevel(double t) => 1 + (t / 60).floor();

// 品质（稀有度）
const List<Color> kRarityColors = [
  Color(0xFFB0BEC5), // 普通 灰
  Color(0xFF42A5F5), // 稀有 蓝
  Color(0xFFAB47BC), // 史诗 紫
  Color(0xFFFFB300), // 传说 橙
];
const List<String> kRarityNames = ['普通', '稀有', '史诗', '传说'];

// 武器类型
enum WeaponType { bolt, orbit, axe, lightning, aura, frost, homing, holy, laser, thorns, scythe, venom, gun, staff, blade, sword, fists, frostBolt, gatling, giantAxe, holyOrbit, storm }

class WeaponDef {
  final String name;
  final String desc;
  final Color color;
  final int maxLevel;
  final int rarity; // 0-3
  const WeaponDef(this.name, this.desc, this.color, this.maxLevel, this.rarity);
}

const Map<WeaponType, WeaponDef> weaponDefs = {
  WeaponType.bolt: WeaponDef('魔法飞弹', '向最近的敌人发射飞弹', Color(0xFF4FC3F7), 10, 0),
  WeaponType.orbit: WeaponDef('飞剑环绕', '环绕你的飞剑持续造成伤害', Color(0xFF9CCC65), 10, 2),
  WeaponType.axe: WeaponDef('旋转战斧', '周期性范围斩击', Color(0xFFEF5350), 10, 1),
  WeaponType.lightning: WeaponDef('闪电链', '闪电链式打击最近的敌人', Color(0xFFFFEE58), 10, 3),
  WeaponType.aura: WeaponDef('火焰光环', '灼烧周围所有敌人', Color(0xFFFF7043), 10, 1),
  WeaponType.frost: WeaponDef('冰霜新星', '冰爆造成伤害并减速', Color(0xFF4DD0E1), 10, 2),
  WeaponType.homing: WeaponDef('追踪飞弹', '发射自动追踪的飞弹', Color(0xFFF48FB1), 10, 2),
  WeaponType.holy: WeaponDef('神圣之光', '周期性大范围圣光净化', Color(0xFFFFF59D), 10, 3),
  WeaponType.laser: WeaponDef('穿透激光', '发射贯穿敌人的激光束', Color(0xFFFF5252), 10, 2),
  WeaponType.thorns: WeaponDef('荆棘护盾', '受击时反伤周围敌人', Color(0xFF66BB6A), 10, 1),
  WeaponType.scythe: WeaponDef('死神镰刀', '周期性向前方扇形横扫', Color(0xFF7E57C2), 10, 3),
  WeaponType.venom: WeaponDef('剧毒沼泽', '脚下留下持续毒圈', Color(0xFF9CCC65), 10, 2),
  WeaponType.gun: WeaponDef('火枪', '向最近的敌人快速连射', Color(0xFF90CAF9), 10, 1),
  WeaponType.staff: WeaponDef('旋风棍', '旋转横扫击退敌人', Color(0xFFA1887F), 10, 0),
  WeaponType.blade: WeaponDef('回旋飞刀', '投出往返的回旋飞刀', Color(0xFF80CBC4), 10, 2),
  WeaponType.sword: WeaponDef('剑气斩', '斩出穿透的月牙剑气', Color(0xFFB39DDB), 10, 2),
  WeaponType.fists: WeaponDef('铁拳', '左右交替重拳连打', Color(0xFFFF8A65), 10, 0),
  // ===== 进化武器（满级基础武器 + 指定被动合成）=====
  WeaponType.frostBolt: WeaponDef('寒冰飞弹', '魔法飞弹进化：命中附带冰冻减速', Color(0xFF4DD0E1), 10, 3),
  WeaponType.gatling: WeaponDef('加特林', '火枪进化：极限连射', Color(0xFF90CAF9), 10, 3),
  WeaponType.giantAxe: WeaponDef('巨斧', '战斧进化：超大范围斩击', Color(0xFFEF5350), 10, 3),
  WeaponType.holyOrbit: WeaponDef('圣剑环绕', '飞剑进化：圣光环绕', Color(0xFFFFF59D), 10, 3),
  WeaponType.storm: WeaponDef('风暴闪电', '闪电进化：天罚连闪', Color(0xFFFFEE58), 10, 3),
};

// 武器进化配方：满级武器 + 指定被动等级 → 合成进化武器
class EvolutionRecipe {
  final WeaponType baseWeapon;
  final int baseLevel;
  final PassiveType passive;
  final int passiveLevel;
  final WeaponType result;
  const EvolutionRecipe(this.baseWeapon, this.baseLevel, this.passive, this.passiveLevel, this.result);
}

const List<EvolutionRecipe> evolutions = [
  EvolutionRecipe(WeaponType.bolt, 10, PassiveType.crit, 3, WeaponType.frostBolt),
  EvolutionRecipe(WeaponType.gun, 10, PassiveType.haste, 3, WeaponType.gatling),
  EvolutionRecipe(WeaponType.axe, 10, PassiveType.area, 3, WeaponType.giantAxe),
  EvolutionRecipe(WeaponType.orbit, 10, PassiveType.power, 3, WeaponType.holyOrbit),
  EvolutionRecipe(WeaponType.lightning, 10, PassiveType.critDmg, 3, WeaponType.storm),
];

// 武器参数：按等级公式计算（伤害约 +15%/级，间隔递减；满级 10 星有觉醒加成）
double _pow(double base, double g, int lv) =>
    base * math.pow(g, lv - 1).toDouble() * (lv >= 10 ? 1.5 : 1);
double _clampD(double v, double a, double b) => v < a ? a : (v > b ? b : v);

class BoltParam { final double dmg, interval, speed; final int count, pierce; final int lv; const BoltParam(this.dmg, this.interval, this.speed, this.count, this.pierce, this.lv); }
BoltParam boltParam(int lv) => BoltParam(
    _pow(12, 1.16, lv),
    _clampD(0.6 * math.pow(0.96, lv - 1).toDouble(), 0.25, 0.6),
    410 + 10.0 * (lv - 1),
    1 + ((lv - 1) ~/ 3).clamp(0, 3),
    ((lv - 1) ~/ 3).clamp(0, 3),
    lv);

class OrbitParam { final double dmg; final int count; final double radius, angSpeed; const OrbitParam(this.dmg, this.count, this.radius, this.angSpeed); }
OrbitParam orbitParam(int lv) => OrbitParam(
    _pow(10, 1.15, lv),
    3 + ((lv - 1) ~/ 2).clamp(0, 4),
    66 + 5.0 * (lv - 1),
    2.4 + 0.15 * (lv - 1));

class AxeParam { final double dmg, radius, interval; const AxeParam(this.dmg, this.radius, this.interval); }
AxeParam axeParam(int lv) => AxeParam(
    _pow(22, 1.16, lv),
    110 + 6.0 * (lv - 1),
    _clampD(1.3 * math.pow(0.96, lv - 1).toDouble(), 0.6, 1.3));

class LightningParam { final double dmg, range, chainRange; final int chains; final double interval; const LightningParam(this.dmg, this.range, this.chainRange, this.chains, this.interval); }
LightningParam lightningParam(int lv) => LightningParam(
    _pow(18, 1.16, lv),
    300 + 8.0 * (lv - 1),
    170 + 6.0 * (lv - 1),
    2 + ((lv - 1) ~/ 3).clamp(0, 4),
    _clampD(1.6 * math.pow(0.97, lv - 1).toDouble(), 0.8, 1.6));

class AuraParam { final double dmg, radius; const AuraParam(this.dmg, this.radius); }
AuraParam auraParam(int lv) => AuraParam(_pow(6, 1.14, lv), 90 + 5.0 * (lv - 1));

class FrostParam { final double dmg, radius, interval; const FrostParam(this.dmg, this.radius, this.interval); }
FrostParam frostParam(int lv) => FrostParam(
    _pow(16, 1.16, lv),
    130 + 6.0 * (lv - 1),
    _clampD(2.4 * math.pow(0.97, lv - 1).toDouble(), 1.2, 2.4));

class HomingParam { final double dmg, speed, interval; final int count; final int lv; const HomingParam(this.dmg, this.speed, this.interval, this.count, this.lv); }
HomingParam homingParam(int lv) => HomingParam(
    _pow(9, 1.15, lv),
    300 + 8.0 * (lv - 1),
    _clampD(0.9 * math.pow(0.97, lv - 1).toDouble(), 0.4, 0.9),
    1 + ((lv - 1) ~/ 3).clamp(0, 3),
    lv);

class HolyParam { final double dmg, radius, interval; const HolyParam(this.dmg, this.radius, this.interval); }
HolyParam holyParam(int lv) => HolyParam(
    _pow(28, 1.17, lv),
    200 + 6.0 * (lv - 1),
    _clampD(3.2 * math.pow(0.97, lv - 1).toDouble(), 1.5, 3.2));

class LaserParam { final double dmg, interval, length, width; const LaserParam(this.dmg, this.interval, this.length, this.width); }
LaserParam laserParam(int lv) => LaserParam(
    _pow(15, 1.16, lv),
    _clampD(1.6 * math.pow(0.96, lv - 1).toDouble(), 0.8, 1.6),
    _clampD(360 + 14.0 * (lv - 1), 360, 720),
    _clampD(6 + 0.4 * (lv - 1), 6, 14));

class ThornsParam { final double dmg, range; const ThornsParam(this.dmg, this.range); }
ThornsParam thornsParam(int lv) => ThornsParam(
    _pow(13, 1.15, lv),
    _clampD(260 + 6.0 * (lv - 1), 260, 520));

class ScytheParam { final double dmg, radius, interval; final int hits; const ScytheParam(this.dmg, this.radius, this.interval, this.hits); }
ScytheParam scytheParam(int lv) => ScytheParam(
    _pow(20, 1.16, lv),
    150 + 6.0 * (lv - 1),
    _clampD(1.9 * math.pow(0.96, lv - 1).toDouble(), 0.9, 1.9),
    1 + ((lv - 1) ~/ 3).clamp(0, 3));

class VenomParam { final double dmg, radius, duration, interval; const VenomParam(this.dmg, this.radius, this.duration, this.interval); }
VenomParam venomParam(int lv) => VenomParam(
    _pow(8, 1.12, lv),
    _clampD(70 + 4.0 * (lv - 1), 70, 150),
    _clampD(3.0 + 0.3 * (lv - 1), 3.0, 6.0),
    _clampD(3.0 * math.pow(0.95, lv - 1).toDouble(), 1.2, 3.0));

class GunParam { final double dmg, interval, speed; final int lv; const GunParam(this.dmg, this.interval, this.speed, this.lv); }
GunParam gunParam(int lv) => GunParam(
    _pow(7, 1.16, lv),
    _clampD(0.22 * math.pow(0.95, lv - 1).toDouble(), 0.08, 0.22),
    520 + 8.0 * (lv - 1),
    lv);

class StaffParam { final double dmg, radius, interval; const StaffParam(this.dmg, this.radius, this.interval); }
StaffParam staffParam(int lv) => StaffParam(
    _pow(16, 1.15, lv),
    96 + 5.0 * (lv - 1),
    _clampD(0.7 * math.pow(0.95, lv - 1).toDouble(), 0.35, 0.7));

class BladeParam { final double dmg, speed, range, interval; final int count; final int lv; const BladeParam(this.dmg, this.speed, this.range, this.count, this.lv, this.interval); }
BladeParam bladeParam(int lv) => BladeParam(
    _pow(14, 1.16, lv),
    330 + 8.0 * (lv - 1),
    _clampD(330 + 10.0 * (lv - 1), 330, 620),
    1 + ((lv - 1) ~/ 3).clamp(0, 3),
    lv,
    _clampD(0.9 * math.pow(0.95, lv - 1).toDouble(), 0.5, 0.9));

class SwordParam { final double dmg, speed, interval; final int waves; final int lv; const SwordParam(this.dmg, this.speed, this.interval, this.waves, this.lv); }
SwordParam swordParam(int lv) => SwordParam(
    _pow(20, 1.16, lv),
    380 + 8.0 * (lv - 1),
    _clampD(1.6 * math.pow(0.96, lv - 1).toDouble(), 0.9, 1.6),
    1 + ((lv - 1) ~/ 3).clamp(0, 3),
    lv);

class FistsParam { final double dmg, radius, interval; const FistsParam(this.dmg, this.radius, this.interval); }
FistsParam fistsParam(int lv) => FistsParam(
    _pow(11, 1.15, lv),
    90 + 5.0 * (lv - 1),
    _clampD(0.4 * math.pow(0.95, lv - 1).toDouble(), 0.2, 0.4));

// ===== 进化武器参数（复用基础武器结构 + 增益）=====
BoltParam frostBoltParam(int lv) {
  final p = boltParam(lv);
  return BoltParam(p.dmg * 1.7, p.interval, p.speed, p.count, p.pierce, lv);
}

GunParam gatlingParam(int lv) {
  final p = gunParam(lv);
  return GunParam(p.dmg * 1.5, p.interval * 0.7, p.speed, lv);
}

AxeParam giantAxeParam(int lv) {
  final p = axeParam(lv);
  return AxeParam(p.dmg * 1.7, p.radius * 1.45, p.interval);
}

OrbitParam holyOrbitParam(int lv) {
  final p = orbitParam(lv);
  return OrbitParam(p.dmg * 1.6, p.count + 2, p.radius, p.angSpeed);
}

LightningParam stormParam(int lv) {
  final p = lightningParam(lv);
  return LightningParam(p.dmg * 1.6, p.range, p.chainRange, p.chains + 2, p.interval);
}

// 被动类型
enum PassiveType { hp, speed, power, haste, crit, lifesteal, magnet, regen, wealth, area, evade, critDmg, stun, explode }

class PassiveDef {
  final String name;
  final String desc;
  final int maxLevel; // 用极大值表示无限上限
  final int rarity;
  const PassiveDef(this.name, this.desc, this.maxLevel, this.rarity);
}

const int kPassiveInfinite = 999999;

const Map<PassiveType, PassiveDef> passiveDefs = {
  PassiveType.hp: PassiveDef('生命强化', '获得当前生命上限 5%', kPassiveInfinite, 0),
  PassiveType.speed: PassiveDef('迅捷', '移动速度 +8%', kPassiveInfinite, 0),
  PassiveType.power: PassiveDef('强攻', '伤害 +15%', kPassiveInfinite, 0),
  PassiveType.haste: PassiveDef('快手', '攻击间隔 -8%', kPassiveInfinite, 1),
  PassiveType.crit: PassiveDef('暴击', '暴击率 +8%', kPassiveInfinite, 1),
  PassiveType.lifesteal: PassiveDef('血吸', '攻击吸血 +3%', kPassiveInfinite, 2),
  PassiveType.magnet: PassiveDef('吸星', '拾取范围 +30% 经验 +10%', kPassiveInfinite, 2),
  PassiveType.regen: PassiveDef('再生', '每秒回复最大生命 1.5%', kPassiveInfinite, 2),
  PassiveType.wealth: PassiveDef('财源', '金币获取 +20%', kPassiveInfinite, 2),
  PassiveType.area: PassiveDef('范围', '范围伤害半径 +10%', kPassiveInfinite, 2),
  PassiveType.evade: PassiveDef('闪避', '5% 概率免疫伤害', kPassiveInfinite, 3),
  PassiveType.critDmg: PassiveDef('暴伤', '暴击伤害 +30%', kPassiveInfinite, 3),
  PassiveType.stun: PassiveDef('眩晕', '攻击 6% 概率眩晕敌人', kPassiveInfinite, 3),
  PassiveType.explode: PassiveDef('爆裂', '击杀时产生小范围爆炸', kPassiveInfinite, 3),
};

// 怪物类型
enum MonsterKind { slime, bat, skeleton, ghost, golem, wolf, archer, iceling, fireling }

class MonsterDef {
  final String name;
  final double hp, speed, damage, radius;
  final int xp, gold;
  final Color color;
  const MonsterDef(this.name, this.hp, this.speed, this.damage, this.radius, this.xp, this.gold, this.color);
}

const Map<MonsterKind, MonsterDef> monsterDefs = {
  MonsterKind.slime: MonsterDef('史莱姆', 20, 62, 8, 15, 1, 1, Color(0xFF66BB6A)),
  MonsterKind.bat: MonsterDef('蝙蝠', 14, 125, 6, 10, 1, 1, Color(0xFFAB47BC)),
  MonsterKind.skeleton: MonsterDef('骷髅', 42, 74, 12, 14, 2, 2, Color(0xFFB0BEC5)),
  MonsterKind.ghost: MonsterDef('幽灵', 32, 95, 10, 13, 2, 2, Color(0xFF80DEEA)),
  MonsterKind.golem: MonsterDef('石头人', 130, 42, 22, 22, 5, 5, Color(0xFF8D6E63)),
  MonsterKind.wolf: MonsterDef('恶狼', 36, 140, 14, 13, 3, 3, Color(0xFFFFA726)),
  MonsterKind.archer: MonsterDef('骷髅射手', 30, 72, 8, 13, 2, 2, Color(0xFFBCAAA4)),
  MonsterKind.iceling: MonsterDef('冰魔', 36, 92, 10, 13, 3, 2, Color(0xFF80DEEA)),
  MonsterKind.fireling: MonsterDef('火魔', 34, 98, 10, 12, 3, 2, Color(0xFFFF7043)),
};

// 各时间段的怪物组成：按权重抽取
class Tier {
  final double until;
  final Map<MonsterKind, double> weights;
  const Tier(this.until, this.weights);
}
const List<Tier> spawnTiers = [
  Tier(60, {MonsterKind.slime: 6, MonsterKind.bat: 3}),
  Tier(180, {MonsterKind.slime: 3, MonsterKind.bat: 3, MonsterKind.skeleton: 3, MonsterKind.ghost: 2, MonsterKind.archer: 2}),
  Tier(360, {MonsterKind.bat: 2, MonsterKind.skeleton: 3, MonsterKind.ghost: 2, MonsterKind.golem: 2, MonsterKind.wolf: 2, MonsterKind.archer: 3, MonsterKind.iceling: 2, MonsterKind.fireling: 2}),
  Tier(1e9, {MonsterKind.skeleton: 2, MonsterKind.ghost: 2, MonsterKind.golem: 3, MonsterKind.wolf: 2, MonsterKind.archer: 3, MonsterKind.iceling: 3, MonsterKind.fireling: 3}),
];

// 生成节奏
double spawnInterval(double t) {
  if (t < 60) return 0.7;
  if (t < 180) return 0.5;
  if (t < 420) return 0.38;
  return 0.26;
}
int spawnCount(double t) => t < 60 ? 1 : (t < 180 ? 1 : (t < 420 ? 2 : 3));

// 精英/Boss
const double kEliteEvery = 45;
const double kEliteHpMul = 2.4, kEliteDmgMul = 1.3, kEliteXpMul = 3.0, kEliteGoldMul = 3.0, kEliteRadiusMul = 1.35;
const double kBossEvery = 180;
const double kBossHpMul = 8, kBossDmgMul = 1.3, kBossXpMul = 15, kBossGoldMul = 20, kBossRadiusMul = 2.2;

// 拾取物
const double kGemRadius = 6, kGoldRadius = 7, kHeartRadius = 8;
const double kPickupMagnetBase = 90;
const double kPickupSpeed = 420;

// 掉落概率
const double kHeartDropChance = 0.04;
const double kGoldDropChance = 0.9;

// 暴击基础
const double kCritChance = 0.05;
const double kCritMult = 2.0;

// 元养成（永久加成，金币购买；收益随等级阶梯上升）
class MetaUpgradeDef {
  final String name;
  final String desc;
  final int baseCost;
  const MetaUpgradeDef(this.name, this.desc, this.baseCost);
}
const metaUpgrades = [
  MetaUpgradeDef('生命祝福', '生命上限 +20%×Σ级（按基础生命）', 60),
  MetaUpgradeDef('风之祝福', '移动速度随等级阶梯提升（+4%×Σ级）', 80),
  MetaUpgradeDef('力之祝福', '伤害随等级阶梯提升（+8%×Σ级）', 80),
  MetaUpgradeDef('快手祝福', '攻速随等级阶梯提升（+3%×Σ级）', 100),
  MetaUpgradeDef('暴击祝福', '暴击率随等级阶梯提升（+3%×Σ级）', 120),
  MetaUpgradeDef('吸血祝福', '吸血随等级阶梯提升（+2%×Σ级）', 150),
];
int metaCost(int index, int bought) =>
    (metaUpgrades[index].baseCost * math.pow(1.6, bought)).round();
// 1..level 之和：让每级收益递增（阶梯上升）
int metaSum(int level) => level * (level + 1) ~/ 2;

// 看广告金币：随累计观看次数阶梯上升
const int kAdCoinsBase = 100;
const int kAdCoinsMax = 1000;

// 月卡
const double kMonthlyCardPrice = 18.8;
const int kMonthlyRevives = 3;

// 皮肤（特殊状态/加成）
class SkinDef {
  final String name;
  final Color color;
  final String desc;
  final String bonus; // none/power/hp/speed/lifesteal
  final double value;
  final int cost; // 0 = 免费
  const SkinDef(this.name, this.color, this.desc, this.bonus, this.value, this.cost);
}
const List<SkinDef> skins = [
  SkinDef('默认球', Color(0xFF64B5F6), '无加成', 'none', 0, 0),
  SkinDef('烈焰球', Color(0xFFFF7043), '伤害 +8%', 'power', 0.08, 300),
  SkinDef('冰晶球', Color(0xFF4DD0E1), '生命上限 +50', 'hp', 50, 300),
  SkinDef('紫电球', Color(0xFFAB47BC), '移动速度 +6%', 'speed', 0.06, 500),
  SkinDef('圣光球', Color(0xFFFFF176), '吸血 +4%', 'lifesteal', 0.04, 800),
];

// 新手保护：开局 6 秒怪物不主动靠近
const double kGracePeriod = 6.0;

// Boss 技能表（血条下方展示，点击查看详情）
class BossSkillDef {
  final String name;
  final String desc;
  const BossSkillDef(this.name, this.desc);
}
const Map<MonsterKind, List<BossSkillDef>> bossSkills = {
  MonsterKind.golem: [
    BossSkillDef('震地', '蓄力后对周围 240 范围造成重击'),
    BossSkillDef('磐石护体', '短时间大幅减伤'),
  ],
  MonsterKind.wolf: [
    BossSkillDef('狼嚎', '召唤一群小狼助战'),
    BossSkillDef('扑击', '快速突进并撕咬'),
  ],
  MonsterKind.ghost: [
    BossSkillDef('冰霜之环', '释放冰环冻结周围的敌人'),
    BossSkillDef('幻影瞬移', '闪现到玩家身边'),
  ],
};

// 临时增益道具
const double kBuffDropChance = 0.035;
const double kBuffDropChanceElite = 0.5;
const double kBuffDropChanceBoss = 1.0;
const double kShieldDuration = 5.0;
const double kPowerDuration = 6.0;
const double kHasteDuration = 6.0;
const double kPowerAtkMult = 1.5;
const double kHasteAtkMult = 0.7; // 攻速乘数（小于 1 更快）
const double kSpeedBuffMult = 1.25;
const int kAdCoinsReward = 120; // 看广告获得金币数
const int kRevivePerRun = 1; // 每局可看广告复活的次数

// 每日挑战（每天重置；target 单位：击杀数/等级/分钟）
class DailyChallengeDef {
  final String name;
  final String desc;
  final int target;
  final int reward;
  const DailyChallengeDef(this.name, this.desc, this.target, this.reward);
}
const List<DailyChallengeDef> dailyChallenges = [
  DailyChallengeDef('猎杀', '本日累计击杀怪物', 300, 200),
  DailyChallengeDef('登峰', '本日达到的最高等级', 20, 150),
  DailyChallengeDef('生存', '本日累计存活分钟', 15, 200),
];

// 弓箭手（远程怪）
const double kArcherRange = 320;
const double kArcherShotInterval = 2.5;
const double kArcherShotSpeed = 320;

// 冰魔 / 火魔异常状态
const double kIceSlowTime = 2.0;
const double kFireBurnTime = 3.0;
const double kBurnDps = 4.0;