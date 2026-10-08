// Ghi âm (record) + nhận dạng giọng nói (speech_to_text) — tương đương recorder.js bên web.
//
// Android: SpeechRecognizer của hệ thống giữ micro, ghi âm song song thường bị câm/lỗi
// -> trên Android chỉ nhận dạng để chấm điểm, không lưu bản ghi.
// iOS: chạy cả hai (SFSpeechRecognizer + AVAudioRecorder).
import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceException implements Exception {
  final String message;
  VoiceException(this.message);
  @override
  String toString() => message;
}

class VoiceResult {
  /// File .m4a vừa ghi (null nếu không ghi được / không hỗ trợ trên nền tảng này)
  final String? audioPath;
  final String transcript;

  /// null = nhận dạng OK (kể cả khi không nghe được gì)
  final String? speechError;
  const VoiceResult(this.audioPath, this.transcript, this.speechError);
}

/// Một phiên ghi: gọi [stop] để dừng, đợi [done] để lấy kết quả.
class VoiceSession {
  VoiceSession._(this._voice);
  final Voice _voice;
  final _done = Completer<VoiceResult>();
  final _sttEnded = Completer<void>();
  AudioRecorder? _recorder;
  String _transcript = '';
  String? _error;
  bool _stopped = false;

  Future<VoiceResult> get done => _done.future;

  void _onResult(SpeechRecognitionResult r) => _transcript = r.recognizedWords.trim();

  void _onError(SpeechRecognitionError e) {
    // Không nói gì / không khớp -> coi như transcript rỗng, không phải lỗi
    if (e.errorMsg != 'error_no_match' && e.errorMsg != 'error_speech_timeout' && e.errorMsg != 'error_busy') {
      _error = e.errorMsg;
    }
    if (e.permanent && !_sttEnded.isCompleted) _sttEnded.complete();
  }

  void _onStatus(String status) {
    if ((status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) &&
        _stopped &&
        !_sttEnded.isCompleted) {
      _sttEnded.complete();
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    String? path;
    try {
      path = await _recorder?.stop();
    } catch (_) {}
    await _recorder?.dispose();
    if (_voice._stt.isListening) {
      await _voice._stt.stop();
      // Đợi kết quả cuối; một số máy không báo trạng thái "done" -> tự kết thúc sau 2.5s
      await _sttEnded.future.timeout(const Duration(milliseconds: 2500), onTimeout: () {});
    }
    _voice._active = null;
    _done.complete(VoiceResult(path, _transcript, _error));
  }
}

class Voice {
  Voice._();
  static final instance = Voice._();

  final SpeechToText _stt = SpeechToText();
  bool? _sttReady;
  VoiceSession? _active;

  /// Có ghi âm song song với nhận dạng không (xem ghi chú đầu file)
  static bool get recordsAudio => Platform.isIOS;

  Future<bool> _initStt() async {
    if (_sttReady == true) return true;
    _sttReady = await _stt.initialize(
      onError: (e) => _active?._onError(e),
      onStatus: (s) => _active?._onStatus(s),
    );
    return _sttReady!;
  }

  /// Bắt đầu phiên ghi. [lang] dạng BCP-47 (vd "en-US").
  Future<VoiceSession> start(String lang) async {
    if (_active != null) throw VoiceException('Đang ghi âm.');
    final ok = await _initStt();
    if (!ok) {
      throw VoiceException(
        'Không dùng được nhận dạng giọng nói. Hãy cho phép quyền Micro và Nhận dạng giọng nói trong Cài đặt.',
      );
    }
    final session = VoiceSession._(this);
    _active = session;

    if (recordsAudio) {
      final rec = AudioRecorder();
      try {
        if (await rec.hasPermission()) {
          final dir = await getTemporaryDirectory();
          final path = '${dir.path}/rec-${DateTime.now().millisecondsSinceEpoch}.m4a';
          await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
          session._recorder = rec;
        } else {
          await rec.dispose();
        }
      } catch (_) {
        // Không ghi được thì vẫn chấm điểm bình thường
        await rec.dispose();
      }
    }

    try {
      await _stt.listen(
        onResult: session._onResult,
        listenOptions: SpeechListenOptions(
          localeId: lang.replaceAll('-', '_'),
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      session._error = '$e';
      await session.stop();
    }
    return session;
  }
}
