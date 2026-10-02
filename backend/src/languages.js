// Danh sách ngôn ngữ dịch được seed vào bảng `languages`.
// Thêm ngôn ngữ mới: thêm 1 dòng ở đây (hoặc INSERT thẳng vào DB) + đảm bảo provider dịch hỗ trợ.
export const LANGUAGES = [
  { code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt' },
  { code: 'ja', name: 'Japanese', nativeName: '日本語' },
  { code: 'ko', name: 'Korean', nativeName: '한국어' },
  { code: 'zh-Hans', name: 'Chinese (Simplified)', nativeName: '中文（简体）' },
  { code: 'th', name: 'Thai', nativeName: 'ไทย' },
  { code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia' },
  { code: 'fr', name: 'French', nativeName: 'Français' },
  { code: 'es', name: 'Spanish', nativeName: 'Español' },
  { code: 'de', name: 'German', nativeName: 'Deutsch' },
  { code: 'pt', name: 'Portuguese', nativeName: 'Português' },
  { code: 'ru', name: 'Russian', nativeName: 'Русский' },
];

// Ngôn ngữ của nội dung gốc
export const SOURCE_LANG = 'en';
