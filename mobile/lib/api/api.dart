import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config.dart';
import '../core/prefs.dart';
import 'models.dart';

class ApiException implements Exception {
  final int? status;
  final String message;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Client cho backend Express hiện có (cùng API với bản web).
class Api {
  Api({String base = Config.apiBase, http.Client? client})
      : _base = base.replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  static final instance = Api();

  final String _base;
  final http.Client _client;
  static const _timeout = Duration(seconds: 20);
  // Dịch máy lần đầu có thể mất vài chục giây
  static const _translateTimeout = Duration(seconds: 120);

  /// Backend trả `/project/shadowing/media/...` (tương đối theo domain) hoặc URL tuyệt đối khi chạy dev.
  String? resolve(String? path) => path == null || path.isEmpty ? null : Uri.parse('$_base/').resolve(path).toString();

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('$_base$path').replace(queryParameters: query);

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final res = await _client.get(_uri(path, query)).timeout(_timeout);
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }
    if (res.statusCode >= 400) {
      final msg = body is Map ? (body['message'] ?? body['error']) : null;
      throw ApiException(msg?.toString() ?? 'HTTP ${res.statusCode}', res.statusCode);
    }
    return body;
  }

  Future<List<Topic>> topics() async =>
      [for (final t in await _get('/api/topics') as List) Topic.fromJson(t as Map<String, dynamic>, resolve)];

  Future<TopicDetail> topic(String slug) async =>
      TopicDetail.fromJson(await _get('/api/topics/${Uri.encodeComponent(slug)}') as Map<String, dynamic>, resolve);

  Future<Lesson> lesson(String topic, String lesson) async => Lesson.fromJson(
        await _get('/api/topics/${Uri.encodeComponent(topic)}/lessons/${Uri.encodeComponent(lesson)}')
            as Map<String, dynamic>,
        resolve,
      );

  Future<List<Language>> languages() async =>
      [for (final l in await _get('/api/languages') as List) Language.fromJson(l as Map<String, dynamic>)];

  /// Bản dịch đã có (chỉ đọc cache trên server).
  Future<Translations> translations(int lessonId, String lang) async =>
      Translations.fromJson(await _get('/api/lessons/$lessonId/translations', {'lang': lang}) as Map<String, dynamic>);

  /// Dịch máy các câu còn thiếu rồi trả về toàn bộ.
  Future<Translations> translate(int lessonId, String lang) async {
    final res = await _client
        .post(
          _uri('/api/lessons/$lessonId/translations'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'lang': lang}),
        )
        .timeout(_translateTimeout);
    return Translations.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<List<Attempt>> progress(int lessonId) async {
    final rows = await _get('/api/lessons/$lessonId/progress', {'clientId': await Prefs.clientId()}) as List;
    return [for (final r in rows) Attempt.fromJson(r as Map<String, dynamic>, resolve)];
  }

  /// Lưu một lần shadow. `audioPath`: file .m4a vừa ghi (tuỳ chọn).
  Future<Attempt> saveAttempt({
    required int lessonId,
    required int sentenceIdx,
    required int score,
    required String heard,
    String? audioPath,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/api/attempts'))
      ..fields.addAll({
        'clientId': await Prefs.clientId(),
        'lessonId': '$lessonId',
        'sentenceIdx': '$sentenceIdx',
        'score': '$score',
        'heard': heard,
      });
    if (audioPath != null) {
      // mimetype chứa "mp4" -> backend lưu đuôi .m4a
      req.files.add(await http.MultipartFile.fromPath('audio', audioPath, contentType: MediaType('audio', 'mp4')));
    }
    final res = await http.Response.fromStream(await _client.send(req).timeout(_timeout));
    return Attempt.fromJson(_decode(res) as Map<String, dynamic>, resolve);
  }
}
