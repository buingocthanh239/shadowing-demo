// Chọn provider dịch máy qua biến môi trường TRANSLATE_PROVIDER.
// Thêm provider mới (DeepL, Google Cloud, Claude...): tạo file cùng interface
//   { name, supports(lang, source): Promise<boolean>, translate(texts, {source, target}): Promise<string[]> }
// rồi đăng ký vào PROVIDERS.
import libretranslate from './libretranslate.js';

const none = {
  name: 'none',
  supports: async () => false,
  translate: async () => {
    throw new Error('Chưa cấu hình TRANSLATE_PROVIDER');
  },
};

const PROVIDERS = { libretranslate, none };

export const translator = PROVIDERS[process.env.TRANSLATE_PROVIDER || 'libretranslate'] ?? none;
