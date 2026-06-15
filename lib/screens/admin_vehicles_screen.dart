import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/rental_models.dart';
import '../services/booking_repository.dart';
import '../services/map_support.dart';
import '../services/notification_repository.dart';
import '../services/profile_repository.dart';
import '../services/vehicle_repository.dart';
import '../theme/app_palette.dart';
import '../widgets/admin_profile_widgets.dart';
import '../widgets/rental_widgets.dart';
import 'map_picker_screen.dart';

const List<String> _adminPickupHubOptions = [
  'Wat Phnom',
  'BKK1 Phnom Penh',
  'Riverside Phnom Penh',
  'Phnom Penh Airport',
  'Tuol Kork Hub',
];

class AdminVehiclesScreen extends StatefulWidget {
  const AdminVehiclesScreen({
    super.key,
    required this.vehicleRepository,
    required this.bookingRepository,
    required this.profileRepository,
    required this.notificationRepository,
    required this.isAdmin,
    this.initialTabIndex = 0,
    this.embeddedTabIndex,
  });

  final VehicleRepository vehicleRepository;
  final BookingRepository bookingRepository;
  final ProfileRepository profileRepository;
  final NotificationRepository notificationRepository;
  final bool isAdmin;
  final int initialTabIndex;
  final int? embeddedTabIndex;

  @override
  State<AdminVehiclesScreen> createState() => _AdminVehiclesScreenState();
}

class _AdminVehiclesScreenState extends State<AdminVehiclesScreen> {
  bool _syncingSeedData = false;
  final TextEditingController _bookingSearchController = TextEditingController();
  BookingStatus? _selectedBookingStatus;
  bool _deliveryOnly = false;
  bool _needsActionOnly = false;
  bool _todayOnly = false;
  bool _sortNewestFirst = true;
  final Set<String> _updatingBookingIds = <String>{};

  @override
  void dispose() {
    _bookingSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    if (!widget.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Manage vehicles'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: colors.textSecondary,
                ),
                const SizedBox(height: 14),
                Text(
                  'Admin access required',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This screen is only available to admin accounts.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.embeddedTabIndex != null) {
      return _buildEmbeddedTabView(theme, colors, widget.embeddedTabIndex!);
    }

    return DefaultTabController(
      initialIndex: widget.initialTabIndex.clamp(0, 2),
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Admin'),
          actions: [
            IconButton(
              tooltip: 'Sync demo vehicles',
              onPressed: _syncingSeedData ? null : _syncSeedVehicles,
              icon: _syncingSeedData
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bookings', icon: Icon(Icons.receipt_long_rounded)),
              Tab(text: 'Vehicles', icon: Icon(Icons.directions_car_filled_rounded)),
              Tab(text: 'Profiles', icon: Icon(Icons.people_alt_rounded)),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final controller = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                if (controller.index != 1) {
                  return const SizedBox.shrink();
                }
                return _AdminAddVehicleButton(
                  onPressed: () => _openEditor(context),
                );
              },
            );
          },
        ),
        body: TabBarView(
          children: [
            _buildBookingsTab(theme, colors),
            _buildVehiclesTab(theme, colors),
            _buildProfilesTab(theme, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedTabView(ThemeData theme, AppPalette colors, int tabIndex) {
    final tabBody = switch (tabIndex) {
      0 => _buildBookingsTab(theme, colors),
      1 => _buildVehiclesTab(theme, colors),
      2 => _buildProfilesTab(theme, colors),
      _ => _buildBookingsTab(theme, colors),
    };

    if (tabIndex != 1) {
      return tabBody;
    }

    return Stack(
      children: [
        Positioned.fill(child: tabBody),
        Positioned(
          right: 20,
          bottom: 20,
          child: _AdminAddVehicleButton(
            onPressed: () => _openEditor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingsTab(ThemeData theme, AppPalette colors) {
    return StreamBuilder<List<BookingRecord>>(
      stream: widget.bookingRepository.watchAllBookings(),
      builder: (context, snapshot) {
        final bookings = snapshot.data ?? const <BookingRecord>[];
        final filteredBookings = bookings.where((booking) {
          final statusMatch =
              _selectedBookingStatus == null || booking.status == _selectedBookingStatus;
          final deliveryMatch = !_deliveryOnly || booking.fulfillmentMethod == 'delivery';
          final needsActionMatch = !_needsActionOnly || booking.status != BookingStatus.completed;
          final todayMatch = !_todayOnly || _isSameBookingDay(booking.startDate, DateTime.now());
          final query = _bookingSearchController.text.trim().toLowerCase();
          if (query.isEmpty) {
            return statusMatch && deliveryMatch && needsActionMatch && todayMatch;
          }
          final haystack = [
            booking.vehicle.name,
            booking.account?.displayName ?? '',
            booking.account?.email ?? '',
            booking.account?.phoneNumber ?? '',
            booking.pickupHub,
            booking.deliveryAddress ?? '',
            booking.deliveryNotes ?? '',
            booking.id,
            booking.status.label,
          ]
              .join(' ')
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ');
          final digitsHaystack = haystack.replaceAll(RegExp(r'\D+'), '');
          final terms = query
              .split(RegExp(r'\s+'))
              .where((term) => term.isNotEmpty);
          final matchesQuery = terms.every((term) {
            if (haystack.contains(term)) {
              return true;
            }
            final digitsTerm = term.replaceAll(RegExp(r'\D+'), '');
            return digitsTerm.length >= 3 && digitsHaystack.contains(digitsTerm);
          });
          return statusMatch &&
              deliveryMatch &&
              needsActionMatch &&
              todayMatch &&
              matchesQuery;
        }).toList()
          ..sort((a, b) => _sortNewestFirst
              ? b.startDate.compareTo(a.startDate)
              : a.startDate.compareTo(b.startDate));
        final pendingCount = bookings.where((booking) => booking.status == BookingStatus.pending).length;
        final ongoingCount = bookings.where((booking) => booking.status == BookingStatus.confirmed).length;
        final completeCount = bookings.where((booking) => booking.status == BookingStatus.completed).length;

        if (snapshot.connectionState == ConnectionState.waiting && bookings.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: const [
              AppLoadingCard(height: 116),
              SizedBox(height: 14),
              AppLoadingCard(height: 180),
              SizedBox(height: 14),
              AppLoadingCard(height: 180),
            ],
          );
        }

        if (bookings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No bookings yet',
                message:
                    'Customer reservations will appear here for review and status updates.',
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            const AppSectionHeader(
              title: 'Booking overview',
              subtitle: 'Track customer demand, search faster, and act on urgent rides first.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AdminProfileStatCard(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending',
                    value: pendingCount.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminProfileStatCard(
                    icon: Icons.electric_car_rounded,
                    label: 'Ongoing',
                    value: ongoingCount.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminProfileStatCard(
                    icon: Icons.task_alt_rounded,
                    label: 'Done',
                    value: completeCount.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _bookingSearchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search customer, vehicle, email, or hub',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AdminBookingFilterChip(
                  label: 'All',
                  selected: _selectedBookingStatus == null,
                  onTap: () => setState(() => _selectedBookingStatus = null),
                ),
                ...BookingStatus.values.map(
                  (status) => _AdminBookingFilterChip(
                    label: status.label,
                    selected: _selectedBookingStatus == status,
                    onTap: () => setState(() => _selectedBookingStatus = status),
                  ),
                ),
                _AdminBookingFilterChip(
                  label: 'Delivery',
                  selected: _deliveryOnly,
                  onTap: () => setState(() => _deliveryOnly = !_deliveryOnly),
                ),
                _AdminBookingFilterChip(
                  label: 'Needs action',
                  selected: _needsActionOnly,
                  onTap: () => setState(() => _needsActionOnly = !_needsActionOnly),
                ),
                _AdminBookingFilterChip(
                  label: 'Today',
                  selected: _todayOnly,
                  onTap: () => setState(() => _todayOnly = !_todayOnly),
                ),
                _AdminBookingFilterChip(
                  label: _sortNewestFirst ? 'Newest first' : 'Oldest first',
                  selected: true,
                  onTap: () => setState(() => _sortNewestFirst = !_sortNewestFirst),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filteredBookings.isEmpty)
              const AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching bookings',
                message:
                    'Try a different search word or clear the status filter to see more reservations.',
              ),
            ...filteredBookings.map(
              (booking) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _AdminBookingCard(
                  booking: booking,
                  isUpdating: _updatingBookingIds.contains(booking.id),
                  onStatusSelected: (status) => _updateBookingStatusWithFeedback(booking, status),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVehiclesTab(ThemeData theme, AppPalette colors) {
    return StreamBuilder<List<Vehicle>>(
      stream: widget.vehicleRepository.watchVehicles(),
      builder: (context, snapshot) {
        final vehicles = snapshot.data ?? const <Vehicle>[];

        if (snapshot.connectionState == ConnectionState.waiting &&
            vehicles.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: const [
              AppLoadingCard(height: 112),
              SizedBox(height: 14),
              AppLoadingCard(height: 260),
              SizedBox(height: 14),
              AppLoadingCard(height: 260),
            ],
          );
        }

        if (vehicles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AppEmptyState(
                icon: Icons.directions_car_filled_outlined,
                title: 'No vehicles yet',
                message:
                    'Add your first car, moto, or bicycle to start building the catalog.',
              ),
            ),
          );
        }

        return StreamBuilder<List<BookingRecord>>(
          stream: widget.bookingRepository.watchAllBookings(),
          builder: (context, bookingsSnapshot) {
            final bookings = bookingsSnapshot.data ?? const <BookingRecord>[];
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              itemCount: vehicles.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      const AppSectionHeader(
                        title: 'Fleet control',
                        subtitle:
                            'Keep shared pickup hubs accurate and review live stock across the catalog.',
                      ),
                      const SizedBox(height: 14),
                      _AdminHubPinsCard(
                        onManage: () => _openPickupHubManager(context),
                      ),
                    ],
                  );
                }
                final vehicle = vehicles[index - 1];
                final now = DateTime.now();
                final activeReservations = overlappingBookingCountForVehicle(
                  vehicleId: vehicle.id,
                  bookings: bookings,
                  requestedStart: now,
                  requestedEnd: now.add(const Duration(minutes: 1)),
                );
                final availableUnits = (vehicle.inventoryCount - activeReservations) < 0
                    ? 0
                    : (vehicle.inventoryCount - activeReservations);
                return _AdminVehicleCard(
                  vehicle: vehicle,
                  availableUnits: availableUnits,
                  activeReservations: activeReservations,
                  onEdit: () => _openEditor(context, vehicle: vehicle),
                  onDelete: () => _confirmDeleteVehicle(vehicle),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openPickupHubManager(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _PickupHubManagerScreen(),
      ),
    );
  }

  Widget _buildProfilesTab(ThemeData theme, AppPalette colors) {
    return StreamBuilder<List<UserProfile>>(
      stream: widget.profileRepository.watchAllProfiles(),
      builder: (context, snapshot) {
        final profiles = snapshot.data ?? const <UserProfile>[];

        if (snapshot.connectionState == ConnectionState.waiting && profiles.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: const [
              AppLoadingCard(height: 116),
              SizedBox(height: 14),
              AppLoadingCard(height: 144),
              SizedBox(height: 14),
              AppLoadingCard(height: 144),
            ],
          );
        }

        if (profiles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AppEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'No profiles yet',
                message:
                    'Customer and admin profiles will appear here once accounts are created.',
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          itemCount: profiles.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final profile = profiles[index];
            return AdminProfileCard(
              profile: profile,
              onTap: () => _showProfileDetails(context, profile, theme, colors),
            );
          },
        );
      },
    );
  }

  Future<void> _showProfileDetails(
    BuildContext context,
    UserProfile profile,
    ThemeData theme,
    AppPalette colors,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: StreamBuilder<List<BookingRecord>>(
            stream: widget.bookingRepository.watchBookings(profile.userId),
            builder: (context, snapshot) {
              final bookings = snapshot.data ?? const <BookingRecord>[];
              final activeBookings = bookings
                  .where(
                    (booking) =>
                        booking.status == BookingStatus.pending ||
                        booking.status == BookingStatus.confirmed,
                  )
                  .length;
              final lastBooking = bookings.isEmpty ? null : bookings.first;
              final totalSpent = bookings
                  .where((booking) => booking.status == BookingStatus.completed)
                  .fold<double>(0, (sum, booking) => sum + booking.totalPrice);
              final favoriteType = _adminFavoriteVehicleTypeLabel(bookings);
              final favoriteHub = _adminFavoritePickupHub(bookings);

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
            const SizedBox(height: 16),
            Row(
              children: [
                        ProfileAvatar(
                          imageUrl: profile.photoUrl,
                          initials: profile.initials,
                          radius: 28,
                          backgroundColor: colors.brandTintStrong,
                          textColor: colors.brandDeep,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName.isEmpty ? 'Unnamed profile' : profile.displayName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.isAdmin ? 'Admin account' : 'Customer account',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: AdminProfileStatCard(
                            icon: Icons.receipt_long_rounded,
                            label: 'Total bookings',
                            value: bookings.length.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminProfileStatCard(
                            icon: Icons.electric_car_rounded,
                            label: 'Ongoing',
                            value: activeBookings.toString(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AdminProfileDetailRow(
                      icon: Icons.history_rounded,
                      label: 'Last booking',
                      value: lastBooking == null
                          ? 'No bookings yet'
                          : _formatAdminBookingDay(lastBooking.createdAt),
                    ),
                    const SizedBox(height: 12),
                    AdminProfileDetailRow(
                      icon: Icons.payments_outlined,
                      label: 'Total spent',
                      value: totalSpent == 0
                          ? '\$0'
                          : '\$${totalSpent.toStringAsFixed(totalSpent == totalSpent.roundToDouble() ? 0 : 1)}',
                    ),
                    const SizedBox(height: 12),
                    AdminProfileDetailRow(
                      icon: Icons.category_outlined,
                      label: 'Favorite ride type',
                      value: favoriteType,
                    ),
                    const SizedBox(height: 12),
                    AdminProfileDetailRow(
                      icon: Icons.place_outlined,
                      label: 'Favorite pickup hub',
                      value: favoriteHub,
                    ),
                    const SizedBox(height: 12),
                    AdminProfileDetailRow(
                      icon: Icons.event_available_rounded,
                      label: 'Joined',
                      value: profile.createdAt == null
                          ? 'Not available'
                          : _formatAdminBookingDay(profile.createdAt!),
                    ),
                    const SizedBox(height: 12),
                    AdminProfileDetailRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: profile.email.isEmpty ? 'Not added' : profile.email,
                    ),
                    const SizedBox(height: 12),
                    AdminProfileDetailRow(
                      icon: Icons.phone_iphone_rounded,
                      label: 'Phone',
                      value: profile.phoneNumber.isEmpty ? 'Not added' : profile.phoneNumber,
                    ),
                    const SizedBox(height: 12),
                    AdminProfileDetailRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Profile status',
                      value: profile.profileComplete ? 'Complete' : 'Incomplete',
                    ),
                    const SizedBox(height: 12),
                    AdminProfileDetailRow(
                      icon: Icons.badge_outlined,
                      label: 'User ID',
                      value: profile.userId,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    Vehicle? vehicle,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VehicleEditorScreen(
          vehicleRepository: widget.vehicleRepository,
          initialVehicle: vehicle,
        ),
      ),
    );
  }

  Future<void> _syncSeedVehicles() async {
    setState(() => _syncingSeedData = true);

    try {
      await widget.vehicleRepository.seedVehiclesIfEmpty();
      await widget.vehicleRepository.syncVehiclesFromSeedData();
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: 'Demo vehicles synced successfully.',
        tone: AppBannerTone.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: 'Could not sync demo vehicles right now.',
        tone: AppBannerTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _syncingSeedData = false);
      }
    }
  }

  Future<void> _confirmDeleteVehicle(Vehicle vehicle) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete vehicle'),
          content: Text(
            'Delete ${vehicle.name}? This will remove it from the catalog.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await widget.vehicleRepository.deleteVehicle(vehicle);
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: '${vehicle.name} deleted.',
        tone: AppBannerTone.warning,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: 'Could not delete this vehicle right now.',
        tone: AppBannerTone.error,
      );
    }
  }

  Future<void> _updateBookingStatusWithFeedback(
    BookingRecord booking,
    BookingStatus status,
  ) async {
    if (_updatingBookingIds.contains(booking.id)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Update to ${status.label}?'),
          content: Text(
            'This will update ${booking.vehicle.name} for ${booking.account?.displayName ?? 'the customer'} and send a booking notification.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _updatingBookingIds.add(booking.id));
    try {
      await widget.bookingRepository.updateBookingStatus(
        bookingId: booking.id,
        status: status,
        cancellationSource: status == BookingStatus.cancelled
            ? BookingCancellationSource.admin
            : null,
      );
      await widget.notificationRepository.createNotification(
        recipientUserId: booking.userId,
        title: 'Booking update',
        body: switch (status) {
          BookingStatus.pending => '${booking.vehicle.name} is back in pending review.',
          BookingStatus.confirmed => '${booking.vehicle.name} is now ongoing.',
          BookingStatus.completed => '${booking.vehicle.name} was marked completed.',
          BookingStatus.cancelled => '${booking.vehicle.name} was cancelled by admin.',
        },
        imageUrl: booking.vehicle.imageUrl,
        bookingId: booking.id,
      );
      if (!mounted) {
        return;
      }
      final message = switch (status) {
        BookingStatus.pending => '${booking.vehicle.name} moved back to pending.',
        BookingStatus.confirmed => '${booking.vehicle.name} is now ongoing for the customer.',
        BookingStatus.completed => '${booking.vehicle.name} was marked complete.',
        BookingStatus.cancelled => '${booking.vehicle.name} was cancelled by admin.',
      };
      showAppBanner(
        context,
        message: message,
        tone: status == BookingStatus.cancelled ? AppBannerTone.warning : AppBannerTone.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: 'Could not update ${booking.vehicle.name} right now.',
        tone: AppBannerTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _updatingBookingIds.remove(booking.id));
      }
    }
  }
}

bool _isSameBookingDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class _AdminVehicleCard extends StatelessWidget {
  const _AdminVehicleCard({
    required this.vehicle,
    required this.availableUnits,
    required this.activeReservations,
    required this.onEdit,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final int availableUnits;
  final int activeReservations;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final accentTextColor = theme.brightness == Brightness.light
        ? colors.textPrimary
        : colors.brand;
    final dayRate = vehicle.rateFor(RentalUnit.day).price;
    final availabilityColor = availableUnits > 0 ? colors.brand : colors.errorText;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 140,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _AdminVehicleImage(
                          vehicle: vehicle,
                          width: double.infinity,
                          height: 140,
                          borderRadius: 20,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.04),
                                Colors.black.withValues(alpha: 0.08),
                                Colors.black.withValues(alpha: 0.38),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Text(
                      vehicle.type.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        vehicle.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '\$${_formatVehiclePrice(dayRate)} / day',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accentTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                _AdminVehicleMetricCard(
                  label: 'Total',
                  value: '${vehicle.inventoryCount}',
                  icon: Icons.inventory_2_outlined,
                ),
                _AdminVehicleMetricCard(
                  label: 'Available',
                  value: '$availableUnits',
                  icon: Icons.check_circle_outline_rounded,
                  valueColor: availabilityColor,
                ),
                _AdminVehicleMetricCard(
                  label: 'Booked',
                  value: '$activeReservations',
                  icon: Icons.receipt_long_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: colors.borderSoft),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEdit,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.brandTintStrong,
                      foregroundColor: accentTextColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.errorText,
                      side: BorderSide(color: colors.errorText.withValues(alpha: 0.28)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminBookingCard extends StatelessWidget {
  const _AdminBookingCard({
    required this.booking,
    required this.isUpdating,
    required this.onStatusSelected,
  });

  final BookingRecord booking;
  final bool isUpdating;
  final ValueChanged<BookingStatus> onStatusSelected;

  Future<void> _showModernAdminBookingDetails(BuildContext context) async {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final account = booking.account;
    final customerName = account?.displayName.trim().isNotEmpty == true
        ? account!.displayName
        : 'Customer';
    final customerSubtitle = [
      if (account?.email.trim().isNotEmpty == true) account!.email,
      if (account?.phoneNumber.trim().isNotEmpty == true) account!.phoneNumber,
    ].join(' | ');
    final availableActions = _availableAdminActionsFor(booking);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
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
                  borderRadius: BorderRadius.circular(28),
                  child: SizedBox(
                    width: double.infinity,
                    height: 172,
                    child: _AdminVehicleImage(vehicle: booking.vehicle),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.vehicle.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            booking.vehicle.type.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _AdminStatusChip(
                      status: booking.status,
                      label: _statusLabelFor(booking),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AdminBookingQuickInfoPill(
                      icon: Icons.calendar_month_rounded,
                      label: 'Start',
                      value:
                          '${_formatAdminBookingDay(booking.startDate)} ? ${_formatAdminBookingTime(booking.startDate)}',
                      tone: _AdminBookingQuickInfoTone.info,
                    ),
                    _AdminBookingQuickInfoPill(
                      icon: Icons.payments_outlined,
                      label: 'Total',
                      value: '\$${_formatVehiclePrice(booking.totalPrice)}',
                      tone: _AdminBookingQuickInfoTone.success,
                    ),
                    _AdminBookingQuickInfoPill(
                      icon: booking.fulfillmentMethod == 'delivery'
                          ? Icons.local_shipping_outlined
                          : Icons.storefront_outlined,
                      label: booking.fulfillmentMethod == 'delivery' ? 'Delivery' : 'Pickup',
                      value: booking.fulfillmentMethod == 'delivery'
                          ? 'Customer address'
                          : booking.pickupHub,
                      tone: _AdminBookingQuickInfoTone.neutral,
                    ),
                  ],
                ),
                if (account != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Customer',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AdminCustomerPanel(
                    title: 'Customer',
                    name: customerName,
                    subtitle: customerSubtitle,
                    photoUrl: account.photoUrl,
                  ),
                ],
                const SizedBox(height: 16),
                _AdminBookingTimelinePanel(booking: booking),
                    if (availableActions.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                    isUpdating ? 'Updating status...' : 'Update status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final status in availableActions)
                        _AdminStatusAction(
                          status: status,
                          selected: booking.status == status,
                          onTap: () {
                            Navigator.of(context).pop();
                            onStatusSelected(status);
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Booking details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _AdminBookingDetailsPanel(booking: booking),
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
    final account = booking.account;
    final customerName = account?.displayName.trim().isNotEmpty == true
        ? account!.displayName
        : 'Customer';
    final customerSubtitle = [
      if (account?.email.trim().isNotEmpty == true) account!.email,
      if (account?.phoneNumber.trim().isNotEmpty == true) account!.phoneNumber,
    ].join('  |  ');
    final availableActions = _availableAdminActionsFor(booking);
    final compactDate = _formatAdminBookingDay(booking.startDate);
    final compactTime = _formatAdminBookingTime(booking.startDate);
    final totalPrice = '\$${_formatVehiclePrice(booking.totalPrice)}';
    final scheduleValue = '$compactDate • $compactTime';
    final fulfillmentValue = booking.fulfillmentMethod == 'delivery'
        ? 'Delivery'
        : booking.pickupHub;
    final accentTextColor = theme.brightness == Brightness.light
        ? colors.textPrimary
        : colors.brand;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _showModernAdminBookingDetails(context),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: SizedBox(
                      width: double.infinity,
                      height: 152,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _AdminVehicleImage(
                            vehicle: booking.vehicle,
                            width: double.infinity,
                            height: 152,
                            borderRadius: 0,
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.04),
                                  Colors.black.withValues(alpha: 0.10),
                                  Colors.black.withValues(alpha: 0.48),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _AdminStatusChip(
                      status: booking.status,
                      label: _statusLabelFor(booking),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Booking total',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalPrice,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.vehicle.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.08,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontWeight: FontWeight.w700,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            customerSubtitle.isEmpty ? 'No contact details' : customerSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _AdminVehicleMetricCard(
                          label: 'Ref',
                          value: booking.id.length > 8
                              ? booking.id.substring(0, 8).toUpperCase()
                              : booking.id.toUpperCase(),
                          icon: Icons.confirmation_number_outlined,
                          valueColor: accentTextColor,
                        ),
                        _AdminVehicleMetricCard(
                          label: 'Status',
                          value: _statusLabelFor(booking),
                          icon: Icons.flag_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _AdminVehicleMetricCard(
                          label: 'Pickup',
                          value: fulfillmentValue,
                          icon: booking.fulfillmentMethod == 'delivery'
                              ? Icons.local_shipping_outlined
                              : Icons.storefront_outlined,
                        ),
                        _AdminVehicleMetricCard(
                          label: 'Schedule',
                          value: scheduleValue,
                          icon: Icons.schedule_rounded,
                        ),
                        _AdminVehicleMetricCard(
                          label: 'Duration',
                          value: '${booking.quantity} ${booking.unit.label.toLowerCase()}',
                          icon: Icons.timelapse_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.borderSoft),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminCustomerPanel(
                            title: 'Customer',
                            name: customerName,
                            subtitle: customerSubtitle,
                            photoUrl: account?.photoUrl,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                    if (booking.cancelledByCustomer || booking.cancelledByAdmin) ...[
                      const SizedBox(height: 12),
                      Text(
                        booking.cancelledByCustomer
                            ? 'Cancelled by customer'
                            : 'Cancelled by admin',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (availableActions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Divider(height: 1, color: colors.borderSoft),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          for (var index = 0; index < availableActions.length; index++) ...[
                            if (index > 0) const SizedBox(width: 10),
                            Expanded(
                              child: _AdminStatusAction(
                                status: availableActions[index],
                                selected: booking.status == availableActions[index],
                                onTap: isUpdating
                                    ? null
                                    : () => onStatusSelected(availableActions[index]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminHubPinsCard extends StatelessWidget {
  const _AdminHubPinsCard({
    required this.onManage,
  });

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.brandTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.place_rounded,
                  color: colors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup hub map pins',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Change shared pickup locations without opening a vehicle first.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Manage hub pins'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupHubManagerScreen extends StatefulWidget {
  const _PickupHubManagerScreen();

  @override
  State<_PickupHubManagerScreen> createState() => _PickupHubManagerScreenState();
}

class _PickupHubManagerScreenState extends State<_PickupHubManagerScreen> {
  Map<String, LatLng> _positions = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    final overrides = await loadPickupHubPositionOverrides();
    if (!mounted) {
      return;
    }
    setState(() {
      _positions = {
        for (final hub in _adminPickupHubOptions)
          hub: overrides[hub] ?? pickupHubPosition(hub),
      };
      _loading = false;
    });
  }

  Future<void> _editHub(String hub) async {
    final initialPosition = _positions[hub] ?? pickupHubPosition(hub);
    final selectedPosition = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        builder: (_) => PickupHubPositionEditorScreen(
          hubName: hub,
          initialPosition: initialPosition,
        ),
      ),
    );
    if (!mounted || selectedPosition == null) {
      return;
    }
    try {
      await saveSharedPickupHubPosition(hub, selectedPosition);
      if (!mounted) {
        return;
      }
      setState(() {
        _positions = {
          ..._positions,
          hub: selectedPosition,
        };
      });
      showAppBanner(
        context,
        message: '$hub pin updated.',
        tone: AppBannerTone.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: 'Could not update the pickup hub position right now.',
        tone: AppBannerTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Pickup hub pins'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              itemCount: _adminPickupHubOptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final hub = _adminPickupHubOptions[index];
                final position = _positions[hub] ?? pickupHubPosition(hub);
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hub,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _editHub(hub),
                            icon: const Icon(Icons.edit_location_alt_outlined),
                            label: const Text('Change'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lat ${position.latitude.toStringAsFixed(5)} • Lng ${position.longitude.toStringAsFixed(5)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _AdminAddVehicleButton extends StatelessWidget {
  const _AdminAddVehicleButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final colors = AppPalette.of(context);

    if (width < 390) {
      return FloatingActionButton.small(
        heroTag: null,
        onPressed: onPressed,
        backgroundColor: colors.brand,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      );
    }

    if (width < 460) {
      return FloatingActionButton.extended(
        heroTag: null,
        onPressed: onPressed,
        backgroundColor: colors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      );
    }

    return FloatingActionButton.extended(
      heroTag: null,
      onPressed: onPressed,
      backgroundColor: colors.brand,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add vehicle'),
    );
  }
}

class _AdminBookingFilterChip extends StatelessWidget {
  const _AdminBookingFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final selectedBackground = isDarkMode ? const Color(0xFF1D4736) : colors.brandTintStrong;
    final selectedBorder = isDarkMode ? const Color(0xFF3F8C69) : colors.brandDeep;
    final selectedForeground = isDarkMode ? Colors.white : colors.brandDeep;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedBackground : colors.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? selectedBorder : colors.border),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: selected ? selectedForeground : colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AdminStatusChip extends StatelessWidget {
  const _AdminStatusChip({
    required this.status,
    required this.label,
  });

  final BookingStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = _statusTheme(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _statusLabelFor(BookingRecord booking) {
  if (booking.cancelledByCustomer) {
    return 'Cancelled by customer';
  }
  if (booking.cancelledByAdmin) {
    return 'Cancelled by admin';
  }
  return booking.status.label;
}

enum _AdminBookingQuickInfoTone { info, success, neutral }

class _AdminBookingQuickInfoPill extends StatelessWidget {
  const _AdminBookingQuickInfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final _AdminBookingQuickInfoTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final (background, iconSurface, iconTint, iconBorderColor) = switch (tone) {
      _AdminBookingQuickInfoTone.info => (
          isDarkMode ? const Color(0xFF1C3347) : colors.brandTintStrong,
          isDarkMode ? const Color(0xFFDDF7E8) : colors.brandTintStrong,
          isDarkMode ? const Color(0xFF47A978) : colors.brandDeep,
          isDarkMode ? const Color(0xCCBFE8CF) : colors.borderSoft,
        ),
      _AdminBookingQuickInfoTone.success => (
          isDarkMode ? const Color(0xFF1C3347) : colors.brandTintStrong,
          isDarkMode ? const Color(0xFFDDF7E8) : colors.brandTintStrong,
          isDarkMode ? const Color(0xFF47A978) : colors.brand,
          isDarkMode ? const Color(0xCCBFE8CF) : colors.borderSoft,
        ),
      _AdminBookingQuickInfoTone.neutral => (
          colors.surfaceSoft,
          isDarkMode ? const Color(0xFFF3FAF2) : colors.surface,
          colors.textSecondary,
          isDarkMode ? const Color(0x99FFFFFF) : colors.borderSoft,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconBorderColor),
            ),
            child: Icon(icon, size: 18, color: iconTint),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
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

class _AdminVehicleMetricCard extends StatelessWidget {
  const _AdminVehicleMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor ?? colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminBookingTimelinePanel extends StatelessWidget {
  const _AdminBookingTimelinePanel({
    required this.booking,
  });

  final BookingRecord booking;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final steps = <({String label, bool done, bool active})>[
      (
        label: 'Requested',
        done: true,
        active: booking.status == BookingStatus.pending,
      ),
      (
        label: 'Ongoing',
        done: booking.status == BookingStatus.confirmed ||
            booking.status == BookingStatus.completed,
        active: booking.status == BookingStatus.confirmed,
      ),
      (
        label: booking.status == BookingStatus.cancelled ? 'Cancelled' : 'Returned',
        done: booking.status == BookingStatus.completed ||
            booking.status == BookingStatus.cancelled,
        active: booking.status == BookingStatus.completed ||
            booking.status == BookingStatus.cancelled,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        children: [
          for (var index = 0; index < steps.length; index++) ...[
            Expanded(
              child: _AdminTimelineStep(
                label: steps[index].label,
                done: steps[index].done,
                active: steps[index].active,
              ),
            ),
            if (index < steps.length - 1)
              Container(
                width: 22,
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: steps[index + 1].done || steps[index + 1].active
                    ? colors.brand
                    : colors.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _AdminTimelineStep extends StatelessWidget {
  const _AdminTimelineStep({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final dotColor = done || active ? colors.brand : colors.surfaceMuted;
    final borderColor = active ? colors.brandDeep : colors.borderSoft;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: done || active ? Colors.white : colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
            fontWeight: done || active ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AdminBookingDetailsPanel extends StatelessWidget {
  const _AdminBookingDetailsPanel({
    required this.booking,
  });

  final BookingRecord booking;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        children: [
          _AdminDetailRow(
            icon: Icons.storefront_outlined,
            label: 'Pickup',
            value: booking.pickupHub,
          ),
          const SizedBox(height: 14),
          _AdminDetailRow(
            icon: Icons.schedule_rounded,
            label: 'Schedule',
            value:
                '${_formatAdminBookingDay(booking.startDate)}, ${_formatAdminBookingTime(booking.startDate)}',
          ),
          const SizedBox(height: 14),
          _AdminDetailRow(
            icon: Icons.flag_outlined,
            label: 'Return',
            value:
                '${_formatAdminBookingDay(booking.endDate)}, ${_formatAdminBookingTime(booking.endDate)}',
          ),
          const SizedBox(height: 14),
          _AdminDetailRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Reference',
            value: booking.id,
          ),
          if ((booking.deliveryAddress ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _AdminDetailRow(
              icon: Icons.location_on_outlined,
              label: 'Delivery address',
              value: booking.deliveryAddress!.trim(),
            ),
          ],
          if ((booking.deliveryNotes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _AdminDetailRow(
              icon: Icons.notes_rounded,
              label: 'Notes',
              value: booking.deliveryNotes!.trim(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminDetailRow extends StatelessWidget {
  const _AdminDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: colors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminStatusAction extends StatelessWidget {
  const _AdminStatusAction({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final BookingStatus status;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = _actionTheme(status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? foreground : background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? foreground : foreground.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          status.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: selected ? Colors.white : foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

(Color, Color) _statusTheme(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => (const Color(0xFFFFE8B5), const Color(0xFF7A4B00)),
    BookingStatus.confirmed => (const Color(0xFFD8ECFF), const Color(0xFF0F4C81)),
    BookingStatus.completed => (const Color(0xFFDDF4E8), const Color(0xFF155B3C)),
    BookingStatus.cancelled => (const Color(0xFFFFE2DF), const Color(0xFF9A2C21)),
  };
}

List<BookingStatus> _availableAdminActionsFor(BookingRecord booking) {
  switch (booking.status) {
    case BookingStatus.pending:
      return const [BookingStatus.confirmed, BookingStatus.cancelled];
    case BookingStatus.confirmed:
      return const [BookingStatus.completed, BookingStatus.cancelled];
    case BookingStatus.completed:
    case BookingStatus.cancelled:
      return const [];
  }
}

(Color, Color) _actionTheme(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => (const Color(0xFFFFF3D6), const Color(0xFF7A4B00)),
    BookingStatus.confirmed => (const Color(0xFFE9F4FF), const Color(0xFF0F4C81)),
    BookingStatus.completed => (const Color(0xFFE9F8EF), const Color(0xFF155B3C)),
    BookingStatus.cancelled => (const Color(0xFFFFECEA), const Color(0xFF9A2C21)),
  };
}

class _AdminVehicleImage extends StatelessWidget {
  const _AdminVehicleImage({
    required this.vehicle,
    this.width = 124,
    this.height = 92,
    this.borderRadius = 18,
  });

  final Vehicle vehicle;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final imagePath = vehicle.imageUrl.trim();
    final placeholder = Container(
      color: colors.brandTintStrong,
      child: Icon(
        vehicle.type.icon,
        color: colors.brand,
        size: 32,
      ),
    );

    Widget image;
    if (imagePath.isEmpty) {
      image = placeholder;
    } else if (imagePath.startsWith('assets/')) {
      image = Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      image = kIsWeb
          ? Image.network(
              imagePath,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return _loading(colors);
              },
              errorBuilder: (context, error, stackTrace) => placeholder,
            )
          : CachedNetworkImage(
              imageUrl: imagePath,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (context, url) => _loading(colors),
              errorWidget: (context, url, error) => placeholder,
            );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: image,
      ),
    );
  }

  Widget _loading(AppPalette colors) {
    return Container(
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
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: colors.brand,
          ),
        ),
      ),
    );
  }
}

class _VehicleEditorScreen extends StatefulWidget {
  const _VehicleEditorScreen({
    required this.vehicleRepository,
    this.initialVehicle,
  });

  final VehicleRepository vehicleRepository;
  final Vehicle? initialVehicle;

  @override
  State<_VehicleEditorScreen> createState() => _VehicleEditorScreenState();
}

class _VehicleEditorScreenState extends State<_VehicleEditorScreen> {
  static const List<String> _pickupHubOptions = _adminPickupHubOptions;

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _seatsController;
  late final TextEditingController _transmissionController;
  late final TextEditingController _energyController;
  late final TextEditingController _ratingController;
  late final TextEditingController _inventoryController;
  late final TextEditingController _hourRateController;
  late final TextEditingController _dayRateController;
  late final TextEditingController _weekRateController;
  late final TextEditingController _monthRateController;
  late VehicleType _selectedType;
  late String _selectedPickupHub;
  late bool _availableNow;
  XFile? _pickedImage;
  List<XFile> _pickedGalleryImages = const [];
  bool _saving = false;

  bool get _isEditing => widget.initialVehicle != null;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.initialVehicle;
    _selectedType = vehicle?.type ?? VehicleType.car;
    _selectedPickupHub = _normalizedPickupHub(vehicle?.location);
    _availableNow = vehicle?.availableNow ?? true;
    _nameController = TextEditingController(text: vehicle?.name ?? '');
    _descriptionController = TextEditingController(text: vehicle?.description ?? '');
    _seatsController = TextEditingController(text: '${vehicle?.seats ?? 4}');
    _transmissionController = TextEditingController(
      text: vehicle?.transmission ?? 'Automatic',
    );
    _energyController = TextEditingController(text: vehicle?.energy ?? 'Electric');
    _ratingController = TextEditingController(text: '${vehicle?.rating ?? 4.8}');
    _inventoryController = TextEditingController(
      text: '${vehicle?.inventoryCount ?? 1}',
    );
    _hourRateController = TextEditingController(
      text: _rateText(vehicle, RentalUnit.hour, fallback: 4),
    );
    _dayRateController = TextEditingController(
      text: _rateText(vehicle, RentalUnit.day, fallback: 24),
    );
    _weekRateController = TextEditingController(
      text: _rateText(vehicle, RentalUnit.week, fallback: 150),
    );
    _monthRateController = TextEditingController(
      text: _rateText(vehicle, RentalUnit.month, fallback: 520),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _seatsController.dispose();
    _transmissionController.dispose();
    _energyController.dispose();
    _ratingController.dispose();
    _inventoryController.dispose();
    _hourRateController.dispose();
    _dayRateController.dispose();
    _weekRateController.dispose();
    _monthRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialVehicle = widget.initialVehicle;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_isEditing ? 'Edit vehicle' : 'Add vehicle'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle photo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: SizedBox(
                            width: 180,
                            height: 140,
                            child: _PickedOrExistingVehicleImage(
                              vehicle: initialVehicle,
                              pickedImage: _pickedImage,
                              selectedType: _selectedType,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _pickImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _pickedImage == null ? 'Choose image' : 'Change image',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _pickGalleryImages,
                          icon: const Icon(Icons.collections_outlined),
                          label: Text(
                            _pickedGalleryImages.isEmpty
                                ? 'Add gallery images'
                                : 'Update gallery (${_pickedGalleryImages.length})',
                          ),
                        ),
                      ),
                      if (_galleryPreviewUrls(initialVehicle).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 58,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _galleryPreviewUrls(initialVehicle).length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final path = _galleryPreviewUrls(initialVehicle)[index];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 74,
                                  height: 58,
                                  child: _buildGalleryPreviewImage(path),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<VehicleType>(
                        initialValue: _selectedType,
                        items: VehicleType.values
                            .map(
                              (type) => DropdownMenuItem<VehicleType>(
                                value: type,
                                child: Text(type.label),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() => _selectedType = value);
                              },
                        decoration: const InputDecoration(
                          labelText: 'Vehicle type',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Vehicle name'),
                        validator: _requiredValidator('Enter a vehicle name.'),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPickupHub,
                        items: _pickupHubOptions
                            .map(
                              (hub) => DropdownMenuItem<String>(
                                value: hub,
                                child: Text(hub),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() => _selectedPickupHub = value);
                              },
                        decoration: const InputDecoration(labelText: 'Pickup hub'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        minLines: 3,
                        maxLines: 4,
                        validator: _requiredValidator('Add a short description.'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _seatsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Seats'),
                              validator: _numberValidator('Enter seat count.'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _inventoryController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Units in fleet'),
                              validator: _wholeNumberValidator('Enter available fleet size.'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _ratingController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Rating'),
                        validator: _numberValidator('Enter a rating.'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _transmissionController,
                              decoration: const InputDecoration(
                                labelText: 'Transmission',
                              ),
                              validator: _requiredValidator('Enter transmission.'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _energyController,
                              decoration: const InputDecoration(labelText: 'Energy'),
                              validator: _requiredValidator('Enter energy type.'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        value: _availableNow,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available now'),
                        subtitle: const Text('Show this vehicle as ready to book.'),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _availableNow = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pricing',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
            const SizedBox(height: 28),
            Row(
              children: [
                          Expanded(
                            child: TextFormField(
                              controller: _hourRateController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(labelText: 'Hour'),
                              validator: _numberValidator('Enter hourly price.'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _dayRateController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(labelText: 'Day'),
                              validator: _numberValidator('Enter daily price.'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _weekRateController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(labelText: 'Week'),
                              validator: _numberValidator('Enter weekly price.'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _monthRateController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(labelText: 'Month'),
                              validator: _numberValidator('Enter monthly price.'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: FilledButton(
          onPressed: _saving ? null : _saveVehicle,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          child: Text(_saving ? 'Saving...' : (_isEditing ? 'Save changes' : 'Create vehicle')),
        ),
      ),
    );
  }

  String _rateText(
    Vehicle? vehicle,
    RentalUnit unit, {
    required double fallback,
  }) {
    final matchingRates = vehicle?.rates.where((item) => item.unit == unit);
    final rate = matchingRates == null || matchingRates.isEmpty
        ? null
        : matchingRates.first;
    final value = rate?.price ?? fallback;
    return _formatVehiclePrice(value);
  }

  String? Function(String?) _requiredValidator(String message) {
    return (value) {
      if ((value ?? '').trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  String? Function(String?) _numberValidator(String message) {
    return (value) {
      final parsed = double.tryParse((value ?? '').trim());
      if (parsed == null) {
        return message;
      }
      return null;
    };
  }

  String _normalizedPickupHub(String? location) {
    final normalized = (location ?? '').trim();
    if (normalized == 'Phnom Penh Center') {
      return 'Wat Phnom';
    }
    if (_pickupHubOptions.contains(normalized)) {
      return normalized;
    }
    return _pickupHubOptions.first;
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null || !mounted) {
      return;
    }
    setState(() => _pickedImage = image);
  }

  String? Function(String?) _wholeNumberValidator(String message) {
    return (value) {
      final parsed = int.tryParse((value ?? '').trim());
      if (parsed == null || parsed < 1) {
        return message;
      }
      return null;
    };
  }

  Future<void> _pickGalleryImages() async {
    final images = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      limit: 4,
    );
    if (images.isEmpty || !mounted) {
      return;
    }
    setState(() => _pickedGalleryImages = images.take(4).toList());
  }

  List<String> _galleryPreviewUrls(Vehicle? initialVehicle) {
    if (_pickedGalleryImages.isNotEmpty) {
      return _pickedGalleryImages.map((image) => image.path).toList();
    }
    return initialVehicle?.allImageUrls ?? const [];
  }

  Widget _buildGalleryPreviewImage(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    if (_pickedGalleryImages.any((image) => image.path == path)) {
      return kIsWeb
          ? Image.network(path, fit: BoxFit.cover)
          : Image.file(File(path), fit: BoxFit.cover);
    }
    return kIsWeb
        ? Image.network(path, fit: BoxFit.cover)
        : CachedNetworkImage(imageUrl: path, fit: BoxFit.cover);
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final existing = widget.initialVehicle;
      final id = existing?.id ?? _slugify(_nameController.text.trim());
      var imageUrl = existing?.imageUrl ?? '';
      var imageStoragePath = existing?.imageStoragePath;
      var galleryImageUrls = List<String>.from(existing?.galleryImageUrls ?? const []);

      if (_pickedImage != null) {
        final uploadedImage = await widget.vehicleRepository.uploadVehicleImage(
          vehicleId: id,
          image: _pickedImage!,
        );
        imageUrl = uploadedImage.downloadUrl;
        imageStoragePath = uploadedImage.storagePath;
      }

      if (_pickedGalleryImages.isNotEmpty) {
        final uploadedGallery = await widget.vehicleRepository.uploadVehicleGalleryImages(
          vehicleId: id,
          images: _pickedGalleryImages,
        );
        galleryImageUrls = uploadedGallery.map((item) => item.downloadUrl).toList();
      }

      if (galleryImageUrls.isEmpty && imageUrl.trim().isNotEmpty) {
        galleryImageUrls = [imageUrl.trim()];
      } else if (galleryImageUrls.isNotEmpty && imageUrl.trim().isEmpty) {
        imageUrl = galleryImageUrls.first;
      } else if (galleryImageUrls.isNotEmpty && imageUrl.trim().isNotEmpty) {
        final normalizedPrimary = imageUrl.trim();
        galleryImageUrls = [
          normalizedPrimary,
          ...galleryImageUrls.where((url) => url.trim().isNotEmpty && url.trim() != normalizedPrimary),
        ];
      }

      final vehicle = Vehicle(
        id: id,
        name: _nameController.text.trim(),
        type: _selectedType,
        imageUrl: imageUrl,
        location: _selectedPickupHub,
        description: _descriptionController.text.trim(),
        seats: int.tryParse(_seatsController.text.trim()) ?? 1,
        transmission: _transmissionController.text.trim(),
        energy: _energyController.text.trim(),
        rating: double.tryParse(_ratingController.text.trim()) ?? 4.5,
        availableNow: _availableNow,
        inventoryCount: int.tryParse(_inventoryController.text.trim()) ?? 1,
        imageStoragePath: imageStoragePath,
        galleryImageUrls: galleryImageUrls,
        rates: [
          VehicleRate(
            unit: RentalUnit.hour,
            price: double.parse(_hourRateController.text.trim()),
          ),
          VehicleRate(
            unit: RentalUnit.day,
            price: double.parse(_dayRateController.text.trim()),
          ),
          VehicleRate(
            unit: RentalUnit.week,
            price: double.parse(_weekRateController.text.trim()),
          ),
          VehicleRate(
            unit: RentalUnit.month,
            price: double.parse(_monthRateController.text.trim()),
          ),
        ],
      );

      await widget.vehicleRepository.saveVehicle(vehicle);
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: _isEditing ? 'Vehicle updated.' : 'Vehicle created.',
        tone: AppBannerTone.success,
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: 'Could not save this vehicle right now.',
        tone: AppBannerTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _slugify(String rawName) {
    final base = rawName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final safeBase = base.isEmpty ? 'vehicle' : base;
    if (_isEditing) {
      return safeBase;
    }
    return '$safeBase-${DateTime.now().millisecondsSinceEpoch}';
  }
}

class _PickedOrExistingVehicleImage extends StatelessWidget {
  const _PickedOrExistingVehicleImage({
    required this.vehicle,
    required this.pickedImage,
    required this.selectedType,
  });

  final Vehicle? vehicle;
  final XFile? pickedImage;
  final VehicleType selectedType;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    if (pickedImage != null) {
      if (kIsWeb) {
        return Image.network(
          pickedImage!.path,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return _loading(colors);
          },
          errorBuilder: (_, _, _) => _fallback(colors),
        );
      }
      return Image.file(
        File(pickedImage!.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(colors),
      );
    }

    final imagePath = vehicle?.imageUrl.trim() ?? '';
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(colors),
      );
    }
    if (imagePath.isNotEmpty) {
      return kIsWeb
          ? Image.network(
              imagePath,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return _loading(colors);
              },
              errorBuilder: (context, error, stackTrace) => _fallback(colors),
            )
          : CachedNetworkImage(
              imageUrl: imagePath,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (context, url) => _loading(colors),
              errorWidget: (context, url, error) => _fallback(colors),
            );
    }
    return _fallback(colors);
  }

  Widget _loading(AppPalette colors) {
    return Container(
      color: colors.surfaceSoft,
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

  Widget _fallback(AppPalette colors) {
    return Container(
      color: colors.brandTintStrong,
      child: Icon(
        selectedType.icon,
        size: 42,
        color: colors.brand,
      ),
    );
  }
}

String _formatVehiclePrice(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _formatAdminBookingDay(DateTime value) {
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
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String _formatAdminBookingTime(DateTime value) {
  final hour24 = value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:$minute $period';
}

String _adminFavoriteVehicleTypeLabel(List<BookingRecord> bookings) {
  if (bookings.isEmpty) {
    return 'No bookings yet';
  }
  final counts = <VehicleType, int>{};
  for (final booking in bookings) {
    counts.update(booking.vehicle.type, (value) => value + 1, ifAbsent: () => 1);
  }
  final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return best.key.label;
}

String _adminFavoritePickupHub(List<BookingRecord> bookings) {
  if (bookings.isEmpty) {
    return 'No bookings yet';
  }
  final counts = <String, int>{};
  for (final booking in bookings) {
    counts.update(booking.pickupHub, (value) => value + 1, ifAbsent: () => 1);
  }
  final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return best.key;
}




