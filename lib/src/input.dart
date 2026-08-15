import 'dart:ui';

// ============ 输入状态 ============

class InputState {
  double mx = 0, my = 0; // 键盘移动向量（未归一化）

  void reset() {
    mx = 0;
    my = 0;
  }
}

// 固定虚拟方向盘：位于屏幕底部中央，360° 控制
class FixedJoy {
  Offset center = Offset.zero;
  Offset stick = Offset.zero;
  bool active = false;

  void start(Offset p, Offset c) {
    center = c;
    stick = c;
    active = true;
  }

  void move(Offset p) {
    if (active) stick = p;
  }

  void end() {
    active = false;
  }

  // 返回归一化方向（无输入返回零向量），最大杆程 radius
  Offset direction(double radius) {
    if (!active) return Offset.zero;
    final d = stick - center;
    if (d.distance < 10) return Offset.zero;
    final clamped = d.distance > radius ? d / d.distance * radius : d;
    return clamped / radius;
  }
}
