import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Consistent light/dark Material 3 themes built on the Inter type scale
/// (matches the LeadX web UI).
///
/// - Light: clean neutral background, solid white content surfaces, subtle
///   borders + soft shadows.
/// - Dark: premium near-black background, clear text contrast, readable
///   financial cards on elevated surfaces.
class AppTheme {
  AppTheme._();

  static const _seed = AppColors.brand;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Dark seed is the near-white brand accent (#FAFAFA) so dark-mode
    // primary/onPrimary stay legible on near-black surfaces.
    //
    // M3's tonal palette drifts toward a saturated hue even for
    // near-black/near-white seeds (seeding #FAFAFA in dark yields a teal
    // primary/primaryContainer ~0x82D3E0/0x004F58), which breaks the flat
    // neutral palette — so the primary/secondary pairs are pinned to
    // explicit neutrals: black #171717 on #E5E5E5 (light) and #FAFAFA on
    // #262626 (dark). Secondary follows neutral grey so secondary
    // containers (selected chips) stay dark-neutral in dark mode.
    final cs = ColorScheme.fromSeed(
      seedColor: isDark ? AppColors.brandDark : _seed,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.brandDark : AppColors.brand,
      onPrimary: isDark ? AppColors.brand : Colors.white,
      // Dark: #404040 so selected/indicator states stay visible against
      // the #262626 surface (chip selectedColor, nav indicator, avatar
      // highlight all ride on primaryContainer).
      primaryContainer: isDark ? const Color(0xFF404040) : const Color(0xFFE5E5E5),
      onPrimaryContainer: isDark ? AppColors.brandDark : AppColors.brand,
      secondary: isDark ? const Color(0xFFBFBFBF) : const Color(0xFF525252),
      onSecondary: isDark ? AppColors.brand : Colors.white,
      secondaryContainer: isDark ? const Color(0xFF404040) : const Color(0xFFE5E5E5),
      onSecondaryContainer: isDark ? AppColors.brandDark : const Color(0xFF3F3F3F),
      surface: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
      surfaceContainerHighest:
          isDark ? const Color(0xFF262626) : const Color(0xFFE5E5E5),
    );

    final cardRadius = BorderRadius.circular(AppColors.radiusLg);
    final cardShape = RoundedRectangleBorder(borderRadius: cardRadius);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: brightness,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: AppTypography.textTheme(),
      splashFactory: InkSparkle.splashFactory,

      scaffoldBackgroundColor: isDark
          ? AppColors.neutralBgDark
          : AppColors.neutralBgLight,

      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        margin: EdgeInsets.zero,
        shape: cardShape,
        clipBehavior: Clip.antiAlias,
      ),

      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.all(12)),

      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.pageTitle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
        actionsIconTheme: IconThemeData(color: cs.onSurfaceVariant),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // §5: 48px minimum input height — guaranteed by the 14px vertical
        // contentPadding on a 16px text line (≈52px tall). 8px radius
        // (spec §5, inputs 8px); 1px grey border. Input text stays 16px
        // (iOS zoom rule) — fields inherit the theme's body tier (16px)
        // unless a screen overrides.
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide(color: cs.outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide(color: cs.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          // Neutral 2px focus ring — deliberately neither blue nor the
          // brand primary (spec §2: "never blue").
          borderSide: BorderSide(color: cs.outline, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide(color: cs.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        labelStyle: AppTypography.body.copyWith(color: cs.onSurfaceVariant),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.brandDark : AppColors.brand,
          foregroundColor: isDark ? AppColors.brand : Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          textStyle: AppTypography.body.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.brand,
          side: BorderSide(
            color: isDark ? const Color(0xFF404040) : const Color(0xFFE5E5E5),
            width: 1,
          ),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          textStyle: AppTypography.body.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 36),
          textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
        titleTextStyle: AppTypography.sectionTitle.copyWith(color: cs.onSurface),
        contentTextStyle: AppTypography.body.copyWith(color: cs.onSurfaceVariant),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? cs.surfaceContainerHighest : Colors.white,
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
        labelStyle: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant),
        selectedColor: cs.primaryContainer,
        secondaryLabelStyle:
            AppTypography.secondary.copyWith(color: cs.onPrimaryContainer),
        elevation: 0,
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
        disabledColor: cs.surfaceContainerHighest,
        secondarySelectedColor: cs.secondaryContainer,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle: AppTypography.secondary.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.primary),

      tabBarTheme: TabBarThemeData(
        labelStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
