import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/rental_models.dart';
import '../services/notification_repository.dart';
import '../theme/app_palette.dart';

typedef NotificationBookingOpener = Future<void> Function(
  BuildContext context,
  BookingRecord booking,
  void Function(BookingStatus status)? onStatusSelected,
);

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.notificationStream,
    required this.bookingsStream,
    required this.isAdmin,
    required this.onOpenBooking,
    this.onAdminStatusSelected,
  });

  final Stream<List<AppNotification>> notificationStream;
  final Stream<List<BookingRecord>> bookingsStream;
  final bool isAdmin;
  final NotificationBookingOpener onOpenBooking;
  final void Function(BookingRecord booking, BookingStatus status)?
      onAdminStatusSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: notificationStream,
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? const <AppNotification>[];

          if (snapshot.connectionState == ConnectionState.waiting &&
              notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        color: colors.textSecondary,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications yet.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Booking activity and account updates will appear here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return StreamBuilder<List<BookingRecord>>(
            stream: bookingsStream,
            builder: (context, bookingSnapshot) {
              final bookings = bookingSnapshot.data ?? const <BookingRecord>[];

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final booking = resolveNotificationBooking(
                    notification,
                    bookings,
                  );
                  return _NotificationCard(
                    notification: notification,
                    booking: booking,
                    isAdmin: isAdmin,
                    onAdminStatusSelected: onAdminStatusSelected,
                    onOpenBooking: onOpenBooking,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isAdmin,
    required this.onOpenBooking,
    this.booking,
    this.onAdminStatusSelected,
  });

  final AppNotification notification;
  final BookingRecord? booking;
  final bool isAdmin;
  final NotificationBookingOpener onOpenBooking;
  final void Function(BookingRecord booking, BookingStatus status)?
      onAdminStatusSelected;

  Future<void> _openNotificationTarget(BuildContext context) async {
    if (booking != null) {
      await onOpenBooking(
        context,
        booking!,
        onAdminStatusSelected == null
            ? null
            : (status) => onAdminStatusSelected!(booking!, status),
      );
      return;
    }
    await _showNotificationDetails(context);
  }

  Future<void> _showNotificationDetails(BuildContext context) async {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final hasImage = (notification.imageUrl ?? '').trim().isNotEmpty;
    final imagePath = notification.imageUrl?.trim() ?? '';
    final placeholderBackground =
        isDarkMode ? const Color(0xFF1D4736) : colors.brandTintStrong;
    final placeholderIconColor = isDarkMode ? Colors.white : colors.brandDeep;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: hasImage
                        ? _notificationImage(imagePath)
                        : Container(
                            color: placeholderBackground,
                            child: Icon(
                              Icons.notifications_active_rounded,
                              size: 48,
                              color: placeholderIconColor,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  notification.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  notification.body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: colors.surfacePill,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.schedule_rounded,
                          color: colors.textPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Received',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatNotificationDate(notification.createdAt),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final hasImage = (notification.imageUrl ?? '').trim().isNotEmpty;
    final imagePath = notification.imageUrl?.trim() ?? '';
    final placeholderBackground =
        isDarkMode ? const Color(0xFF1D4736) : colors.brandTintStrong;
    final placeholderIconColor = isDarkMode ? Colors.white : colors.brandDeep;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openNotificationTarget(context),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 56,
                  width: 56,
                  child: hasImage
                      ? _notificationImage(imagePath)
                      : Container(
                          decoration: BoxDecoration(
                            color: placeholderBackground,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.notifications_active_outlined,
                            color: placeholderIconColor,
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatNotificationDate(notification.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationImage(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    return kIsWeb
        ? Image.network(path, fit: BoxFit.cover)
        : CachedNetworkImage(imageUrl: path, fit: BoxFit.cover);
  }
}

BookingRecord? resolveNotificationBooking(
  AppNotification notification,
  List<BookingRecord> bookings,
) {
  final bookingId = notification.bookingId?.trim() ?? '';
  if (bookingId.isNotEmpty) {
    for (final booking in bookings) {
      if (booking.id == bookingId) {
        return booking;
      }
    }
  }

  if (bookings.isEmpty) {
    return null;
  }

  final normalizedTitle = notification.title.trim().toLowerCase();
  final normalizedBody = notification.body.trim().toLowerCase();
  final imageUrl = notification.imageUrl?.trim() ?? '';
  final newBookingMatch = RegExp(
    r'^(.*?)\s+requested\s+(.*?)\.$',
    caseSensitive: false,
  ).firstMatch(notification.body.trim());
  if (newBookingMatch != null) {
    final requestedBy = newBookingMatch.group(1)?.trim().toLowerCase() ?? '';
    final vehicleName = newBookingMatch.group(2)?.trim().toLowerCase() ?? '';

    final exactCandidates = bookings.where((booking) {
      final bookingDisplayName =
          booking.account?.displayName.trim().toLowerCase() ?? '';
      final bookingVehicleName = booking.vehicle.name.trim().toLowerCase();
      return bookingDisplayName == requestedBy &&
          bookingVehicleName == vehicleName;
    }).toList()
      ..sort((a, b) {
        final aDelta = a.createdAt.difference(notification.createdAt).abs();
        final bDelta = b.createdAt.difference(notification.createdAt).abs();
        final timeCompare = aDelta.compareTo(bDelta);
        if (timeCompare != 0) {
          return timeCompare;
        }
        if (a.status == BookingStatus.pending &&
            b.status != BookingStatus.pending) {
          return -1;
        }
        if (b.status == BookingStatus.pending &&
            a.status != BookingStatus.pending) {
          return 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    if (exactCandidates.length == 1) {
      return exactCandidates.first;
    }
    if (exactCandidates.length > 1) {
      final closestDelta =
          exactCandidates.first.createdAt.difference(notification.createdAt).abs();
      final equallyClose = exactCandidates
          .where(
            (booking) =>
                booking.createdAt.difference(notification.createdAt).abs() ==
                closestDelta,
          )
          .toList();
      if (equallyClose.length == 1) {
        return equallyClose.first;
      }
      return null;
    }
  }

  BookingRecord? bestMatch;
  var bestScore = 0;
  var secondBestScore = 0;

  for (final booking in bookings) {
    var score = 0;
    final vehicleName = booking.vehicle.name.trim().toLowerCase();
    final displayName = booking.account?.displayName.trim().toLowerCase() ?? '';
    final firstName = booking.account?.firstName.trim().toLowerCase() ?? '';
    final lastName = booking.account?.lastName.trim().toLowerCase() ?? '';

    if (vehicleName.isNotEmpty && normalizedBody.contains(vehicleName)) {
      score += 5;
    }

    if (displayName.isNotEmpty && normalizedBody.contains(displayName)) {
      score += 4;
    }

    if (firstName.isNotEmpty && normalizedBody.contains(firstName)) {
      score += 2;
    }

    if (lastName.isNotEmpty && normalizedBody.contains(lastName)) {
      score += 2;
    }

    if (imageUrl.isNotEmpty && booking.vehicle.imageUrl.trim() == imageUrl) {
      score += 3;
    }

    if (normalizedTitle.contains('new booking request') &&
        booking.status == BookingStatus.pending) {
      score += 1;
    }

    if (normalizedTitle.contains('booking update')) {
      score += 1;
    }

    final minutesDelta = booking.createdAt
        .difference(notification.createdAt)
        .inMinutes
        .abs();
    if (minutesDelta <= 10) {
      score += 4;
    } else if (minutesDelta <= 60) {
      score += 3;
    } else if (minutesDelta <= 24 * 60) {
      score += 2;
    } else if (minutesDelta <= 7 * 24 * 60) {
      score += 1;
    }

    if (score > bestScore) {
      secondBestScore = bestScore;
      bestScore = score;
      bestMatch = booking;
    } else if (score > secondBestScore) {
      secondBestScore = score;
    }
  }

  if (bestScore < 4) {
    return null;
  }
  if (bestScore == secondBestScore) {
    return null;
  }
  return bestMatch;
}

String _formatNotificationDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final hour24 = value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

  return '${months[value.month - 1]} ${value.day}, ${value.year} at $hour12:$minute $period';
}
