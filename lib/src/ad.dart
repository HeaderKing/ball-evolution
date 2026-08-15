// 广告服务：为抖音小游戏预留的激励视频广告接口。
// 后续接入真实广告 SDK 时，只需用一个实现替换下方的 adService 全局实例，
// 游戏内所有"看广告"入口（复活 / 金币 / 道具）都会自动走新实现。

enum AdReward { revive, coins, item }

abstract class AdService {
  /// 展示激励视频广告，返回是否完整观看（完整观看才发放奖励）
  Future<bool> showRewarded(AdReward reward);
}

/// 占位实现：模拟观看 1 秒后视为完成。
/// TODO(抖音小游戏): 替换为抖音激励视频广告 SDK 调用。
class DummyAdService implements AdService {
  @override
  Future<bool> showRewarded(AdReward reward) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return true;
  }
}

/// 全局广告服务实例（后续在此替换为真实实现）
AdService adService = DummyAdService();
