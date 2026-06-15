import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brandDeep,
    required this.brand,
    required this.brandMid,
    required this.brandSoft,
    required this.brandTint,
    required this.brandTintStrong,
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceMuted,
    required this.surfacePill,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.borderSoft,
    required this.divider,
    required this.errorSoft,
    required this.errorText,
    required this.shadow,
  });

  final Color brandDeep;
  final Color brand;
  final Color brandMid;
  final Color brandSoft;
  final Color brandTint;
  final Color brandTintStrong;
  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color surfaceMuted;
  final Color surfacePill;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color borderSoft;
  final Color divider;
  final Color errorSoft;
  final Color errorText;
  final Color shadow;

  static const light = AppPalette(
    brandDeep: Color(0xFF245241),
    brand: Color(0xFF3F8066),
    brandMid: Color(0xFF5E9679),
    brandSoft: Color(0xFF7DAE94),
    brandTint: Color(0xFFE3F0E8),
    brandTintStrong: Color(0xFFEDF5F0),
    background: Color(0xFFF0E8DC),
    surface: Color(0xFFFFFCF7),
    surfaceSoft: Color(0xFFF7F2E9),
    surfaceMuted: Color(0xFFFBF8F2),
    surfacePill: Color(0xFFF2ECE2),
    textPrimary: Color(0xFF202320),
    textSecondary: Color(0xFF4E5550),
    border: Color(0xFFDDD3C4),
    borderSoft: Color(0xFFE5DCCE),
    divider: Color(0xFFE7DED1),
    errorSoft: Color(0xFFFFE6E2),
    errorText: Color(0xFF8A2D1F),
    shadow: Color(0x14000000),
  );

  static const dark = AppPalette(
    brandDeep: Color(0xFF143528),
    brand: Color(0xFF47A978),
    brandMid: Color(0xFF1D4636),
    brandSoft: Color(0xFF2A6650),
    brandTint: Color(0xFF1B2A23),
    brandTintStrong: Color(0xFF22342C),
    background: Color(0xFF101312),
    surface: Color(0xFF171B1A),
    surfaceSoft: Color(0xFF1D2221),
    surfaceMuted: Color(0xFF202725),
    surfacePill: Color(0xFF2A3130),
    textPrimary: Color(0xFFF7FAF8),
    textSecondary: Color(0xFFC7D0CB),
    border: Color(0xFF2C3432),
    borderSoft: Color(0xFF343E3A),
    divider: Color(0xFF29312F),
    errorSoft: Color(0xFF3B2325),
    errorText: Color(0xFFFFB4AB),
    shadow: Color(0x29000000),
  );

  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>()!;
  }

  @override
  ThemeExtension<AppPalette> copyWith({
    Color? brandDeep,
    Color? brand,
    Color? brandMid,
    Color? brandSoft,
    Color? brandTint,
    Color? brandTintStrong,
    Color? background,
    Color? surface,
    Color? surfaceSoft,
    Color? surfaceMuted,
    Color? surfacePill,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? borderSoft,
    Color? divider,
    Color? errorSoft,
    Color? errorText,
    Color? shadow,
  }) {
    return AppPalette(
      brandDeep: brandDeep ?? this.brandDeep,
      brand: brand ?? this.brand,
      brandMid: brandMid ?? this.brandMid,
      brandSoft: brandSoft ?? this.brandSoft,
      brandTint: brandTint ?? this.brandTint,
      brandTintStrong: brandTintStrong ?? this.brandTintStrong,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfacePill: surfacePill ?? this.surfacePill,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      borderSoft: borderSoft ?? this.borderSoft,
      divider: divider ?? this.divider,
      errorSoft: errorSoft ?? this.errorSoft,
      errorText: errorText ?? this.errorText,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  ThemeExtension<AppPalette> lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }

    return AppPalette(
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandMid: Color.lerp(brandMid, other.brandMid, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      brandTintStrong: Color.lerp(brandTintStrong, other.brandTintStrong, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfacePill: Color.lerp(surfacePill, other.surfacePill, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
