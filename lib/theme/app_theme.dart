import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Thème Material 3 de TAKYMED : palette marque, typographie Inter,
/// composants arrondis et ombres douces.
class AppTheme {
  AppTheme._();

  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.primaryForeground,
    primaryContainer: AppColors.primaryLight,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.secondaryLight,
    onSecondaryContainer: AppColors.secondaryDark,
    tertiary: AppColors.ai,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.aiLight,
    onTertiaryContainer: Color(0xFF4C1D95),
    error: AppColors.destructive,
    onError: Colors.white,
    errorContainer: AppColors.destructiveLight,
    onErrorContainer: Color(0xFF991B1B),
    surface: AppColors.surface,
    onSurface: AppColors.foreground,
    surfaceContainerHighest: AppColors.surfaceMuted,
    surfaceContainerHigh: Color(0xFFF4F7FA),
    surfaceContainer: Color(0xFFF7FAFC),
    surfaceContainerLow: Color(0xFFFAFCFD),
    surfaceContainerLowest: Colors.white,
    onSurfaceVariant: AppColors.mutedForeground,
    outline: AppColors.border,
    outlineVariant: AppColors.surfaceMuted,
    shadow: Color(0xFF0F172A),
    scrim: Color(0xFF0F172A),
    inverseSurface: AppColors.foreground,
    onInverseSurface: Colors.white,
    inversePrimary: Color(0xFF8FC9E8),
    surfaceTint: Colors.transparent,
  );

  static TextTheme _textTheme() {
    final base = GoogleFonts.interTextTheme();
    const color = AppColors.foreground;
    const muted = AppColors.mutedForeground;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40, fontWeight: FontWeight.w800, color: color, letterSpacing: -1.2, height: 1.1),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 34, fontWeight: FontWeight.w800, color: color, letterSpacing: -1, height: 1.1),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 30, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.8, height: 1.15),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 28, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.6, height: 1.2),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5, height: 1.2),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 21, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.3, height: 1.25),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.2, height: 1.3),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.1, height: 1.35),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w700, color: color, height: 1.35),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16, fontWeight: FontWeight.w400, color: color, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w400, color: color, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12, fontWeight: FontWeight.w400, color: muted, height: 1.45),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.1),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12, fontWeight: FontWeight.w600, color: muted, letterSpacing: 0.2),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11, fontWeight: FontWeight.w600, color: muted, letterSpacing: 0.4),
    );
  }

  static ThemeData get light {
    final textTheme = _textTheme();
    final inter = GoogleFonts.inter();

    OutlineInputBorder inputBorder(Color color, {double width = 1}) => OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      fontFamily: inter.fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      dividerColor: AppColors.border,
      disabledColor: AppColors.subtleForeground,
      hintColor: AppColors.subtleForeground,
      iconTheme: const IconThemeData(color: AppColors.foreground, size: 22),
      primaryIconTheme: const IconThemeData(color: AppColors.primary, size: 22),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.page,
        iconTheme: const IconThemeData(color: AppColors.foreground, size: 22),
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rLg,
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder(AppColors.border),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.primary, width: 1.6),
        errorBorder: inputBorder(AppColors.destructive),
        focusedErrorBorder: inputBorder(AppColors.destructive, width: 1.6),
        disabledBorder: inputBorder(AppColors.surfaceMuted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.subtleForeground),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: AppColors.primary),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.destructive),
        prefixIconColor: AppColors.mutedForeground,
        suffixIconColor: AppColors.mutedForeground,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          side: const BorderSide(color: AppColors.border, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rSm),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.foreground,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rSm),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        extendedTextStyle: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.foreground,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
        actionTextColor: AppColors.secondarySoft,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.primaryLight,
        secondarySelectedColor: AppColors.primaryLight,
        disabledColor: AppColors.surfaceMuted,
        checkmarkColor: AppColors.primary,
        deleteIconColor: AppColors.mutedForeground,
        labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.foreground, fontSize: 13),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: AppColors.primary, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rPill),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryLight,
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.mutedForeground,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.primary : AppColors.mutedForeground,
          );
        }),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.mutedForeground,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        dragHandleSize: Size(40, 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: AppColors.mutedForeground,
        textColor: AppColors.foreground,
        titleTextStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.surfaceMuted;
          if (states.contains(WidgetState.selected)) return AppColors.secondary;
          return AppColors.borderStrong;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.borderStrong;
        }),
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.primaryLight,
        thumbColor: AppColors.primary,
        overlayColor: Color(0x22006093),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryLight,
        circularTrackColor: AppColors.primaryLight,
        linearMinHeight: 8,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.mutedForeground,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return AppColors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return AppColors.foreground;
          }),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: AppRadius.rMd)),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium?.copyWith(fontSize: 13)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.foreground.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        textStyle: textTheme.bodyMedium,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.foreground, borderRadius: AppRadius.rSm),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium,
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: AppRadius.rMd)),
        ),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        hourMinuteShape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        dayPeriodShape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        dialHandColor: AppColors.primary,
        dialBackgroundColor: AppColors.primaryLight,
        hourMinuteColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.primaryLight : AppColors.surfaceMuted),
        hourMinuteTextColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.primary : AppColors.foreground),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: Colors.white,
        dayShape: const WidgetStatePropertyAll(CircleBorder()),
        todayBorder: const BorderSide(color: AppColors.primary),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
