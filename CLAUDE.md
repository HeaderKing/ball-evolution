# 暗黑割草（打怪升级游戏）

Flutter + CustomPainter 实现的实时动作打怪升级游戏（类吸血鬼幸存者）。

## 硬性约束

- **禁止使用截图/图像查看功能**：当前模型不支持多模态，不能通过截图读图。
  验证方式只能用：
  - `flutter analyze`（静态检查）
  - `flutter test`（widget / 单元测试）
  - 浏览器 console 日志 / accessibility snapshot（不截图）
  - 直接读代码、日志文本

## 运行

```bash
flutter run -d chrome   # Web
flutter run -d windows  # Windows 桌面
```

## 结构

- `lib/main.dart` — 入口、GameScreen（Ticker 主循环、键盘/摇杆输入接线）
- `lib/src/config.dart` — 全部平衡数值表（武器/被动/怪物/难度/经验/元养成）
- `lib/src/entities.dart` — Player / Monster / Projectile / Pickup / Particle / FloatText
- `lib/src/state.dart` — GameState：主循环、武器、战斗、生成、升级三选一、存档
- `lib/src/render.dart` — GamePainter：Canvas 绘制
- `lib/src/ui.dart` — HUD、升级面板、暂停/结束/主菜单、虚拟摇杆
- `lib/src/save.dart` — 存档分发（Web：SQLite wasm+IndexedDB，回退 localStorage；桌面：JSON 文件）

## 玩法

鼠标跟随光标移动（WASD 备用），触屏按住拖动移动，武器自动攻击，
升级三选一，精英每 45s、Boss 每 180s（3 种 Boss 轮换、Boss 带范围技能）。
开局自带 1 级魔法飞弹。玩家体型随等级增大。
存储：Web 用 SQLite（`sqlite3.wasm` + IndexedDB，失败回退 localStorage），
桌面用 `%APPDATA%\dark_slash_save.json`。主菜单可选"新游戏 / 继续存档"。
