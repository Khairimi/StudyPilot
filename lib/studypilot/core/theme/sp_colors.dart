import 'package:flutter/material.dart';

/// StudyPilot colour tokens, taken from the Google AI Studio prototype
/// (Tailwind indigo / slate / emerald / amber / rose palettes).
class SpColors {
  SpColors._();

  // Brand (indigo)
  static const Color indigo50 = Color(0xFFEEF2FF);
  static const Color indigo100 = Color(0xFFE0E7FF);
  static const Color indigo300 = Color(0xFFA5B4FC);
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color indigo700 = Color(0xFF4338CA);
  static const Color indigo950 = Color(0xFF1E1B4B);

  // Neutrals (slate)
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color night = Color(0xFF090D16); // dark app background

  // Success (emerald)
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald950 = Color(0xFF022C22);

  // Warning / conflicts (amber)
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber950 = Color(0xFF451A03);

  // Danger / urgent (rose)
  static const Color rose50 = Color(0xFFFFF1F2);
  static const Color rose400 = Color(0xFFFB7185);
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose950 = Color(0xFF4C0519);

  // Info (sky)
  static const Color sky50 = Color(0xFFF0F9FF);
  static const Color sky400 = Color(0xFF38BDF8);
  static const Color sky600 = Color(0xFF0284C7);
  static const Color sky950 = Color(0xFF082F49);

  // Semantic aliases
  static const Color primary = indigo600;
  static const Color primaryDarkMode = indigo400;

  /// Member colours for avatars, charts and workload bars.
  static const List<Color> memberPalette = [
    Color(0xFF6366F1), // indigo
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFF43F5E), // rose
    Color(0xFF0EA5E9), // sky
    Color(0xFF8B5CF6), // violet
    Color(0xFF14B8A6), // teal
    Color(0xFFF97316), // orange
  ];

  /// Stable colour for a member id (same id → same colour everywhere).
  static Color memberColor(String seed) {
    if (seed.isEmpty) return memberPalette.first;
    final hash = seed.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
    return memberPalette[hash % memberPalette.length];
  }
}

/// A soft background + strong foreground pair used by badges and chips.
@immutable
class SpTone {
  final Color background;
  final Color foreground;
  const SpTone(this.background, this.foreground);

  static SpTone _pick(BuildContext context, SpTone light, SpTone dark) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static SpTone neutral(BuildContext c) => _pick(c,
      const SpTone(SpColors.slate100, SpColors.slate600),
      const SpTone(SpColors.slate800, SpColors.slate300));
  static SpTone brand(BuildContext c) => _pick(c,
      const SpTone(SpColors.indigo50, SpColors.indigo700),
      const SpTone(SpColors.indigo950, SpColors.indigo300));
  static SpTone success(BuildContext c) => _pick(c,
      const SpTone(SpColors.emerald50, SpColors.emerald600),
      const SpTone(SpColors.emerald950, SpColors.emerald400));
  static SpTone warning(BuildContext c) => _pick(c,
      const SpTone(SpColors.amber50, SpColors.amber700),
      const SpTone(SpColors.amber950, SpColors.amber400));
  static SpTone danger(BuildContext c) => _pick(c,
      const SpTone(SpColors.rose50, SpColors.rose600),
      const SpTone(SpColors.rose950, SpColors.rose400));
  static SpTone info(BuildContext c) => _pick(c,
      const SpTone(SpColors.sky50, SpColors.sky600),
      const SpTone(SpColors.sky950, SpColors.sky400));
}
