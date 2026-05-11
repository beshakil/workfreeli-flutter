import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand / Interactive (matches web #2440bd) ─────────────────────────────
  static const Color primary = Color(0xFF2440BD);
  static const Color accent = Color(0xFF6366F1); // indigo
  static const Color accentSoft = Color(0xFFEEF2FF); // soft indigo bg

  // Backward-compat aliases kept so existing code compiles
  static const Color primaryLight = accent;
  static const Color primaryDark = Color(0xFF1E35A0);

  // ── Backgrounds (light — matches web) ────────────────────────────────────
  static const Color bg = Color(0xFFF1F5F9); // page bg
  static const Color bgCard = Color(0xFFFFFFFF); // card / panel
  static const Color bgElevated = Color(0xFFF8FAFC); // elevated surface
  static const Color bgHover = Color(0xFFF1F5F9); // hover state

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F2750); // near-black
  static const Color textMuted = Color(0xFF64748B); // secondary text
  static const Color textDim = Color(0xFF94A3B8); // placeholder / dim

  // ── Borders & Status ─────────────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  // ── Gradients ────────────────────────────────────────────────────────────
  // Matches web's blue→indigo button gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2440BD), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // accentGradient = same as primary (kept for existing references)
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF2440BD), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bannerGradient = LinearGradient(
    colors: [Color(0xFF2440BD), Color(0xFF6366F1), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Avatar Gradients ──────────────────────────────────────────────────────
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

  // ── Text Styles ───────────────────────────────────────────────────────────
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

  // ── Decorations ───────────────────────────────────────────────────────────
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

  // ── Theme Data (light — matches web) ─────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: bg,
        primaryColor: primary,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: accent,
          surface: bgCard,
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

  // Keep darkTheme pointing to lightTheme so existing references compile
  static ThemeData get darkTheme => lightTheme;
}
