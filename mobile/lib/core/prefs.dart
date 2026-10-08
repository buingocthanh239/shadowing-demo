import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Tuỳ chọn người dùng + định danh thiết bị (demo chưa có đăng nhập, giống bản web).
class Prefs {
  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();
  static String? _clientId;

  static Future<String> clientId() async {
    if (_clientId != null) return _clientId!;
    final p = await _p;
    var id = p.getString('sd.clientId');
    if (id == null) {
      id = const Uuid().v4();
      await p.setString('sd.clientId', id);
    }
    return _clientId = id;
  }

  /// Ngôn ngữ dịch ('off' = tắt)
  static Future<String> lang() async => (await _p).getString('sd.lang') ?? 'vi';
  static Future<void> setLang(String v) async => (await _p).setString('sd.lang', v);

  static Future<bool> showIpa() async => (await _p).getBool('sd.ipa') ?? true;
  static Future<void> setShowIpa(bool v) async => (await _p).setBool('sd.ipa', v);
}
