import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimensions.dart';
import '../tokens/component_colors.dart';
import '../typography/app_typography.dart';

/// Builds the OrbiJob (identity C, Minimal Tech) themes from the generated tokens.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.secondary,
      onSecondary: c.onSecondary,
      secondaryContainer: c.secondaryContainer,
      onSecondaryContainer: c.onSecondaryContainer,
      tertiary: c.success,
      onTertiary: c.onSuccess,
      tertiaryContainer: c.successContainer,
      onTertiaryContainer: c.onSuccessContainer,
      error: c.error,
      onError: c.onError,
      errorContainer: c.errorContainer,
      onErrorContainer: c.onErrorContainer,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.bg,
      surfaceContainer: c.container,
      surfaceContainerHigh: c.containerHigh,
      surfaceContainerHighest: c.containerHigh,
      outline: c.outline,
      outlineVariant: c.divider,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: c.ink,
      onInverseSurface: c.bg,
      inversePrimary: c.primaryContainer,
      surfaceTint: const Color(0x00000000),
    );
    final text = AppTypography.textTheme(c);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: c.hairline),
    );
    final layers = WidgetStateProperty.resolveWith<Color?>((s) {
      if (s.contains(WidgetState.pressed)) {
        return c.pressedLayer;
      }
      if (s.contains(WidgetState.focused)) {
        return c.focusLayer;
      }
      if (s.contains(WidgetState.hovered)) {
        return c.hoverLayer;
      }
      return null;
    });
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      textTheme: text,
      primaryTextTheme: text,
      extensions: <ThemeExtension<dynamic>>[c],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: NoSplash.splashFactory,
      focusColor: c.focusLayer,
      hoverColor: c.hoverLayer,
      highlightColor: c.pressedLayer,
      dividerColor: c.divider,
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: b == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      iconTheme: IconThemeData(color: c.ink, size: AppSize.icon),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.container,
        hintStyle: text.bodyLarge!.copyWith(color: c.inputPlaceholder),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s3 + 2,
        ),
        border: border(c.container),
        enabledBorder: border(c.container),
        focusedBorder: border(c.inputBorderFocused, 2),
        errorBorder: border(c.error),
        focusedErrorBorder: border(c.error, 2),
        disabledBorder: border(c.divider),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: const Color(0x00000000),
        shape: cardShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: const Color(0x00000000),
        showDragHandle: true,
        dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        constraints: const BoxConstraints(maxWidth: AppSize.sheetMaxWidth),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: const Color(0x00000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.muted),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: c.hairline),
        ),
        textStyle: text.bodyMedium!.copyWith(color: c.ink),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.ink,
        shape: shape,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.container,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.clear : c.muted,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        side: BorderSide(color: c.outline, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : null,
        ),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.outline,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSize.touch, AppSize.touch),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpace.s5),
          ),
          shape: WidgetStatePropertyAll(shape),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.disabledBg : c.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.disabled) ? c.disabledFg : c.onPrimary,
          ),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((s) {
            if (s.contains(WidgetState.pressed)) {
              return c.onPrimary.withValues(alpha: AppStateLayer.pressed);
            }
            if (s.contains(WidgetState.focused)) {
              return c.onPrimary.withValues(alpha: AppStateLayer.focus);
            }
            if (s.contains(WidgetState.hovered)) {
              return c.onPrimary.withValues(alpha: AppStateLayer.hover);
            }
            return null;
          }),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSize.touch, AppSize.touch),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpace.s5),
          ),
          shape: WidgetStatePropertyAll(shape),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.disabledFg : c.primary,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.disabled) ? c.divider : c.line,
              width: 1,
            ),
          ),
          overlayColor: layers,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSize.touch, AppSize.touch),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpace.s4),
          ),
          shape: WidgetStatePropertyAll(shape),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.disabledFg : c.primary,
          ),
          overlayColor: layers,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSize.touch, AppSize.touch),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.disabledFg : c.ink,
          ),
          overlayColor: layers,
          shape: WidgetStatePropertyAll(shape),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSize.touch, AppSize.touch),
          ),
          shape: WidgetStatePropertyAll(shape),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          side: WidgetStatePropertyAll(BorderSide(color: c.outline)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? c.chipSelectedBg : c.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.chipSelectedFg : c.ink,
          ),
          overlayColor: layers,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.loading,
        linearTrackColor: c.divider,
        circularTrackColor: c.divider,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.bg),
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: text.bodySmall!.copyWith(color: c.bg),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(),
    );
  }
}
