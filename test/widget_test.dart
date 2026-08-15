import 'package:flutter_test/flutter_test.dart';
import 'package:dark_slash/main.dart';
import 'package:dark_slash/src/state.dart';

void main() {
  // 游戏有常驻 Ticker，禁止使用 pumpAndSettle
  GameState.debugNoSave = true;

  testWidgets('菜单显示并可开始游戏', (tester) async {
    await tester.pumpWidget(const DarkSlashApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('球球进化'), findsOneWidget);
    expect(find.text('新游戏'), findsOneWidget);

    await tester.tap(find.text('新游戏'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('HP'), findsOneWidget);
    expect(find.textContaining('技能'), findsOneWidget); // 技能按钮折叠展示
    expect(find.text('你死了'), findsNothing);
  });

  testWidgets('暂停按钮弹出暂停面板并可继续', (tester) async {
    await tester.pumpWidget(const DarkSlashApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('新游戏'));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('暂停'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('已暂停'), findsOneWidget);

    await tester.tap(find.text('继续游戏'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('已暂停'), findsNothing);
  });
}
