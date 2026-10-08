// Toàn bộ state + logic của màn shadowing (port từ frontend/src/lib/useShadowing.js):
// phát audio theo câu, highlight karaoke, ghi âm, chấm điểm, lưu kết quả.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../core/scoring.dart';
import '../core/timeline.dart';
import 'voice.dart';

enum Phase { idle, listening, recording, scoring }

class SentenceResult {
  final int? score;
  final List<WordMark>? words;
  final String? heard;

  /// File ghi âm trên máy (vừa ghi) hoặc URL trên server (từ lịch sử)
  final String? audio;
  final int? best;
  final int? tries;
  const SentenceResult({this.score, this.words, this.heard, this.audio, this.best, this.tries});
}

class RecordWindow {
  final Duration length;
  final DateTime startedAt;
  RecordWindow(this.length) : startedAt = DateTime.now();
}

class ShadowingController extends ChangeNotifier {
  ShadowingController(this.lesson, {Api? api, Voice? voice})
      : _api = api ?? Api.instance,
        _voice = voice ?? Voice.instance;

  final Lesson lesson;
  final Api _api;
  final Voice _voice;
  final player = AudioPlayer();
  final _minePlayer = AudioPlayer();

  List<Sentence> get sentences => lesson.sentences;

  int current = 0;
  int wordIdx = -1;
  double time = 0;
  double? totalDuration;
  bool playing = false;
  double rate = 1;
  Phase phase = Phase.idle;
  RecordWindow? recordWindow;
  final results = <int, SentenceResult>{};
  bool continuous = false;
  String? error;
  bool ready = false;

  double? _stopAt; // giây: dừng phát khi tới mốc này
  VoidCallback? _onStop; // callback khi phát hết đoạn
  VoiceSession? _session;
  int _run = 0; // tăng lên để huỷ chuỗi shadow tự động đang chạy
  bool _disposed = false;
  final _subs = <StreamSubscription>[];

  bool get busy => phase != Phase.idle;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> init() async {
    _subs
      ..add(player
          .createPositionStream(minPeriod: const Duration(milliseconds: 30), maxPeriod: const Duration(milliseconds: 30))
          .listen(_tick))
      ..add(player.playerStateStream.listen((s) {
        final p = s.playing && s.processingState != ProcessingState.completed;
        if (p != playing) {
          playing = p;
          if (!p) wordIdx = -1;
          _notify();
        }
      }))
      ..add(player.durationStream.listen((d) {
        if (d != null) totalDuration = d.inMilliseconds / 1000;
        _notify();
      }));

    _loadProgress();
    if (lesson.audioUrl == null) {
      error = 'Bài này chưa có audio.';
    } else {
      try {
        await player.setUrl(lesson.audioUrl!);
        ready = true;
      } catch (e) {
        error = 'Không tải được audio: $e';
      }
    }
    _notify();
  }

  // Tiến độ đã lưu trên server
  Future<void> _loadProgress() async {
    try {
      for (final a in await _api.progress(lesson.id)) {
        results[a.sentenceIdx] = SentenceResult(score: a.score, heard: a.heard, audio: a.audioUrl, best: a.best, tries: a.tries);
      }
      _notify();
    } catch (_) {}
  }

  // Đồng bộ câu/từ đang phát với vị trí audio
  void _tick(Duration pos) {
    if (_disposed) return;
    final t = pos.inMilliseconds / 1000;
    time = t;
    if (_stopAt == null && player.playing) current = findSentence(sentences, t);
    wordIdx = player.playing ? findWord(sentences.elementAtOrNull(current), t) : -1;

    if (_stopAt != null && player.playing && t >= _stopAt!) {
      player.pause();
      _stopAt = null;
      wordIdx = -1;
      final cb = _onStop;
      _onStop = null;
      cb?.call();
    }
    _notify();
  }

  Future<void> _playRange(double start, double end, [VoidCallback? onDone]) async {
    if (!ready) return;
    await _minePlayer.stop();
    _stopAt = null;
    _onStop = null;
    await player.seek(Duration(milliseconds: (start * 1000).round()));
    _stopAt = end;
    _onStop = onDone;
    unawaited(player.play().catchError((Object e) {
      error = '$e';
      _notify();
    }));
  }

  void setCurrent(int i) {
    if (i < 0 || i >= sentences.length) return;
    current = i;
    _notify();
  }

  void cancel() {
    _run++;
    _stopAt = null;
    _onStop = null;
    player.pause();
    _session?.stop();
    if (phase == Phase.listening) phase = Phase.idle;
    _notify();
  }

  void playSentence(int i, [VoidCallback? onDone]) {
    if (i < 0 || i >= sentences.length || !ready) return;
    current = i;
    phase = Phase.listening;
    _notify();
    _playRange(sentences[i].start, segmentEnd(sentences, i), () {
      phase = Phase.idle;
      _notify();
      onDone?.call();
    });
  }

  void playWord(int sIdx, int wIdx) {
    final s = sentences.elementAtOrNull(sIdx);
    final w = s?.words.elementAtOrNull(wIdx);
    if (s == null || w?.start == null || busy) return;
    final end = s.words.elementAtOrNull(wIdx + 1)?.start ?? segmentEnd(sentences, sIdx);
    _playRange(w!.start!, end + 0.05);
  }

  void togglePlayAll() {
    if (player.playing) return cancel();
    _run++;
    _stopAt = null;
    _onStop = null;
    if (player.processingState == ProcessingState.completed) player.seek(Duration.zero);
    unawaited(player.play());
  }

  Future<void> seek(double t) async {
    _stopAt = null;
    _onStop = null;
    time = t;
    current = findSentence(sentences, t);
    _notify();
    await player.seek(Duration(milliseconds: (t * 1000).round()));
  }

  Future<void> setRate(double r) async {
    rate = r;
    _notify();
    await player.setSpeed(r);
  }

  void setContinuous(bool v) {
    continuous = v;
    _notify();
  }

  void clearError() {
    error = null;
    _notify();
  }

  /// Ghi âm câu i. [autoStop]: tự dừng sau khoảng thời gian (chế độ shadow tự động).
  Future<ScoreResult?> record(int i, {Duration? autoStop}) async {
    final s = sentences.elementAtOrNull(i);
    if (s == null || _session != null) return null;
    error = null;
    current = i;
    await _minePlayer.stop();
    final VoiceSession session;
    try {
      session = await _voice.start(lesson.lang);
    } catch (e) {
      error = e is VoiceException ? e.message : 'Không mở được micro: $e';
      _notify();
      return null;
    }
    _session = session;
    phase = Phase.recording;
    Timer? timer;
    if (autoStop != null) {
      recordWindow = RecordWindow(autoStop);
      timer = Timer(autoStop, session.stop);
    }
    _notify();

    final out = await session.done;
    timer?.cancel();
    _session = null;
    recordWindow = null;
    if (_disposed) return null;
    phase = Phase.scoring;
    _notify();

    final scored = out.speechError == null ? scoreSentence(s.text, out.transcript) : null;
    if (out.speechError != null) error = 'Lỗi nhận dạng giọng nói: ${out.speechError}';

    final old = results[i];
    results[i] = SentenceResult(
      score: scored?.score ?? old?.score,
      words: scored?.words ?? old?.words,
      heard: scored?.heard ?? old?.heard,
      audio: out.audioPath ?? (scored == null ? old?.audio : null),
      best: scored != null ? max(old?.best ?? 0, scored.score) : old?.best,
      tries: scored != null ? (old?.tries ?? 0) + 1 : old?.tries,
    );
    phase = Phase.idle;
    _notify();

    if (scored != null) {
      unawaited(_api
          .saveAttempt(lessonId: lesson.id, sentenceIdx: i, score: scored.score, heard: scored.heard, audioPath: out.audioPath)
          .then((_) {}, onError: (_) {}));
    }
    return scored;
  }

  void stopRecording() => _session?.stop();

  /// Shadow tự động: nghe câu mẫu -> ghi âm trong (độ dài câu + 1.5s) -> chấm -> (liên tục) sang câu sau
  void shadow(int i) {
    final run = ++_run;
    void step(int idx) {
      playSentence(idx, () async {
        if (run != _run) return;
        final s = sentences[idx];
        final ms = max(2500, (((segmentEnd(sentences, idx) - s.start) / rate + 1.5) * 1000).round());
        await record(idx, autoStop: Duration(milliseconds: ms));
        if (run != _run || !continuous || idx + 1 >= sentences.length) return;
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (run == _run && !_disposed) step(idx + 1);
        });
      });
    }

    step(i);
  }

  /// Nghe lại bản ghi của mình
  Future<void> playMine(int i) async {
    final src = results[i]?.audio;
    if (src == null) return;
    cancel();
    try {
      if (src.startsWith('http')) {
        await _minePlayer.setUrl(src);
      } else {
        await _minePlayer.setFilePath(src);
      }
      unawaited(_minePlayer.play());
    } catch (e) {
      error = 'Không phát được bản ghi: $e';
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _run++;
    _session?.stop();
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
    _minePlayer.dispose();
    super.dispose();
  }
}
