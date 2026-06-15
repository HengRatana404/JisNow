import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/rental_models.dart';
import '../theme/app_palette.dart';

int? _cacheDimension(BuildContext context, double logicalPixels) {
  if (!logicalPixels.isFinite || logicalPixels <= 0) {
    return null;
  }

  final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
  return (logicalPixels * devicePixelRatio).round();
}

String _optimizedProfileImageUrl(String imageUrl) {
  final normalized = imageUrl.trim();
  if (normalized.isEmpty) {
    return normalized;
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return normalized;
  }

  final host = uri.host.toLowerCase();
  if (!host.contains('googleusercontent.com')) {
    return normalized;
  }

  const highResMarker = 's512-c';
  final sizedPath = normalized.replaceAllMapped(
    RegExp(r'/s\d+(?:-c)?(?=/)'),
    (_) => '/$highResMarker',
  );
  if (sizedPath != normalized) {
    return sizedPath;
  }

  final sizedQueryStyle = normalized.replaceAllMapped(
    RegExp(r'=s\d+(?:-c)?$'),
    (_) => '=$highResMarker',
  );
  if (sizedQueryStyle != normalized) {
    return sizedQueryStyle;
  }

  return '$normalized=$highResMarker';
}

Widget _cachedNetworkImage({
  required String imageUrl,
  required BoxFit fit,
  required Widget Function() placeholderBuilder,
  required Widget Function() errorBuilder,
  double? width,
  double? height,
  int? memCacheWidth,
  int? memCacheHeight,
}) {
  if (kIsWeb) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: memCacheWidth,
      cacheHeight: memCacheHeight,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return placeholderBuilder();
      },
      errorBuilder: (context, error, stackTrace) => errorBuilder(),
    );
  }

  return CachedNetworkImage(
    imageUrl: imageUrl,
    width: width,
    height: height,
    fit: fit,
    memCacheWidth: memCacheWidth,
    memCacheHeight: memCacheHeight,
    fadeInDuration: const Duration(milliseconds: 120),
    placeholder: (context, url) => placeholderBuilder(),
    errorWidget: (context, url, error) => errorBuilder(),
  );
}

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.selectedUnit,
    required this.isSelected,
    required this.onTap,
    this.onBookTap,
  });

  final Vehicle vehicle;
  final RentalUnit selectedUnit;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onBookTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final accentTextColor = theme.brightness == Brightness.light
        ? colors.textPrimary
        : colors.brand;
    final buttonBackgroundColor = theme.brightness == Brightness.light
        ? colors.brandDeep
        : colors.brand;
    final hasImage = vehicle.imageUrl.trim().isNotEmpty;
    final isAssetImage = vehicle.imageUrl.startsWith('assets/');
    final cacheHeight = _cacheDimension(context, 180);
    final imageSurface = hasImage
        ? (isAssetImage
            ? Image.asset(
                vehicle.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheHeight: cacheHeight,
              )
            : _cachedNetworkImage(
                imageUrl: vehicle.imageUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                memCacheHeight: cacheHeight,
                placeholderBuilder: () => const _ImageLoadingPlaceholder(
                  height: 180,
                  width: double.infinity,
                ),
                errorBuilder: () => _VehicleArtwork(vehicle: vehicle),
              ))
        : _VehicleArtwork(vehicle: vehicle);
    final primaryHub = vehicle.primaryPickupHub;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected ? colors.brandTintStrong : colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? colors.brandSoft : colors.border,
            width: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VehicleCardImageShell(
              topLeftBadge: _VehicleHeroBadge(
                icon: Icons.bolt_rounded,
                text: vehicle.displayEnergyLabel,
              ),
              topRightBadge: _VehicleHeroBadge(
                icon: Icons.star_rounded,
                text: vehicle.rating.toStringAsFixed(1),
                highlight: true,
              ),
              bottomLeftBadge: _VehicleHeroBadge(
                icon: Icons.place_outlined,
                text: primaryHub,
              ),
              child: imageSurface,
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vehicle.type.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vehicle.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SpecPill(
                        icon: Icons.airline_seat_recline_normal,
                        text: '${vehicle.seats} seats',
                      ),
                      SpecPill(icon: Icons.settings, text: vehicle.transmission),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${vehicle.rateFor(selectedUnit).price.toStringAsFixed(0)} / ${selectedUnit.label.toLowerCase()}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: accentTextColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: onBookTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: buttonBackgroundColor,
                          foregroundColor: Colors.white,
                          shadowColor: theme.brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.24)
                              : null,
                          elevation: theme.brightness == Brightness.dark ? 2 : 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: const Text('Book'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCardImageShell extends StatelessWidget {
  const _VehicleCardImageShell({
    required this.child,
    this.topLeftBadge,
    this.topRightBadge,
    this.bottomLeftBadge,
  });

  final Widget child;
  final Widget? topLeftBadge;
  final Widget? topRightBadge;
  final Widget? bottomLeftBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 22,
            right: 22,
            bottom: -10,
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.32),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 196,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: const Color(0xFF0E3B2C).withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.02),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                  if (topLeftBadge != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: topLeftBadge!,
                    ),
                  if (topRightBadge != null)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: topRightBadge!,
                    ),
                  if (bottomLeftBadge != null)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: bottomLeftBadge!,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleHeroBadge extends StatelessWidget {
  const _VehicleHeroBadge({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.black.withValues(alpha: 0.56)
            : Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight ? const Color(0xFF7EE0B3) : Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleArtwork extends StatelessWidget {
  const _VehicleArtwork({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(vehicle.type);
    final soft = _softColor(vehicle.type);

    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            soft,
            accent.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                vehicle.displayEnergyLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Icon(
              vehicle.type.icon,
              size: 76,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  vehicle.location,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _accentColor(VehicleType type) {
    switch (type) {
      case VehicleType.car:
        return const Color(0xFF1E6B52);
      case VehicleType.motorbike:
        return const Color(0xFF146C5A);
      case VehicleType.bicycle:
        return const Color(0xFF327C4C);
    }
  }

  Color _softColor(VehicleType type) {
    switch (type) {
      case VehicleType.car:
        return const Color(0xFF93D7C3);
      case VehicleType.motorbike:
        return const Color(0xFF88D8C2);
      case VehicleType.bicycle:
        return const Color(0xFFA8D89C);
    }
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder({
    required this.height,
    required this.width,
  });

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.surfaceSoft,
            colors.surfaceMuted,
            colors.surfaceSoft,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: colors.brand,
          ),
        ),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...[
                SizedBox(height: compact ? 4 : 6),
                Text(
                  subtitle!.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconBackground = isDarkMode
        ? const Color(0xFF183529)
        : colors.brandTintStrong;
    final iconColor = isDarkMode
        ? const Color(0xFF7EE0B3)
        : colors.brandDeep;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 26, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          if ((actionLabel ?? '').trim().isNotEmpty && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel!.trim()),
            ),
          ],
        ],
      ),
    );
  }
}

class AppLoadingCard extends StatelessWidget {
  const AppLoadingCard({
    super.key,
    this.height = 120,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final isCompact = height < 104;
    final verticalPadding = isCompact ? 12.0 : 18.0;
    final barHeight = isCompact ? 10.0 : 12.0;
    final gapLarge = isCompact ? 8.0 : 12.0;
    final gapSmall = isCompact ? 6.0 : 10.0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      padding: EdgeInsets.all(verticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LoadingBar(widthFactor: 0.42, height: barHeight),
          SizedBox(height: gapLarge),
          _LoadingBar(widthFactor: 0.78, height: barHeight),
          SizedBox(height: gapSmall),
          _LoadingBar(widthFactor: 0.58, height: barHeight),
          const Spacer(),
          _LoadingBar(widthFactor: 0.32, height: barHeight),
        ],
      ),
    );
  }
}

class AppInlineNotice extends StatelessWidget {
  const AppInlineNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = AppBannerTone.info,
  });

  final IconData icon;
  final String title;
  final String message;
  final AppBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final (background, border, iconColor) = switch (tone) {
      AppBannerTone.success => (
          colors.brandTint,
          colors.brand.withValues(alpha: 0.20),
          colors.brandDeep,
        ),
      AppBannerTone.info => (
          colors.surfaceSoft,
          colors.borderSoft,
          colors.brand,
        ),
      AppBannerTone.warning => (
          const Color(0xFF4A3920),
          const Color(0xFF8B6A2E),
          const Color(0xFFFFD47A),
        ),
      AppBannerTone.error => (
          colors.errorSoft,
          colors.errorText.withValues(alpha: 0.20),
          colors.errorText,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({
    required this.widthFactor,
    this.height = 12,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

enum AppBannerTone { success, info, warning, error }

void showAppBanner(
  BuildContext context, {
  required String message,
  AppBannerTone tone = AppBannerTone.info,
  IconData? icon,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final colors = AppPalette.of(context);
  final theme = Theme.of(context);
  final (background, foreground, fallbackIcon) = switch (tone) {
    AppBannerTone.success => (colors.brandDeep, Colors.white, Icons.check_circle_rounded),
    AppBannerTone.info => (colors.textPrimary, Colors.white, Icons.info_rounded),
    AppBannerTone.warning => (const Color(0xFF7C5A10), Colors.white, Icons.warning_amber_rounded),
    AppBannerTone.error => (colors.errorText, Colors.white, Icons.error_rounded),
  };

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon ?? fallbackIcon, color: foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showVehicleDetailsSheet(
  BuildContext context, {
  required Vehicle vehicle,
  required String primaryActionLabel,
  required VoidCallback onPrimaryAction,
  String? secondaryActionLabel,
  VoidCallback? onSecondaryAction,
}) async {
  final theme = Theme.of(context);
  final colors = AppPalette.of(context);
  final isLightMode = theme.brightness == Brightness.light;
  final accentTextColor = isLightMode ? colors.textPrimary : const Color(0xFF7ED2A6);
  final bodyTextColor = isLightMode ? colors.textSecondary : colors.textPrimary;
  final rates = [...vehicle.rates]..sort((a, b) => a.unit.index.compareTo(b.unit.index));
  final galleryImages = vehicle.allImageUrls;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: vehicle.imageUrl.trim().startsWith('assets/')
                    ? Image.asset(
                        vehicle.imageUrl,
                        width: double.infinity,
                        height: 172,
                        fit: BoxFit.cover,
                        cacheHeight: _cacheDimension(context, 172),
                      )
                    : vehicle.imageUrl.trim().isNotEmpty
                        ? _cachedNetworkImage(
                            imageUrl: vehicle.imageUrl,
                            width: double.infinity,
                            height: 172,
                            fit: BoxFit.cover,
                            memCacheHeight: _cacheDimension(context, 172),
                            placeholderBuilder: () => const _ImageLoadingPlaceholder(
                              height: 172,
                              width: double.infinity,
                            ),
                            errorBuilder: () => _VehicleArtwork(vehicle: vehicle),
                          )
                        : _VehicleArtwork(vehicle: vehicle),
              ),
              if (galleryImages.length > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: galleryImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final imagePath = galleryImages[index];
                      final isAsset = imagePath.startsWith('assets/');
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: isAsset
                            ? Image.asset(
                                imagePath,
                                width: 74,
                                height: 56,
                                fit: BoxFit.cover,
                              )
                            : _cachedNetworkImage(
                                imageUrl: imagePath,
                                width: 74,
                                height: 56,
                                fit: BoxFit.cover,
                                placeholderBuilder: () => const _ImageLoadingPlaceholder(
                                  height: 56,
                                  width: 74,
                                ),
                                errorBuilder: () => _VehicleArtwork(vehicle: vehicle),
                              ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vehicle.type.label} • ${vehicle.inventoryCount} units',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.surfacePill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: colors.brandDeep),
                        const SizedBox(width: 4),
                        Text(
                          vehicle.rating.toStringAsFixed(1),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                vehicle.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: bodyTextColor,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SpecPill(icon: Icons.place_outlined, text: vehicle.primaryPickupHub),
                  SpecPill(
                    icon: Icons.airline_seat_recline_normal,
                    text: '${vehicle.seats} seats',
                  ),
                  SpecPill(icon: Icons.settings, text: vehicle.transmission),
                  SpecPill(icon: Icons.bolt_rounded, text: vehicle.displayEnergyLabel),
                ],
              ),
              const SizedBox(height: 12),
              if (vehicle.pickupHubs.length > 1) ...[
                _VehicleInfoPanel(
                  title: 'Pickup hubs',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: vehicle.pickupHubs
                        .map(
                          (hub) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: colors.border),
                            ),
                            child: Text(
                              hub,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _VehicleInfoPanel(
                title: 'Pricing',
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rates.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 74,
                  ),
                  itemBuilder: (context, index) {
                    final rate = rates[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.borderSoft),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            rate.unit.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: bodyTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${rate.price.toStringAsFixed(rate.price == rate.price.roundToDouble() ? 0 : 1)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: accentTextColor,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          onSecondaryAction();
                        },
                        child: Text(
                          secondaryActionLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onPrimaryAction();
                      },
                      child: Text(primaryActionLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _VehicleInfoPanel extends StatelessWidget {
  const _VehicleInfoPanel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class FeatureTag extends StatelessWidget {
  const FeatureTag({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
  });

  final String text;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor ?? Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (compact) {
      return SizedBox(
        height: 54,
        child: Image.asset(
          isDarkMode
              ? 'assets/branding/jisnow_logo_compact_dark.png'
              : 'assets/branding/jisnow_logo_compact.png',
          fit: BoxFit.fitHeight,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    return Image.asset(
      isDarkMode
          ? 'assets/branding/jisnow_logo_dark.png'
          : 'assets/branding/jisnow_logo.png',
      width: 260,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    required this.radius,
    required this.backgroundColor,
    required this.textColor,
    this.imageUrl,
    this.localImagePath,
  });

  final String initials;
  final double radius;
  final Color backgroundColor;
  final Color textColor;
  final String? imageUrl;
  final String? localImagePath;

  @override
  Widget build(BuildContext context) {
    if (localImagePath != null) {
      final provider = kIsWeb
          ? NetworkImage(localImagePath!)
          : FileImage(File(localImagePath!)) as ImageProvider;
      return CircleAvatar(
        radius: radius,
        backgroundImage: ResizeImage.resizeIfNeeded(
          _cacheDimension(context, radius * 2),
          _cacheDimension(context, radius * 2),
          provider,
        ),
      );
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final optimizedImageUrl = _optimizedProfileImageUrl(imageUrl!);
      return CircleAvatar(
        radius: radius,
        backgroundImage: ResizeImage.resizeIfNeeded(
          _cacheDimension(context, radius * 2),
          _cacheDimension(context, radius * 2),
          kIsWeb
              ? NetworkImage(optimizedImageUrl)
              : CachedNetworkImageProvider(optimizedImageUrl),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class SpecPill extends StatelessWidget {
  const SpecPill({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final iconColor = theme.brightness == Brightness.light ? colors.brandDeep : colors.brand;
    final textColor = colors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfacePill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class PriceRow extends StatelessWidget {
  const PriceRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class HeroStat extends StatelessWidget {
  const HeroStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
          ),
        ],
      ),
    );
  }
}
