# Shadowing — app Flutter (Android / iOS)

Bản mobile của demo shadowing, dùng **chung backend** với bản web (`https://demo.thanhbn.space/project/shadowing`). Không cần sửa gì ở backend: app gọi đúng các API trong [README gốc, mục 6](../README.md#6-api).

| Tính năng | Bản web | Bản Flutter |
|---|---|---|
| Danh sách chủ đề / bài, tìm kiếm, lọc level | ✓ | ✓ |
| Phát theo câu, karaoke từng từ, chạm từ để nghe | `<audio>` + rAF | `just_audio` + position stream 30 ms |
| IPA từng từ, bản dịch 11 ngôn ngữ (tự gọi dịch máy khi thiếu) | ✓ | ✓ |
| Ghi âm + nhận dạng giọng nói | MediaRecorder + Web Speech API | `record` + `speech_to_text` (nhận dạng của hệ điều hành) |
| Chấm điểm LCS theo từ | `scoring.js` | `lib/core/scoring.dart` (port 1-1, có test) |
| Shadow tự động, chế độ liên tục, tốc độ 0.5x–1.25x | ✓ | ✓ |
| Lưu lần luyện + tiến độ (`/api/attempts`, `/progress`) | ✓ | ✓ (clientId riêng cho mỗi máy) |
| Từ vựng / cụm / thành ngữ / ngữ pháp, nghe TTS | `speechSynthesis` | `flutter_tts` |

## Chạy

Cần Flutter SDK ≥ 3.27 (stable).

```bash
cd mobile
flutter pub get
flutter run                       # dùng backend public demo.thanhbn.space
flutter test                      # test chấm điểm + timeline
```

Trên máy dev hiện tại, Flutter và Android SDK cài ở ổ ngoài (không có trong PATH):

```bash
export PATH=/Volumes/Untitled/dev/flutter/bin:$PATH
export ANDROID_HOME=/Volumes/Untitled/dev/android-sdk ANDROID_AVD_HOME=/Volumes/Untitled/dev/avd
$ANDROID_HOME/emulator/emulator -avd shadowing_pixel -allow-host-audio &   # Pixel 7, Android 16 (API 36) + Google Play
flutter run
```

Emulator cần nhiều CPU: nếu máy đang bận (build, esbuild watch…) Android sẽ hay hiện "System UI isn't responding" — chọn *Wait*.
Micro của emulator chỉ nhận tiếng từ Mac khi bật *Extended controls → Microphone → Virtual microphone uses host audio input* và macOS đã cấp quyền micro cho emulator; nếu không, nhận dạng luôn trả "không nghe được gì".

Đổi backend (vd chạy backend dev ở máy, Android emulator truy cập máy host qua `10.0.2.2`):

```bash
flutter run --dart-define=API_BASE=http://10.0.2.2:4100
```

Gọi `http://` (không TLS) trên Android cần bật cleartext; bản mặc định chỉ dùng HTTPS nên không bật.

Build:

```bash
flutter build apk --release       # Android
flutter build ipa                 # iOS (cần tài khoản Apple Developer để ký)
```

## Cấu trúc

```
lib/
  config.dart                      API_BASE (--dart-define)
  api/models.dart, api/api.dart    model + client HTTP, đổi URL media tương đối sang tuyệt đối
  core/scoring.dart                chấm điểm LCS (port từ frontend/src/lib/scoring.js)
  core/timeline.dart               tìm câu/từ theo thời gian (port từ useShadowing.js)
  core/prefs.dart                  clientId, ngôn ngữ dịch, bật IPA (shared_preferences)
  shadowing/shadowing_controller.dart   state màn luyện: phát theo câu, ghi âm, chấm, lưu
  shadowing/voice.dart             ghi âm + nhận dạng giọng nói
  shadowing/translations_controller.dart  tải/dịch bản dịch
  screens/                         Home → Topic → Lesson
  widgets/                         FocusCard, SentenceList, StudyPanel, …
```

## Lưu ý

- **Nhận dạng giọng nói** dùng engine của hệ điều hành (Google trên Android, Apple trên iOS), cần mạng nếu máy chưa có gói offline tiếng Anh. Lần đầu app sẽ xin quyền Micro (và quyền Nhận dạng giọng nói trên iOS).
- **Nghe lại giọng mình:** trên **iOS** app vừa ghi file `.m4a` vừa nhận dạng, file được upload lên `/api/attempts` như bản web. Trên **Android**, SpeechRecognizer của hệ thống chiếm micro nên ghi song song thường bị câm, vì vậy Android chỉ chấm điểm, không lưu bản ghi (xem `Voice.recordsAudio`).
- Backend chấp nhận file `audio/mp4` (lưu đuôi `.m4a`), không cần đổi gì.
