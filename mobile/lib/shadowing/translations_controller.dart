// Bản dịch câu của 1 bài theo ngôn ngữ (port từ useTranslations.js).
// Đọc cache trên server trước; còn câu chưa dịch thì gọi server dịch máy (lần đầu có thể mất vài giây).
import 'package:flutter/foundation.dart';

import '../api/api.dart';

enum TrStatus { idle, loading, translating, ready, error }

class TranslationsController extends ChangeNotifier {
  TranslationsController(this.lessonId, {Api? api}) : _api = api ?? Api.instance;

  final int lessonId;
  final Api _api;
  Map<int, String> items = const {};
  TrStatus status = TrStatus.idle;
  String? error;
  String lang = 'off';
  int _req = 0;
  bool _disposed = false;

  bool get pending => status == TrStatus.loading || status == TrStatus.translating;

  void _set(TrStatus s, {Map<int, String>? items, String? error}) {
    if (_disposed) return;
    status = s;
    if (items != null) this.items = items;
    this.error = error;
    notifyListeners();
  }

  /// lang = 'off' -> không tải
  Future<void> load(String lang) async {
    this.lang = lang;
    final req = ++_req;
    if (lang == 'off') return _set(TrStatus.idle, items: const {});
    _set(TrStatus.loading, items: const {});
    try {
      var data = await _api.translations(lessonId, lang);
      if (req != _req) return;
      if (data.missing > 0) {
        _set(TrStatus.translating, items: data.items);
        data = await _api.translate(lessonId, lang);
        if (req != _req) return;
      }
      _set(TrStatus.ready, items: data.items);
    } catch (e) {
      if (req == _req) _set(TrStatus.error, error: '$e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
