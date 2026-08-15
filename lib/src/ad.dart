// 广告服务：为抖音小游戏预留的激励视频广告接口。
// 后续接入真实广告 SDK 时，只需用一个实现替换下方的 adService 全局实例，
// 游戏内所有"看广告"入口（复活 / 金币 / 道具）都会自动走新实现。

enum AdReward { revive, coins, item }

abstract class AdService {
  /// 展示激励视频广告，返回是否完整观看（完整观看才发放奖励）
  Future<bool> showRewarded(AdReward reward);
}

/// 占位实现：模拟观看一段延迟后视为完成。
/// 可配置延迟与是否成功，便于演示/测试。
/// TODO(抖音小游戏): 替换为抖音激励视频广告 SDK 调用。
class DummyAdService implements AdService {
  final Duration delay;
  final bool succeed;
  const DummyAdService({
    this.delay = const Duration(seconds: 1),
    this.succeed = true,
  });

  @override
  Future<bool> showRewarded(AdReward reward) async {
    await Future<void>.delayed(delay);
    return succeed;
  }
}

/// 全局广告服务实例（后续在此替换为真实实现）
AdService adService = DummyAdService();
