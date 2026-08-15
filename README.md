# 球球进化

实时动作打怪升级小游戏（类吸血鬼幸存者玩法）。控制一个球体在怪海中割草、升级、挑战 Boss，数值无限成长。

[Flutter](https://flutter.dev) 3.41 · 纯 `CustomPainter` 渲染 · 自写 `Ticker` 游戏循环 · 可打包 Web / Android / Windows。

## 玩法

- **操作**：桌面鼠标跟随光标移动；移动端屏幕底部中央的**虚拟方向盘** 360° 控制（WASD 亦可）
- **核心循环**：怪物从四周涌来 → 武器自动攻击 → **击杀直接获得经验** → 升级**三选一**（品质配色：普通/稀有/史诗/传说）→ 变强 → 难度随时间与玩家等级爬升
- **Boss 战**：每 3 分钟一只（石头王/狼王/幽灵王轮换），带范围技能预警；**放完技能进入"虚弱"**（受伤+50%）、战斗中**周期性掉落增益道具**；Boss 存活期间不再刷新小怪
- **养成**：17 种武器 ×10 星（满级觉醒）、14 种被动无限叠加、6 维永久祝福（金币阶梯购买）、5 款皮肤（附加成）、月卡（每局复活 3 次）
- **生命阶梯成长**：1-10 级每级 +100，11-20 级每级 +1000，依此类推；**怪物伤害按玩家生命上限百分比计算**，全程保持挑战

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
```

## 构建

```bash
flutter build web --release            # Web 产物 → build/web
flutter build apk --release            # Android APK
```

> **注意**：项目路径含中文，Android 的 Gradle / Dart AOT 无法处理非 ASCII 路径。
> 打 APK 需先复制到 ASCII 路径（如 `Z:\vibe_coding\dsapk`）再构建。

## 项目结构

```
lib/
  main.dart               # 入口、GameScreen（Ticker 主循环、键盘/摇杆/指针输入）
  src/
    config.dart           # 全部平衡数值表（武器/被动/怪物/难度/元养成/皮肤）
    entities.dart         # Player / Monster / Projectile / Pickup / Particle ...
    state.dart            # GameState：主循环、武器、战斗、生成、升级、存档
    render.dart           # GamePainter：Canvas 绘制（相机缩放、背景装饰、特效）
    ui.dart               # HUD、升级三选一、技能图鉴、状态面板、主菜单、皮肤/月卡
    audio.dart            # AudioManager：音效/BGM（audioplayers）
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

## 广告 / 内购预留

- `lib/src/ad.dart`：激励视频广告接口（`AdService`），已接入 复活/看广告得金币/随机道具 三个入口；接入抖音/微信广告 SDK 时替换 `adService` 即可
- `lib/src/pay.dart`：月卡（¥18.8）支付接口占位，替换 `paymentService` 即接入真实支付

## 测试

```bash
flutter test     # 19 条：游戏逻辑 + 武器/Boss 回归 + 升级/存档/复活 + widget 冒烟
```

## 鸣谢

- Kenney（音效，CC0）：https://kenney.nl
- OpenGameArt（BGM，CC0）：https://opengameart.org
