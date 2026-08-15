// 支付服务：为月卡/内购预留的接口。
// 后续接入真实支付（抖音/微信/支付宝）时替换 paymentService 实现即可。

abstract class PaymentService {
  /// 购买月卡，返回是否成功
  Future<bool> purchaseMonthlyCard();
}

/// 占位实现：模拟支付结果。
/// TODO: 替换为真实支付 SDK（抖音/微信/支付宝）。
class DummyPaymentService implements PaymentService {
  final bool succeed;
  const DummyPaymentService({this.succeed = true});

  @override
  Future<bool> purchaseMonthlyCard() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return succeed;
  }
}

/// 全局支付服务实例（后续在此替换为真实实现）
PaymentService paymentService = DummyPaymentService();
