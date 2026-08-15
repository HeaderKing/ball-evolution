# 球球进化

实时动作打怪升级小游戏（类吸血鬼幸存者玩法）。控制一个球体在怪海中割草、升级、挑战 Boss，数值无限成长。

[Flutter](https://flutter.dev) 3.41 · 纯 `CustomPainter` 渲染 · 自写 `Ticker` 游戏循环 · 可打包 Web / Android / Windows / iOS / macOS。

## 在线试玩

**Web 版已部署 GitHub Pages：<https://headerking.github.io/ball-evolution/>**（push master 自动构建发布）

## 玩法

- **操作**：桌面鼠标跟随光标移动；移动端屏幕底部中央的**虚拟方向盘** 360° 控制（WASD 亦可）；首局主菜单有引导提示
- **核心循环**：怪物从四周涌来 → 武器自动攻击 → 击杀直接获得经验 → 升级**三选一**（品质配色：普通/稀有/史诗/传说）→ 变强 → 难度随时间与玩家等级爬升
- **Boss 战**：每 3 分钟一只，三只 Boss 各有**专属技能**与预警——
  - 石头王：**震地**（大范围重击）/ **磐石护体**（4 秒减伤 70%）
  - 狼王：**狼嚎**（召唤小狼群）/ **扑击**（高速突进）
  - 幽灵王：**冰霜之环**（扩散冰环减速）/ **幻影瞬移**（闪现突袭）
  - 放完技能进入**虚弱**（受伤 +50%）、战斗中周期性掉落增益道具；Boss 存活期间不再刷新小怪
- **武器进化**：满级武器（10 星）+ 指定被动达标 → 合成进化武器（寒冰飞弹 / 加特林 / 巨斧 / 圣剑环绕 / 风暴闪电），图鉴展示进化路径
- **养成**：22 种武器（含进化）、14 种被动无限叠加、6 维永久祝福（金币阶梯购买）、5 款皮肤（附加成）、月卡（每局复活 3 次）
- **成长**：1-10 级每级 +100 生命，11-20 级每级 +1000，依此类推；怪物伤害按玩家生命上限百分比计算，全程保持挑战
- **收集与目标**：怪物图鉴击杀解锁（含 Boss 机制说明）；**每日挑战**（累计击杀 / 最高等级 / 累计存活）金币奖励、跨天重置
- **体验细节**：打击顿帧、屏幕震动、命中受击音效（武器专属音效 + 播放器池）、HUD **小地图**显示敌人分布与 Boss 方位、死亡总结展示伤害 TOP 武器与最长连杀
- **设置持久化**：BGM / 音效独立音量、手机震动、屏幕震动、顿帧、伤害数字开关，跨会话保存

## 素材与授权

- 打击/受击/击杀音效：**Kenney「Impact Sounds」**（[kenney.nl/assets/impact-sounds](https://kenney.nl/assets/impact-sounds)），**CC0** 公有领域
- 战斗背景音乐："Battle Theme"（Liberated Pixel Cup，[OpenGameArt](https://lpc.opengameart.org/content/battle-theme-0)），**CC0**
- Boss 战背景音乐：本项目 `tool/gen_audio.py` 合成（A 小调驱动循环）
- 图标：项目内 `球球进化.jpg`（用户素材）

## 本地运行

```bash
cd 打怪升级
flutter run -d chrome     # Web
flutter run -d windows    # Windows 桌面
flutter run -d macos      # macOS
```

> iOS 构建需在 macOS 上执行；项目路径含中文，Android 打包需先复制到 ASCII 路径（见下）。

## 构建

```bash
flutter build web --release            # Web 产物 → build/web（已配置 GitHub Pages 自动部署）
flutter build apk --release            # Android APK
```

> **注意**：项目路径含中文，Android 的 Gradle / Dart AOT 无法处理非 ASCII 路径。
> 打 APK 需先复制到 ASCII 路径（如 `Z:\vibe_coding\dsapk`）再构建。

## Web 自动部署

仓库已配置 GitHub Actions（`.github/workflows/deploy-web.yml`）：push 到 `master` 自动 `flutter build web --release` 并发布到 GitHub Pages（在线试玩链接见上）。

## 项目结构

```
lib/
  main.dart               # 入口、GameScreen（Ticker 主循环、键盘/摇杆/指针输入）
  src/
    config.dart           # 全部平衡数值表（武器/被动/进化配方/怪物/Boss/元养成/每日挑战）
    entities.dart         # Player / Monster / Projectile / Pickup / Particle ...
    state.dart            # GameState：主循环、武器、Boss 技能、进化、升级、存档、每日挑战
    render.dart           # GamePainter：Canvas 绘制（相机缩放、背景装饰、Boss 技能特效）
    ui.dart               # HUD、小地图、升级三选一、技能/怪物图鉴、状态、设置、主菜单
    audio.dart            # AudioManager：音效/BGM（audioplayers 播放器池）
    ad.dart / pay.dart    # 激励视频广告 / 月卡支付 预留接口（可替换为真实 SDK）
    save.dart             # 存档分发（Web SQLite wasm / 桌面 JSON）
    input.dart            # 键盘 + 虚拟方向盘
  assets/audio/           # 音效与 BGM（CC0）
tool/
  gen_audio.py            # 合成 Boss BGM 与占位音效（Python 标准库）
  make_icons.py           # 由 球球进化.jpg 生成 Android/Web 图标
```

## 存档

- **Web**：SQLite（`package:sqlite3/wasm.dart`，IndexedDB 持久化，加载失败回退 localStorage）
- **桌面/移动**：应用文档目录 JSON 文件
- 规则：**死亡清档；意外退出（切后台/锁屏/关闭）才自动存档**
- 存档带**版本号 + 迁移钩子**（`kSaveVersion`），改结构安全升级

## 广告 / 内购预留

- `lib/src/ad.dart`：激励视频广告接口（`AdService`），已接入 复活/看广告得金币/随机道具 三个入口；`DummyAdService` 可配置延迟与成功率，接入抖音/微信广告 SDK 时替换 `adService` 即可
- `lib/src/pay.dart`：月卡（¥18.8）支付接口占位，替换 `paymentService` 即接入真实支付

## 测试

```bash
flutter test     # 20 条：游戏逻辑 + 武器/Boss/进化回归 + 升级/存档/复活 + widget 冒烟
```

## 鸣谢

- Kenney（音效，CC0）：https://kenney.nl
- OpenGameArt（BGM，CC0）：https://opengameart.org
