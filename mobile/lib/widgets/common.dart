import 'package:flutter/material.dart';

// Màu giống bản web (frontend/src/styles.css)
const _accentLight = Color(0xFF4F46E5);
const _accentDark = Color(0xFF8B85FF);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: dark ? _accentDark : _accentLight,
    brightness: b,
    primary: dark ? _accentDark : _accentLight,
    surface: dark ? const Color(0xFF171A23) : Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0F1117) : const Color(0xFFF6F7FB),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: dark ? const Color(0xFF2A2F3D) : const Color(0xFFE3E6EE)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
  );
}

/// Màu theo điểm: >=85 tốt, >=60 tạm, còn lại kém
Color scoreColor(BuildContext context, int score) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (score >= 85) return dark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);
  if (score >= 60) return dark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  return dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.accent = false});
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: accent ? cs.onPrimaryContainer : cs.onSurfaceVariant),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off, size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ]),
      ),
    );
  }
}

class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.width, this.height, this.fit = BoxFit.cover});
  final String? url;
  final double? width, height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.headphones, color: Colors.grey),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      width: width,
      height: height,
      fit: fit,
      // Ảnh bìa khá nặng (~400KB): hiện placeholder trong lúc tải
      frameBuilder: (_, child, frame, sync) => frame == null && !sync ? placeholder : child,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.error = false, this.onTap});
  final String text;
  final bool error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: error ? cs.errorContainer : cs.secondaryContainer,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(
              child: Text(text, style: TextStyle(color: error ? cs.onErrorContainer : cs.onSecondaryContainer)),
            ),
            if (onTap != null) Icon(Icons.close, size: 16, color: error ? cs.onErrorContainer : cs.onSecondaryContainer),
          ]),
        ),
      ),
    );
  }
}
