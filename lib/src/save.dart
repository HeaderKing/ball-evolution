// 存档统一入口：桌面端走文件，Web 端走 localStorage
export 'save_io.dart' if (dart.library.html) 'save_web.dart';
