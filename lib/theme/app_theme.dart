import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand / Interactive (matches web #2440bd) ─────────────────────────────
  static const Color primary = Color(0xFF2440BD);
  static const Color accent = Color(0xFF6366F1); // indigo
  static const Color accentSoft = Color(0xFFEEF2FF); // soft indigo bg (light)

  // Dark mode brand
  static const Color primaryDark_dm = Color(0xFF4F6AE8); // brighter for dark bg
  static const Color accentDark_dm =
      Color(0xFF818CF8); // lighter indigo for dark
  static const Color accentSoftDark_dm = Color(0xFF1E1B4B); // deep indigo bg

  // Backward-compat aliases
  static const Color primaryLight = accent;
  static const Color primaryDark = Color(0xFF1E35A0);

  // ── Backgrounds (light) ───────────────────────────────────────────────────
  static const Color bg = Color(0xFFF1F5F9);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgElevated = Color(0xFFF8FAFC);
  static const Color bgHover = Color(0xFFF1F5F9);

  // ── Backgrounds (dark) ───────────────────────────────────────────────────
  static const Color bg_dm = Color(0xFF0D1117); // page bg — deep navy-black
  static const Color bgCard_dm = Color(0xFF161B27); // card / panel
  static const Color bgElevated_dm = Color(0xFF1E2535); // elevated surface
  static const Color bgHover_dm = Color(0xFF252D3D); // hover state

  // ── Text (light) ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F2750);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDim = Color(0xFF64748B);

  // ── Text (dark) ──────────────────────────────────────────────────────────
  static const Color textPrimary_dm = Color(0xFFE2E8F0); // near-white
  static const Color textMuted_dm = Color(0xFF94A3B8); // secondary text
  static const Color textDim_dm = Color(0xFF64748B); // placeholder / dim

  // ── Borders & Status (light) ─────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  // ── Borders & Status (dark) ──────────────────────────────────────────────
  static const Color border_dm = Color(0xFF2D3748); // subtle dark border
  static const Color danger_dm = Color(0xFFF87171); // lighter red for dark bg
  static const Color warning_dm = Color(0xFFFBBF24); // lighter amber
  static const Color success_dm = Color(0xFF34D399); // lighter green

  // ── Gradients (light + dark share same direction; colors shift) ───────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2440BD), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient_dm = LinearGradient(
    colors: [Color(0xFF4F6AE8), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF2440BD), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient_dm = LinearGradient(
    colors: [Color(0xFF4F6AE8), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bannerGradient = LinearGradient(
    colors: [Color(0xFF2440BD), Color(0xFF6366F1), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bannerGradient_dm = LinearGradient(
    colors: [Color(0xFF3B55D4), Color(0xFF6366F1), Color(0xFFA5B4FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Avatar Gradients ──────────────────────────────────────────────────────
  // Light (same as before)
  static const LinearGradient avatarBlue = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
  );
  static const LinearGradient avatarCyan = LinearGradient(
    colors: [Color(0xFF0E7490), Color(0xFF22D3EE)],
  );
  static const LinearGradient avatarIndigo = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF6366F1)],
  );
  static const LinearGradient avatarPink = LinearGradient(
    colors: [Color(0xFFBE185D), Color(0xFFEC4899)],
  );

  // Dark (brighter/lighter to pop on dark surfaces)
  static const LinearGradient avatarBlue_dm = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
  );
  static const LinearGradient avatarCyan_dm = LinearGradient(
    colors: [Color(0xFF0891B2), Color(0xFF67E8F9)],
  );
  static const LinearGradient avatarIndigo_dm = LinearGradient(
    colors: [Color(0xFF4338CA), Color(0xFFA5B4FC)],
  );
  static const LinearGradient avatarPink_dm = LinearGradient(
    colors: [Color(0xFFDB2777), Color(0xFFF9A8D4)],
  );

  // ── Text Styles (light) ───────────────────────────────────────────────────
  static TextStyle get headingLarge => GoogleFonts.sora(
      fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary);

  static TextStyle get headingMedium => GoogleFonts.sora(
      fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary);

  static TextStyle get headingSmall => GoogleFonts.sora(
      fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary);

  static TextStyle get bodyLarge =>
      GoogleFonts.dmSans(fontSize: 15, color: textPrimary);

  static TextStyle get bodyMedium =>
      GoogleFonts.dmSans(fontSize: 14, color: textPrimary);

  static TextStyle get bodySmall =>
      GoogleFonts.dmSans(fontSize: 13, color: textMuted);

  static TextStyle get caption =>
      GoogleFonts.dmSans(fontSize: 12, color: textDim);

  static TextStyle get labelSmall => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: textDim,
      );

  // ── Text Styles (dark) ────────────────────────────────────────────────────
  static TextStyle get headingLarge_dm => GoogleFonts.sora(
      fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary_dm);

  static TextStyle get headingMedium_dm => GoogleFonts.sora(
      fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary_dm);

  static TextStyle get headingSmall_dm => GoogleFonts.sora(
      fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary_dm);

  static TextStyle get bodyLarge_dm =>
      GoogleFonts.dmSans(fontSize: 15, color: textPrimary_dm);

  static TextStyle get bodyMedium_dm =>
      GoogleFonts.dmSans(fontSize: 14, color: textPrimary_dm);

  static TextStyle get bodySmall_dm =>
      GoogleFonts.dmSans(fontSize: 13, color: textMuted_dm);

  static TextStyle get caption_dm =>
      GoogleFonts.dmSans(fontSize: 12, color: textDim_dm);

  static TextStyle get labelSmall_dm => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: textDim_dm,
      );

  // ── Decorations (light) ───────────────────────────────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static BoxDecoration get elevatedDecoration => BoxDecoration(
        color: bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      );

  // ── Decorations (dark) ────────────────────────────────────────────────────
  static BoxDecoration get cardDecoration_dm => BoxDecoration(
        color: bgCard_dm,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border_dm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration get elevatedDecoration_dm => BoxDecoration(
        color: bgElevated_dm,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border_dm),
      );

  // ── Theme Data (light) ────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: bg,
        primaryColor: primary,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: accent,
          surface: bgCard,
          onSurface: textPrimary,
          onPrimary: Colors.white,
          outline: border,
          error: danger,
        ),
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: bgCard,
          elevation: 0,
          iconTheme: const IconThemeData(color: textPrimary),
          titleTextStyle: headingSmall,
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: border,
        cardColor: bgCard,
      );

  // ── Theme Data (dark) ─────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg_dm,
        primaryColor: primaryDark_dm,
        colorScheme: const ColorScheme.dark(
          primary: primaryDark_dm,
          secondary: accentDark_dm,
          surface: bgCard_dm,
          onSurface: textPrimary_dm,
          onPrimary: Colors.white,
          outline: border_dm,
          error: danger_dm,
        ),
        textTheme:
            GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: textPrimary_dm,
          displayColor: textPrimary_dm,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bgCard_dm,
          elevation: 0,
          iconTheme: const IconThemeData(color: textPrimary_dm),
          titleTextStyle: headingSmall_dm,
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: border_dm,
        cardColor: bgCard_dm,
      );
}
