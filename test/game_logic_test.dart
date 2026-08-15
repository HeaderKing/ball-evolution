import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dark_slash/src/config.dart';
import 'package:dark_slash/src/entities.dart';
import 'package:dark_slash/src/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GameState.debugNoSave = true;

  test('new run starts playing', () {
    final g = GameState();
    expect(g.phase, GamePhase.menu);
    g.startNewRun();
    expect(g.phase, GamePhase.playing);
    expect(g.player.level, 1);
    expect(g.player.weaponLevel(WeaponType.bolt), 1); // 开局自带魔法飞弹
  });

  test('monsters spawn over time', () {
    final g = GameState()..startNewRun();
    for (int i = 0; i < 40; i++) {
      g.update(0.05, Offset.zero);
    }
    expect(g.monsters.length, greaterThan(0));
  });

  test('kill grants kills, gold and direct xp', () {
    final g = GameState()..startNewRun();
    g.player.weapons[WeaponType.bolt] = 1;
    g.monsters.add(Monster(
        kind: MonsterKind.slime, x: 40, y: 0, hp: 10, speed: 0, damage: 0,
        radius: 10, xp: 1, gold: 1, color: const Color(0xFF66BB6A)));
    for (int i = 0; i < 150; i++) {
      g.update(0.05, Offset.zero);
    }
    expect(g.kills, greaterThan(0));
    expect(g.gold, greaterThan(0));
    expect(g.player.xp, greaterThan(0)); // 击杀直接获得经验
  });

  test('level up pauses and yields exactly 3 choices', () {
    final g = GameState()..startNewRun();
    g.player.xp = g.player.xpNeed - 1;
    g.pickups.add(Pickup(x: 5, y: 0, value: 2, kind: 'xp'));
    for (int i = 0; i < 30; i++) {
      g.update(0.05, Offset.zero);
    }
    expect(g.phase, GamePhase.levelup);
    expect(g.pendingChoices.length, 3);
    final c = g.pendingChoices.first;
    g.applyChoice(c);
    expect(g.phase, GamePhase.playing);
  });

  test('hurtPlayer respects i-frames then triggers gameover', () {
    final g = GameState()..startNewRun();
    g.hurtPlayer(30, fromX: 100, fromY: 0);
    expect(g.player.hp, kPlayerHp - 30);
    final hp = g.player.hp;
    g.hurtPlayer(30, fromX: 100, fromY: 0); // 无敌帧内不受击
    expect(g.player.hp, hp);
    g.player.invuln = 0;
    g.hurtPlayer(1000, fromX: 100, fromY: 0);
    expect(g.phase, GamePhase.gameover);
  });

  test('save then continue restores run', () {
    final g = GameState()..startNewRun();
    g.player.level = 4;
    g.player.weapons[WeaponType.orbit] = 2;
    g.player.passives[PassiveType.power] = 1;
    g.gold = 25;
    g.saveRun();
    g.startNewRun(); // 清空
    expect(g.player.level, 1);
    expect(g.continueRun(), isTrue);
    expect(g.player.level, 4);
    expect(g.player.weaponLevel(WeaponType.orbit), 2);
    expect(g.player.passiveLevel(PassiveType.power), 1);
    expect(g.gold, 25);
  });

  test('meta upgrade costs gold and grants permanent stat', () {
    final g = GameState()..startNewRun();
    g.meta.gold = 500;
    expect(g.buyMeta(0), isTrue);
    expect(g.meta.gold, 500 - metaCost(0, 0));
    expect(g.meta.metaBought[0], 1);
    // 买不起
    g.meta.gold = 1;
    expect(g.buyMeta(1), isFalse);
  });

  test('holdDirection 朝按住点移动并在贴近时停住', () {
    // 视口 800x600，玩家在世界原点；按住屏幕右下角 → 归一化向右下方
    final d = holdDirection(const Offset(0, 0), const Offset(600, 450), 800, 600);
    expect(d.dx, greaterThan(0));
    expect(d.dy, greaterThan(0));
    expect(d.distance, closeTo(1.0, 0.001));
    // 按住点等于玩家屏幕位置（视口中心）→ 停住
    final stop = holdDirection(const Offset(0, 0), const Offset(400, 300), 800, 600);
    expect(stop, Offset.zero);
  });

  test('冰霜新星/神圣之光/追踪飞弹 都能造成伤害', () {
    final g = GameState()..startNewRun();
    g.player.weapons[WeaponType.frost] = 1;
    g.player.weapons[WeaponType.holy] = 1;
    g.player.weapons[WeaponType.homing] = 1;
    g.monsters.add(Monster(
        kind: MonsterKind.slime, x: 60, y: 0, hp: 5000, speed: 0, damage: 0,
        radius: 12, xp: 1, gold: 1, color: const Color(0xFF66BB6A)));
    for (int i = 0; i < 240; i++) {
      g.update(0.05, Offset.zero);
    }
    expect(g.monsters.first.hp, lessThan(5000));
  });

  test('boss 会正常掉血', () {
    final g = GameState()..startNewRun();
    g.player.weapons[WeaponType.bolt] = 5;
    g.monsters.add(Monster(
        kind: MonsterKind.golem, x: 80, y: 0, hp: 2000, speed: 0, damage: 0,
        radius: 40, xp: 15, gold: 20, color: const Color(0xFF8D6E63),
        boss: true));
    for (int i = 0; i < 120; i++) {
      g.update(0.05, Offset.zero);
    }
    expect(g.monsters.first.hp, lessThan(2000));
  });

  test('穿透激光能造成伤害', () {
    final g = GameState()..startNewRun();
    g.player.weapons[WeaponType.laser] = 1;
    g.monsters.add(Monster(
        kind: MonsterKind.slime, x: 120, y: 0, hp: 5000, speed: 0, damage: 0,
        radius: 10, xp: 1, gold: 1, color: const Color(0xFF66BB6A)));
    for (int i = 0; i < 120; i++) {
      g.update(0.05, Offset.zero);
    }
    expect(g.monsters.first.hp, lessThan(5000));
  });

  test('荆棘护盾受击反伤', () {
    final g = GameState()..startNewRun();
    g.player.weapons[WeaponType.thorns] = 1;
    g.monsters.add(Monster(
        kind: MonsterKind.slime, x: 15, y: 0, hp: 200, speed: 0, damage: 20,
        radius: 10, xp: 1, gold: 1, color: const Color(0xFF66BB6A)));
    g.player.invuln = 0;
    g.hurtPlayer(20, fromX: 15, fromY: 0); // 直接受击触发反伤
    expect(g.monsters.first.hp, lessThan(200));
  });

  test('死神镰刀与剧毒沼泽能造成伤害', () {
    final g = GameState()..startNewRun();
    g.player.weapons[WeaponType.scythe] = 1;
    g.player.weapons[WeaponType.venom] = 1;
    g.monsters.add(Monster(
        kind: MonsterKind.slime, x: 80, y: 0, hp: 5000, speed: 0, damage: 0,
        radius: 10, xp: 1, gold: 1, color: const Color(0xFF66BB6A)));
    for (int i = 0; i < 200; i++) {
      g.update(0.05, Offset.zero);
    }
    expect(g.monsters.first.hp, lessThan(5000));
  });

  test('弓箭手的箭能伤害玩家', () {
    final g = GameState()..startNewRun();
    g.monsters.add(Monster(
        kind: MonsterKind.archer, x: 100, y: 0, hp: 50, speed: 0, damage: 5,
        radius: 12, xp: 1, gold: 1, color: const Color(0xFFBCAAA4)));
    g.player.invuln = 0;
    for (int i = 0; i < 240; i++) {
      g.update(0.05, Offset.zero);
    }
    expect(g.player.hp, lessThan(kPlayerHp));
  });

  test('玩家体型随等级增大', () {
    final g = GameState()..startNewRun();
    final base = g.player.radius();
    g.player.level = 20;
    expect(g.player.radius(), greaterThan(base));
  });

  test('武器支持 10 星，被动无上限，带品质', () {
    final g = GameState()..startNewRun();
    g.player.weapons[WeaponType.bolt] = 10;
    expect(g.player.weaponLevel(WeaponType.bolt), 10);
    expect(boltParam(10).dmg, greaterThan(boltParam(1).dmg));
    g.player.passives[PassiveType.power] = 60;
    expect(passiveDefs[PassiveType.power]!.maxLevel, greaterThan(60));
    expect(weaponDefs[WeaponType.lightning]!.rarity, greaterThanOrEqualTo(0));
    expect(passiveDefs[PassiveType.explode]!.rarity, greaterThanOrEqualTo(0));
  });

  test('看广告复活恢复满血并清空敌人', () {
    final g = GameState()..startNewRun();
    g.player.invuln = 0;
    g.monsters.add(Monster(
        kind: MonsterKind.slime, x: 30, y: 0, hp: 20, speed: 0, damage: 0,
        radius: 10, xp: 1, gold: 1, color: const Color(0xFF66BB6A)));
    g.hurtPlayer(1000, fromX: 30, fromY: 0);
    expect(g.phase, GamePhase.gameover);
    g.revive();
    expect(g.phase, GamePhase.playing);
    expect(g.player.hp, g.player.maxHp);
    expect(g.reviveLeft, 0);
    expect(g.monsters, isEmpty);
  });
}
