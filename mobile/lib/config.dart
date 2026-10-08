/// Cấu hình build. Đổi backend khi build/run:
///   flutter run --dart-define=API_BASE=http://10.0.2.2:4100
class Config {
  /// Gốc của API, không có dấu `/` ở cuối. Mặc định dùng backend public (sau Traefik).
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://demo.thanhbn.space/project/shadowing',
  );
}
