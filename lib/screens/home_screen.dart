import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/rental_models.dart';
import '../services/auth_repository.dart';
import '../services/booking_repository.dart';
import '../services/notification_repository.dart';
import '../services/profile_repository.dart';
import '../services/support_repository.dart';
import '../services/vehicle_repository.dart';
import '../theme/app_palette.dart';
import '../widgets/rental_widgets.dart';
import 'notifications_screen.dart';
import 'admin_vehicles_screen.dart';
import 'rental_app.dart';
import 'booking_screen.dart';
import 'profile_setup_screen.dart';
import 'support_chat_screen.dart';

class RentalHomeScreen extends StatefulWidget {
  const RentalHomeScreen({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.vehicleRepository,
    required this.bookingRepository,
    required this.notificationRepository,
    required this.supportRepository,
    required this.currentUser,
    required this.currentProfile,
    required this.initialTabIndex,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final VehicleRepository vehicleRepository;
  final BookingRepository bookingRepository;
  final NotificationRepository notificationRepository;
  final SupportRepository supportRepository;
  final AuthUser currentUser;
  final UserProfile currentProfile;
  final int initialTabIndex;

  @override
  State<RentalHomeScreen> createState() => _RentalHomeScreenState();
}

class _RentalHomeScreenState extends State<RentalHomeScreen> {
  static const String _allHubsLabel = 'All hubs';

  late int _currentIndex;
  final PageController _featuredPageController = PageController(viewportFraction: 0.84);
  final ScrollController _homeScrollController = ScrollController();
  final GlobalKey _resultsSectionKey = GlobalKey();
  VehicleType? selectedType;
  Vehicle? selectedVehicle = demoVehicles.first;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Vehicle> _featuredVehicles = [];
  List<Vehicle> _allVehicles = demoVehicles;
  StreamSubscription<List<Vehicle>>? _vehicleSubscription;
  String? _vehicleLoadError;
  int _featuredPage = 0;
  String selectedArea = _allHubsLabel;
  BookingStatus? _selectedBookingStatusFilter;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _featuredVehicles = List<Vehicle>.from(demoVehicles)..shuffle(Random());
    _startVehicleSubscription();
    _searchController.addListener(_triggerRebuild);
    _searchFocusNode.addListener(_triggerRebuild);
  }

  List<Vehicle> get filteredVehicles {
    return _filteredVehiclesFrom(_allVehicles);
  }

  void _syncFeaturedVehicles(List<Vehicle> vehicles) {
    final currentIds = _featuredVehicles.map((vehicle) => vehicle.id).toList();
    final nextIds = vehicles.map((vehicle) => vehicle.id).toList();
    if (currentIds.length == nextIds.length &&
        currentIds.every((id) => nextIds.contains(id))) {
      _featuredVehicles = currentIds
          .map((id) => vehicles.firstWhere((vehicle) => vehicle.id == id))
          .toList();
      return;
    }

    final shuffled = List<Vehicle>.from(vehicles)..shuffle(Random());
    _featuredVehicles = shuffled;
  }

  List<String> get pickupAreas => [
        _allHubsLabel,
        ...({
          for (final vehicle in _allVehicles) ...vehicle.pickupHubs,
        }.toList()
          ..sort()),
      ];

  List<Vehicle> get searchSuggestions {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return const [];
    }
    return filteredVehicles.take(4).toList();
  }

  bool get _hasActiveSearchQuery => _searchController.text.trim().isNotEmpty;

  List<Vehicle> get _featuredDisplayVehicles {
    if (_hasActiveSearchQuery) {
      return filteredVehicles;
    }
    return _featuredVehicles;
  }

  bool get _isAdminUser => widget.currentProfile.isAdmin;

  int get _selectedBottomNavIndex {
    if (!_isAdminUser) {
      return _currentIndex;
    }

    switch (_currentIndex) {
      case 1:
        return 0;
      case 0:
        return 1;
      case 2:
      default:
        return 2;
    }
  }

  int _pageIndexForBottomNav(int navigationIndex) {
    if (!_isAdminUser) {
      return navigationIndex;
    }

    switch (navigationIndex) {
      case 0:
        return 1;
      case 1:
        return 0;
      case 2:
      default:
        return 2;
    }
  }

  String get _appBarTitle {
    if (_isAdminUser) {
      switch (_currentIndex) {
        case 1:
          return 'Customer Bookings';
        case 0:
          return 'Vehicles';
        case 2:
        default:
          return 'Profile';
      }
    }

    if (_currentIndex == 1) {
      return 'Bookings';
    }
    return 'Profile';
  }

  @override
  void dispose() {
    _vehicleSubscription?.cancel();
    _featuredPageController.dispose();
    _homeScrollController.dispose();
    _searchController.removeListener(_triggerRebuild);
    _searchFocusNode.removeListener(_triggerRebuild);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _triggerRebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openNotificationsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          notificationStream: widget.notificationRepository.watchNotifications(
            userId: widget.currentUser.id,
            isAdmin: _isAdminUser,
          ),
          bookingsStream: _isAdminUser
              ? widget.bookingRepository.watchAllBookings()
              : widget.bookingRepository.watchBookings(widget.currentUser.id),
          isAdmin: _isAdminUser,
          onAdminStatusSelected: _isAdminUser
              ? (booking, status) {
                  widget.bookingRepository.updateBookingStatus(
                    bookingId: booking.id,
                    status: status,
                    cancellationSource: status == BookingStatus.cancelled
                        ? BookingCancellationSource.admin
                        : null,
                  );
                }
              : null,
          onOpenBooking: (context, booking, onStatusSelected) {
            return _BookingHistoryCard(
              booking: booking,
              isAdmin: _isAdminUser,
              onStatusSelected: onStatusSelected,
            )._showBookingDetails(context);
          },
        ),
      ),
    );
  }

  Future<void> _openSupportInbox() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportInboxScreen(
          supportRepository: widget.supportRepository,
          bookingRepository: widget.bookingRepository,
          currentProfile: widget.currentProfile,
          currentUserId: widget.currentUser.id,
          isAdmin: _isAdminUser,
        ),
      ),
    );
  }

  Future<void> _openBookingSupportChat(BookingRecord booking) async {
    try {
      final conversation = await widget.supportRepository.getOrCreateBookingConversation(
        customerProfile: widget.currentProfile,
        booking: booking,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
        builder: (_) => SupportConversationScreen(
          supportRepository: widget.supportRepository,
          bookingRepository: widget.bookingRepository,
          currentProfile: widget.currentProfile,
          currentUserId: widget.currentUser.id,
          conversation: conversation,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final rawMessage = error.toString().trim();
      showAppBanner(
        context,
        message: rawMessage.isEmpty
            ? 'Could not open booking support right now.'
            : rawMessage,
        tone: AppBannerTone.error,
      );
    }
  }

  void _startVehicleSubscription() {
    _vehicleSubscription = widget.vehicleRepository.watchVehicles().listen(
      (vehicles) {
        if (!mounted) {
          return;
        }

        final nextVehicles = vehicles.isEmpty ? demoVehicles : vehicles;
        setState(() {
          _vehicleLoadError = null;
          _allVehicles = nextVehicles;
          _syncFeaturedVehicles(nextVehicles);
          _sanitizeSelectedArea();
          _reconcileSelectedVehicle();
          if (_featuredPage >= _featuredVehicles.length) {
            _featuredPage = _featuredVehicles.isEmpty ? 0 : _featuredVehicles.length - 1;
          }
        });
        _warmVehicleImages(nextVehicles);
      },
      onError: (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _vehicleLoadError = 'Live vehicles could not load. Showing saved demo rides instead.';
          _allVehicles = demoVehicles;
          _syncFeaturedVehicles(_allVehicles);
          _sanitizeSelectedArea();
          _reconcileSelectedVehicle();
          if (_featuredPage >= _featuredVehicles.length) {
            _featuredPage = _featuredVehicles.isEmpty ? 0 : _featuredVehicles.length - 1;
          }
        });
        _warmVehicleImages(_allVehicles);
      },
    );
  }

  void _warmVehicleImages(List<Vehicle> vehicles) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final uniquePaths = <String>{};
      for (final vehicle in vehicles.take(10)) {
        final path = vehicle.imageUrl.trim();
        if (path.isNotEmpty) {
          uniquePaths.add(path);
        }
      }

      for (final path in uniquePaths) {
        final ImageProvider provider = path.startsWith('assets/')
            ? AssetImage(path) as ImageProvider
            : (kIsWeb ? NetworkImage(path) : CachedNetworkImageProvider(path));
        precacheImage(provider, context);
      }
    });
  }

  void _sanitizeSelectedArea() {
    if (selectedArea != _allHubsLabel && !pickupAreas.contains(selectedArea)) {
      selectedArea = _allHubsLabel;
    }
  }

  void _reconcileSelectedVehicle() {
    final vehicles = filteredVehicles;
    if (selectedVehicle != null &&
        !vehicles.any((vehicle) => vehicle.id == selectedVehicle!.id)) {
      selectedVehicle = vehicles.isEmpty ? null : vehicles.first;
      return;
    }
    if (selectedVehicle == null && vehicles.isNotEmpty) {
      selectedVehicle = vehicles.first;
    }
  }

  bool _matchesVehicleSearch(Vehicle vehicle, List<String> terms) {
    final fields = [
      vehicle.name.toLowerCase(),
      vehicle.location.toLowerCase(),
      vehicle.description.toLowerCase(),
      vehicle.type.label.toLowerCase(),
      vehicle.energy.toLowerCase(),
    ];

    return terms.every(
      (term) => fields.any((field) => field.contains(term)),
    );
  }

  int _vehicleSearchScore(Vehicle vehicle, List<String> terms) {
    final name = vehicle.name.toLowerCase();
    final location = vehicle.location.toLowerCase();
    final type = vehicle.type.label.toLowerCase();
    final description = vehicle.description.toLowerCase();
    final energy = vehicle.energy.toLowerCase();
    var score = 0;

    for (final term in terms) {
      if (name == term) {
        score += 150;
      }
      if (name.startsWith(term)) {
        score += 100;
      }
      if (name.contains(term)) {
        score += 60;
      }
      if (location.startsWith(term)) {
        score += 40;
      }
      if (location.contains(term)) {
        score += 24;
      }
      if (type.startsWith(term)) {
        score += 30;
      }
      if (type.contains(term)) {
        score += 20;
      }
      if (energy.contains(term)) {
        score += 16;
      }
      if (description.contains(term)) {
        score += 10;
      }
    }

    score += (vehicle.rating * 2).round();
    if (vehicle.availableNow) {
      score += 3;
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final greetingName = widget.currentProfile.firstName.trim().isEmpty
        ? 'there'
        : widget.currentProfile.firstName.trim();
    final vehicles = filteredVehicles;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        leading: IconButton(
          tooltip: _isAdminUser ? 'Support inbox' : 'Customer support',
          onPressed: _openSupportInbox,
          icon: Icon(
            _isAdminUser
                ? Icons.support_agent_rounded
                : Icons.chat_bubble_outline_rounded,
          ),
        ),
        title: !_isAdminUser && _currentIndex == 0
            ? const AppLogo(compact: true)
            : Text(_appBarTitle),
        actions: [
          if (_currentIndex == 2)
            IconButton(
              tooltip: 'Notifications',
              onPressed: _openNotificationsScreen,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          IconButton(
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: () => JisNowApp.of(context).toggleThemeMode(),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isAdminUser
            ? IndexedStack(
                index: _currentIndex,
                children: [
                  AdminVehiclesScreen(
                    vehicleRepository: widget.vehicleRepository,
                    bookingRepository: widget.bookingRepository,
                    profileRepository: widget.profileRepository,
                    notificationRepository: widget.notificationRepository,
                    isAdmin: widget.currentProfile.isAdmin,
                    embeddedTabIndex: 1,
                  ),
                  AdminVehiclesScreen(
                    vehicleRepository: widget.vehicleRepository,
                    bookingRepository: widget.bookingRepository,
                    profileRepository: widget.profileRepository,
                    notificationRepository: widget.notificationRepository,
                    isAdmin: widget.currentProfile.isAdmin,
                    embeddedTabIndex: 0,
                  ),
                  _buildProfileTab(theme, colors),
                ],
              )
            : IndexedStack(
                index: _currentIndex,
                children: [
                  _buildHomeTab(theme, colors, vehicles, greetingName),
                  _buildBookingsTab(theme, colors, _allVehicles),
                  _buildProfileTab(theme, colors),
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedBottomNavIndex,
        onDestinationSelected: (index) {
          final pageIndex = _pageIndexForBottomNav(index);
          JisNowApp.of(context).rememberHomeTabIndex(pageIndex);
          setState(() => _currentIndex = pageIndex);
        },
        destinations: _isAdminUser
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.directions_car_outlined),
                  selectedIcon: Icon(Icons.directions_car_filled_rounded),
                  label: 'Vehicles',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
      ),
    );
  }

  List<Vehicle> _filteredVehiclesFrom(List<Vehicle> sourceVehicles) {
    final query = _searchController.text.trim().toLowerCase();
    final terms = query.split(RegExp(r'\s+')).where((term) => term.isNotEmpty).toList();
    final matches = sourceVehicles.where((vehicle) {
      final matchesType = selectedType == null || vehicle.type == selectedType;
      final matchesArea =
          selectedArea == _allHubsLabel || vehicle.pickupHubs.contains(selectedArea);
      final matchesQuery = terms.isEmpty || _matchesVehicleSearch(vehicle, terms);
      return matchesType && matchesArea && matchesQuery;
    }).toList();

    if (terms.isEmpty) {
      return matches;
    }

    matches.sort(
      (a, b) => _vehicleSearchScore(b, terms).compareTo(_vehicleSearchScore(a, terms)),
    );
    return matches;
  }

  Widget _buildHomeTab(
    ThemeData theme,
    AppPalette colors,
    List<Vehicle> vehicles,
    String greetingName,
  ) {
    final isLightMode = theme.brightness == Brightness.light;
    final heroGradient = isLightMode
        ? const [Color(0xFF1C4E3E), Color(0xFF5C886F)]
        : [colors.brandDeep, colors.brandMid];
    final featuredVehicles = _featuredDisplayVehicles;
    final rentalsTitle = selectedArea == _allHubsLabel
        ? 'Popular rides'
        : '$selectedArea rides';
    final rentalsSubtitle = vehicles.isEmpty
        ? 'No vehicles match this filter yet.'
        : selectedArea == _allHubsLabel
            ? 'Fast electric rentals ready to book across your hubs.'
            : 'Ready from this pickup hub.';

    return ListView(
      controller: _homeScrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: heroGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_vehicleLoadError != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    _vehicleLoadError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              Row(
                children: [
                  ProfileAvatar(
                    imageUrl: widget.currentProfile.photoUrl,
                    initials: widget.currentProfile.initials,
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    textColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, $greetingName',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.currentProfile.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Search model, location, or vehicle type',
                          hintStyle: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.76),
                          ),
                        ),
                      ),
                    ),
                    if (_searchController.text.trim().isNotEmpty) ...[
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Search by model, hub, or ride type to jump straight into booking.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              if (_searchFocusNode.hasFocus && _searchController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _SearchSuggestionPanel(
                  vehicles: searchSuggestions,
                  onSelect: (vehicle) {
                    setState(() {
                      selectedVehicle = vehicle;
                      _searchController.text = vehicle.name;
                    });
                    _searchFocusNode.unfocus();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (featuredVehicles.isNotEmpty) ...[
          if (_hasActiveSearchQuery) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Matches for "${_searchController.text.trim()}"',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${featuredVehicles.length} match${featuredVehicles.length == 1 ? '' : 'es'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Swipe through matching rides, then tap a card to focus it below.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 236,
              child: AnimatedBuilder(
                animation: _featuredPageController,
                builder: (context, child) {
                  return PageView.builder(
                    controller: _featuredPageController,
                    itemCount: featuredVehicles.length,
                    onPageChanged: (index) => setState(() => _featuredPage = index),
                    itemBuilder: (context, index) {
                      final vehicle = featuredVehicles[index];
                      double page = _featuredPage.toDouble();
                      if (_featuredPageController.hasClients &&
                          _featuredPageController.position.hasPixels) {
                        page = _featuredPageController.page ?? _featuredPage.toDouble();
                      }
                      final distance = (page - index).abs().clamp(0.0, 1.0);
                      final direction = page > index ? -1.0 : 1.0;
                      final scale = 1 - (distance * 0.05);
                      final verticalInset = 6 + (distance * 14);
                      final opacity = 1 - (distance * 0.08);
                      final rotation = direction * distance * 0.045;

                      return Transform.translate(
                        offset: Offset(direction * distance * 6, 0),
                        child: Transform.rotate(
                          angle: rotation,
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  index == 0 ? 4 : 8,
                                  verticalInset,
                                  index == featuredVehicles.length - 1 ? 4 : 8,
                                  verticalInset,
                                ),
                                child: _FeaturedVehicleCard(
                                  vehicle: vehicle,
                                  actionLabel: 'View result',
                                  swipeProgress: (page - index).clamp(-1.0, 1.0),
                                  onTap: () => _showVehicleDetails(vehicle),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  featuredVehicles.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _featuredPage == index ? 22 : 8,
                    decoration: BoxDecoration(
                      color: _featuredPage == index ? colors.brand : colors.borderSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text(
              'Featured rides',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Swipe to explore featured vehicles.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 236,
              child: AnimatedBuilder(
                animation: _featuredPageController,
                builder: (context, child) {
                  return PageView.builder(
                    controller: _featuredPageController,
                    itemCount: featuredVehicles.length,
                    onPageChanged: (index) => setState(() => _featuredPage = index),
                    itemBuilder: (context, index) {
                      final vehicle = featuredVehicles[index];
                      double page = _featuredPage.toDouble();
                      if (_featuredPageController.hasClients &&
                          _featuredPageController.position.hasPixels) {
                        page = _featuredPageController.page ?? _featuredPage.toDouble();
                      }
                      final distance = (page - index).abs().clamp(0.0, 1.0);
                      final direction = page > index ? -1.0 : 1.0;
                      final scale = 1 - (distance * 0.05);
                      final verticalInset = 6 + (distance * 14);
                      final opacity = 1 - (distance * 0.08);
                      final rotation = direction * distance * 0.045;

                      return Transform.translate(
                        offset: Offset(direction * distance * 6, 0),
                        child: Transform.rotate(
                          angle: rotation,
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  index == 0 ? 4 : 8,
                                  verticalInset,
                                  index == featuredVehicles.length - 1 ? 4 : 8,
                                  verticalInset,
                                ),
                                child: _FeaturedVehicleCard(
                                  vehicle: vehicle,
                                  actionLabel: _isAdminUser ? 'Manage this ride' : 'Book this ride',
                                  swipeProgress: (page - index).clamp(-1.0, 1.0),
                                  onTap: () {
                                    setState(() => selectedVehicle = vehicle);
                                    if (_isAdminUser) {
                                      _openAdminVehicles(initialTabIndex: 1);
                                      return;
                                    }
                                    _showVehicleDetails(vehicle);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  featuredVehicles.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _featuredPage == index ? 22 : 8,
                    decoration: BoxDecoration(
                      color: _featuredPage == index ? colors.brand : colors.borderSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
        Text(
          'Browse by type',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a ride style first, then compare the best electric options.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CategoryCard(
                label: 'All rides',
                icon: Icons.apps_rounded,
                isSelected: selectedType == null,
                onTap: () => setState(() => selectedType = null),
              ),
              const SizedBox(width: 12),
              ...VehicleType.values.expand(
                (type) => [
                  _CategoryCard(
                    label: type.label,
                    icon: type.icon,
                    isSelected: selectedType == type,
                    onTap: () => setState(() => selectedType = type),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pickupAreas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final area = pickupAreas[index];
              final isSelected = selectedArea == area;
              return ChoiceChip(
                label: Text(area),
                selected: isSelected,
                onSelected: (_) => setState(() => selectedArea = area),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: colors.brandTintStrong,
                backgroundColor: colors.surface,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : colors.border,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        Row(
          key: _resultsSectionKey,
          children: [
            Expanded(
              child: Text(
                rentalsTitle,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${vehicles.length} available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          rentalsSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (vehicles.isEmpty)
          AppEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No vehicles found',
            message:
                'Try another pickup hub, change vehicle type, or clear your search words.',
            actionLabel: 'Clear filters',
            onAction: _clearFilters,
          ),
        ...vehicles.map(
          (vehicle) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: VehicleCard(
              vehicle: vehicle,
              selectedUnit: RentalUnit.day,
              isSelected: selectedVehicle?.id == vehicle.id,
              onTap: () {
                setState(() => selectedVehicle = vehicle);
                if (_isAdminUser) {
                  _openAdminVehicles(initialTabIndex: 1);
                  return;
                }
                _showVehicleDetails(vehicle);
              },
              onBookTap: _isAdminUser
                  ? () => _openAdminVehicles(initialTabIndex: 1)
                  : () => _openBookingScreen(vehicle),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingsTab(ThemeData theme, AppPalette colors, List<Vehicle> vehicles) {
    if (_isAdminUser) {
      return _buildAdminBookingsOverview(theme, colors);
    }

    final quickPickVehicles = vehicles.take(3).toList();

    return StreamBuilder<List<BookingRecord>>(
      stream: widget.bookingRepository.watchBookings(widget.currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookings could not load',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'There was a problem reading your reservations from Firestore. Please try again after reopening the app.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final bookings = snapshot.data ?? const <BookingRecord>[];
        final filteredBookings = _selectedBookingStatusFilter == null
            ? bookings
            : bookings
                .where((booking) => booking.status == _selectedBookingStatusFilter)
                .toList();
        int bookingPriority(BookingRecord booking) {
          switch (booking.status) {
            case BookingStatus.pending:
              return 0;
            case BookingStatus.confirmed:
              return 1;
            case BookingStatus.cancelled:
              return 2;
            case BookingStatus.completed:
              return 3;
          }
        }

        int compareBookings(BookingRecord a, BookingRecord b) {
          final priorityComparison =
              bookingPriority(a).compareTo(bookingPriority(b));
          if (priorityComparison != 0) {
            return priorityComparison;
          }
          final startDateComparison = b.startDate.compareTo(a.startDate);
          if (startDateComparison != 0) {
            return startDateComparison;
          }
          return b.createdAt.compareTo(a.createdAt);
        }

        final activeBookings = (filteredBookings
            .where(
              (booking) =>
                  booking.status == BookingStatus.pending ||
                  booking.status == BookingStatus.confirmed,
            )
            .toList()
          ..sort(compareBookings));
        final completedBookings = (filteredBookings
            .where((booking) => booking.status == BookingStatus.completed)
            .toList()
          ..sort(compareBookings));
        final cancelledBookings = (filteredBookings
            .where((booking) => booking.status == BookingStatus.cancelled)
            .toList()
          ..sort(compareBookings));
        final recentBookings = _selectedBookingStatusFilter == null
            ? (filteredBookings
                  .where(
                    (booking) =>
                        booking.status != BookingStatus.pending &&
                        booking.status != BookingStatus.confirmed,
                  )
                  .toList()
                ..sort(compareBookings))
                .take(3)
                .toList()
            : const <BookingRecord>[];
        final showRecentBookingsSection = recentBookings.isNotEmpty &&
            !listEquals(
              recentBookings.map((booking) => booking.id).toList(),
              activeBookings.take(recentBookings.length).map((booking) => booking.id).toList(),
            );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (bookings.isEmpty)
              AppEmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'No active bookings yet',
                message:
                    'When you confirm a ride, it will appear here with pickup time, duration, and total price.',
                actionLabel: 'Browse vehicles',
                onAction: () => setState(() => _currentIndex = 0),
              )
            else ...[
              AppSectionHeader(
                title: 'Your bookings',
                subtitle: 'Recent reservations saved from your account.',
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatusFilterChip(
                      label: 'All',
                      selected: _selectedBookingStatusFilter == null,
                      onTap: () {
                        setState(() => _selectedBookingStatusFilter = null);
                      },
                    ),
                    for (final status in BookingStatus.values) ...[
                      const SizedBox(width: 10),
                      _StatusFilterChip(
                        label: status.label,
                        selected: _selectedBookingStatusFilter == status,
                        onTap: () {
                          setState(() => _selectedBookingStatusFilter = status);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (filteredBookings.isEmpty)
                AppEmptyState(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'No ${_selectedBookingStatusFilter?.label.toLowerCase() ?? ''} bookings',
                  message:
                      'Try another status filter to review the rest of your reservations.',
                )
              else if (_selectedBookingStatusFilter != null)
                ...filteredBookings.map(
                  (booking) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _BookingHistoryCard(
                      booking: booking,
                      isAdmin: widget.currentProfile.isAdmin,
                      onStatusSelected: widget.currentProfile.isAdmin
                          ? (status) {
                              widget.bookingRepository.updateBookingStatus(
                                bookingId: booking.id,
                                status: status,
                              );
                            }
                          : null,
                      onCancel: booking.status == BookingStatus.pending
                          ? () => _confirmCancelBooking(booking)
                          : null,
                      onSupportTap: widget.currentProfile.isAdmin
                          ? null
                          : () => _openBookingSupportChat(booking),
                    ),
                  ),
                )
              else ...[
                if (activeBookings.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: _BookingGroupSection(
                      title: 'Active now',
                      subtitle: 'Pending approvals and rides currently in progress.',
                      bookings: activeBookings,
                      isAdmin: widget.currentProfile.isAdmin,
                      onStatusSelected: widget.currentProfile.isAdmin
                          ? (booking, status) {
                              widget.bookingRepository.updateBookingStatus(
                                bookingId: booking.id,
                                status: status,
                              );
                            }
                          : null,
                      onCancelBooking: (booking) => _confirmCancelBooking(booking),
                      onSupportBooking: widget.currentProfile.isAdmin
                          ? null
                          : (booking) => _openBookingSupportChat(booking),
                    ),
                  ),
                if (showRecentBookingsSection) ...[
                  if (activeBookings.isNotEmpty) const SizedBox(height: 8),
                  _BookingGroupSection(
                    title: 'Recent bookings',
                    subtitle: 'Your latest completed and cancelled bookings.',
                    bookings: recentBookings,
                    isAdmin: widget.currentProfile.isAdmin,
                    onStatusSelected: widget.currentProfile.isAdmin
                        ? (booking, status) {
                            widget.bookingRepository.updateBookingStatus(
                              bookingId: booking.id,
                              status: status,
                            );
                          }
                        : null,
                    onCancelBooking: (booking) => _confirmCancelBooking(booking),
                    onSupportBooking: widget.currentProfile.isAdmin
                        ? null
                        : (booking) => _openBookingSupportChat(booking),
                  ),
                ],
                if (completedBookings.isNotEmpty) ...[
                  if (showRecentBookingsSection || activeBookings.isNotEmpty)
                    const SizedBox(height: 8),
                  _BookingGroupSection(
                    title: 'Completed',
                    subtitle: 'Finished rides saved in your history.',
                    bookings: completedBookings,
                    isAdmin: widget.currentProfile.isAdmin,
                    onStatusSelected: widget.currentProfile.isAdmin
                        ? (booking, status) {
                            widget.bookingRepository.updateBookingStatus(
                              bookingId: booking.id,
                              status: status,
                            );
                          }
                        : null,
                    onSupportBooking: widget.currentProfile.isAdmin
                        ? null
                        : (booking) => _openBookingSupportChat(booking),
                  ),
                ],
                if (cancelledBookings.isNotEmpty) ...[
                  if (showRecentBookingsSection ||
                      activeBookings.isNotEmpty ||
                      completedBookings.isNotEmpty)
                    const SizedBox(height: 8),
                  _BookingGroupSection(
                    title: 'Cancelled',
                    subtitle: 'Reservations that were cancelled before completion.',
                    bookings: cancelledBookings,
                    isAdmin: widget.currentProfile.isAdmin,
                    onStatusSelected: widget.currentProfile.isAdmin
                        ? (booking, status) {
                            widget.bookingRepository.updateBookingStatus(
                              bookingId: booking.id,
                              status: status,
                            );
                          }
                        : null,
                    onSupportBooking: widget.currentProfile.isAdmin
                        ? null
                        : (booking) => _openBookingSupportChat(booking),
                  ),
                ],
              ],
            ],
            const SizedBox(height: 22),
            Text(
              'Quick booking picks',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Jump into one of the most popular rentals without going back to search.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ...quickPickVehicles.map(
              (vehicle) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _MiniBookingCard(
                  vehicle: vehicle,
                  onTap: () => _openBookingScreen(vehicle),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminBookingsOverview(ThemeData theme, AppPalette colors) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.brandDeep, colors.brandMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin workspace',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Admin accounts cannot create customer bookings. Use this space to review reservations and manage the live vehicle catalog instead.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ProfilePrimaryActionCard(
          icon: Icons.receipt_long_rounded,
          title: 'Manage bookings',
          subtitle: 'Review customer reservations, open details, and update the booking status.',
          actionLabel: 'Open bookings',
          onTap: () => _openAdminVehicles(initialTabIndex: 0),
        ),
        const SizedBox(height: 14),
        _ProfilePrimaryActionCard(
          icon: Icons.directions_car_filled_rounded,
          title: 'Manage vehicles',
          subtitle: 'Add new vehicles, update pricing, replace images, and keep pickup hubs clean.',
          actionLabel: 'Open vehicles',
          onTap: () => _openAdminVehicles(initialTabIndex: 1),
        ),
        const SizedBox(height: 14),
        _ProfilePrimaryActionCard(
          icon: Icons.people_alt_rounded,
          title: 'Manage profiles',
          subtitle: 'Review customer and admin accounts, contact details, and profile completion.',
          actionLabel: 'Open profiles',
          onTap: () => _openAdminVehicles(initialTabIndex: 2),
        ),
        const SizedBox(height: 18),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: colors.brandTintStrong,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: colors.brand,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why booking is disabled here',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This keeps admin accounts focused on oversight only, so customer bookings always come from real customer profiles.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab(ThemeData theme, AppPalette colors) {
    final isPasswordUser = widget.currentUser.usesPasswordProvider;
    final isLightMode = theme.brightness == Brightness.light;
    final profileGradient = isLightMode
        ? const [Color(0xFF20513F), Color(0xFF638D75)]
        : [colors.brandDeep, colors.brandMid];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: profileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileAvatar(
                    imageUrl: widget.currentProfile.photoUrl,
                    initials: widget.currentProfile.initials,
                    radius: 32,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    textColor: Colors.white,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentProfile.displayName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.currentProfile.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ProfileTopPill(
                    icon: isPasswordUser
                        ? Icons.mail_outline_rounded
                        : Icons.g_mobiledata_rounded,
                    label: isPasswordUser ? 'Email account' : 'Google account',
                  ),
                  if (widget.currentProfile.phoneNumber.trim().isNotEmpty)
                    _ProfileTopPill(
                      icon: Icons.phone_iphone_rounded,
                      label: widget.currentProfile.phoneNumber,
                    ),
                  if (widget.currentProfile.isAdmin)
                    const _ProfileTopPill(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Admin',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _ProfileDetailRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'Email',
                  value: widget.currentProfile.email,
                ),
                const SizedBox(height: 12),
                _ProfileDetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: widget.currentProfile.phoneNumber.trim().isEmpty
                      ? 'Not added yet'
                      : widget.currentProfile.phoneNumber,
                ),
                const SizedBox(height: 12),
                _ProfileDetailRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Sign-in',
                  value: isPasswordUser ? 'Email and password' : 'Google account',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _ProfilePrimaryActionCard(
          icon: Icons.manage_accounts_rounded,
          title: 'Edit profile',
          subtitle: 'Update your photo, contact info, email, and password settings.',
          actionLabel: 'Edit profile',
          onTap: _openProfileEditor,
        ),
        if (_isAdminUser) ...[
          const SizedBox(height: 18),
          Text(
            'Customer profiles',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'View customer accounts and contact details. This section is read-only for admin.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<UserProfile>>(
            stream: widget.profileRepository.watchAllProfiles(),
            builder: (context, snapshot) {
              final customerProfiles = (snapshot.data ?? const <UserProfile>[])
                  .where((profile) => !profile.isAdmin)
                  .toList();

              if (snapshot.connectionState == ConnectionState.waiting &&
                  customerProfiles.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (customerProfiles.isEmpty) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'No customer profiles yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: customerProfiles
                    .map(
                      (profile) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ReadOnlyCustomerProfileCard(
                          profile: profile,
                          onTap: () => _showReadOnlyCustomerProfile(profile),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final colors = AppPalette.of(context);
              final isLightMode = theme.brightness == Brightness.light;
              return OutlinedButton.icon(
                onPressed: widget.authRepository.signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isLightMode ? colors.textPrimary : null,
                  side: BorderSide(
                    color: isLightMode ? colors.border : colors.borderSoft,
                  ),
                  backgroundColor: isLightMode ? colors.surface : null,
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openProfileEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSetupScreen(
          authRepository: widget.authRepository,
          profileRepository: widget.profileRepository,
          authUser: widget.currentUser,
          initialProfile: widget.currentProfile,
          isInitialSetup: false,
        ),
      ),
    );
  }

  Future<void> _openBookingScreen(Vehicle vehicle) async {
    if (_isAdminUser) {
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: 'Admin accounts cannot create bookings. Use the admin tools instead.',
        tone: AppBannerTone.info,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingScreen(
          vehicle: vehicle,
          bookingRepository: widget.bookingRepository,
          notificationRepository: widget.notificationRepository,
          authUser: widget.currentUser,
          userProfile: widget.currentProfile,
        ),
      ),
    );
  }

  Future<void> _showVehicleDetails(Vehicle vehicle) async {
    await showVehicleDetailsSheet(
      context,
      vehicle: vehicle,
      primaryActionLabel: _isAdminUser ? 'Open vehicle tools' : 'Book now',
      onPrimaryAction: _isAdminUser
          ? () => _openAdminVehicles(initialTabIndex: 1)
          : () => _openBookingScreen(vehicle),
      secondaryActionLabel: _isAdminUser ? null : 'Back Home',
      onSecondaryAction: _isAdminUser
          ? null
          : () {
              setState(() => selectedVehicle = vehicle);
              _previewVehicleResult(vehicle);
            },
    );
  }

  Future<void> _showReadOnlyCustomerProfile(UserProfile profile) async {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

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
              final completedBookings = bookings
                  .where((booking) => booking.status == BookingStatus.completed)
                  .length;
              final totalSpent = bookings
                  .where((booking) => booking.status == BookingStatus.completed)
                  .fold<double>(0, (sum, booking) => sum + booking.totalPrice);
              final lastBooking = bookings.isEmpty ? null : bookings.first;
              final joinedLabel = profile.createdAt == null
                  ? 'Not available'
                  : _formatBookingDate(profile.createdAt!);
              final favoriteType = _favoriteVehicleTypeLabel(bookings);
              final favoriteHub = _favoritePickupHub(bookings);

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
                    const SizedBox(height: 18),
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
                                profile.displayName.isEmpty
                                    ? 'Unnamed customer'
                                    : profile.displayName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Customer profile',
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
                          child: _CustomerBookingSummaryCard(
                            icon: Icons.receipt_long_rounded,
                            label: 'Total bookings',
                            value: bookings.length.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CustomerBookingSummaryCard(
                            icon: Icons.electric_car_rounded,
                            label: 'Active now',
                            value: activeBookings.toString(),
                          ),
                        ),
                      ],
                    ),
                    if (completedBookings > 0) ...[
                      const SizedBox(height: 12),
                      _CustomerBookingSummaryCard(
                        icon: Icons.task_alt_rounded,
                        label: 'Completed bookings',
                        value: completedBookings.toString(),
                        fullWidth: true,
                      ),
                    ],
                    if (totalSpent > 0) ...[
                      const SizedBox(height: 12),
                      _CustomerBookingSummaryCard(
                        icon: Icons.payments_outlined,
                        label: 'Total spent',
                        value: '\$${totalSpent.toStringAsFixed(totalSpent == totalSpent.roundToDouble() ? 0 : 1)}',
                        fullWidth: true,
                      ),
                    ],
                    if (lastBooking != null) ...[
                      const SizedBox(height: 12),
                      _CustomerBookingSummaryCard(
                        icon: Icons.history_rounded,
                        label: 'Last booking',
                        value: _formatBookingDate(lastBooking.createdAt),
                        fullWidth: true,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _ProfileDetailRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: profile.email.isEmpty ? 'Not added yet' : profile.email,
                    ),
                    const SizedBox(height: 12),
                    _ProfileDetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: profile.phoneNumber.isEmpty ? 'Not added yet' : profile.phoneNumber,
                    ),
                    const SizedBox(height: 12),
                    _ProfileDetailRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Profile status',
                      value: profile.profileComplete ? 'Complete' : 'Incomplete',
                    ),
                    const SizedBox(height: 12),
                    _ProfileDetailRow(
                      icon: Icons.category_outlined,
                      label: 'Favorite ride type',
                      value: favoriteType,
                    ),
                    const SizedBox(height: 12),
                    _ProfileDetailRow(
                      icon: Icons.place_outlined,
                      label: 'Favorite pickup hub',
                      value: favoriteHub,
                    ),
                    const SizedBox(height: 12),
                    _ProfileDetailRow(
                      icon: Icons.event_available_rounded,
                      label: 'Joined',
                      value: joinedLabel,
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

  Future<void> _openAdminVehicles({int initialTabIndex = 0}) async {
    if (!widget.currentProfile.isAdmin) {
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: 'Admin access is required for vehicle management.',
        tone: AppBannerTone.warning,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminVehiclesScreen(
          vehicleRepository: widget.vehicleRepository,
          bookingRepository: widget.bookingRepository,
          profileRepository: widget.profileRepository,
          notificationRepository: widget.notificationRepository,
          isAdmin: widget.currentProfile.isAdmin,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  Future<void> _confirmCancelBooking(BookingRecord booking) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel booking'),
          content: Text(
            'Cancel ${booking.vehicle.name}? This will mark the booking as cancelled.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep booking'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel booking'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !mounted) {
      return;
    }

    await widget.bookingRepository.updateBookingStatus(
      bookingId: booking.id,
      status: BookingStatus.cancelled,
      cancellationSource: BookingCancellationSource.customer,
    );

    if (!mounted) {
      return;
    }
    showAppBanner(
      context,
      message: '${booking.vehicle.name} was cancelled.',
      tone: AppBannerTone.warning,
    );
  }

  void _clearFilters() {
    setState(() {
      selectedType = null;
      selectedArea = _allHubsLabel;
      _searchController.clear();
      selectedVehicle = _allVehicles.isEmpty ? null : _allVehicles.first;
    });
    _searchFocusNode.unfocus();
  }

  void _previewVehicleResult(Vehicle vehicle) {
    setState(() {
      selectedVehicle = vehicle;
    });
    _searchFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _resultsSectionKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        width: 74,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.brandDeep : colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? colors.brandDeep : colors.border,
          ),
          boxShadow: isSelected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.14)
                    : colors.brandTintStrong,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : colors.brand,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected ? Colors.white : colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBookingCard extends StatelessWidget {
  const _MiniBookingCard({
    required this.vehicle,
    required this.onTap,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final accentTextColor = theme.brightness == Brightness.light
        ? colors.textPrimary
        : colors.brand;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _VehiclePreviewImage(
              vehicle: vehicle,
              width: _VehiclePreviewImage.bookingThumbWidth,
              height: _VehiclePreviewImage.bookingThumbHeight,
              borderRadius: _VehiclePreviewImage.bookingThumbRadius,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vehicle.type.label} | ${vehicle.location}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${vehicle.rateFor(RentalUnit.day).price.toStringAsFixed(0)} / day',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: accentTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onTap,
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehiclePreviewImage extends StatelessWidget {
  const _VehiclePreviewImage({
    required this.vehicle,
    required this.width,
    required this.height,
    required this.borderRadius,
    this.fit = BoxFit.cover,
    this.fallbackToArtwork = false,
  });

  final Vehicle vehicle;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final bool fallbackToArtwork;

  static const double bookingThumbWidth = 112;
  static const double bookingThumbHeight = 84;
  static const double bookingThumbRadius = 18;

  @override
  Widget build(BuildContext context) {
    final imageUrl = vehicle.imageUrl.trim();
    final isAssetImage = imageUrl.startsWith('assets/');
    final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final cacheWidth = width.isFinite ? (width * devicePixelRatio).round() : null;
    final cacheHeight = height.isFinite ? (height * devicePixelRatio).round() : null;

    if (imageUrl.isEmpty) {
      return _vehicleFallback(context);
    }

    if (isAssetImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: kIsWeb
          ? Image.network(
              imageUrl,
              width: width,
              height: height,
              fit: fit,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              gaplessPlayback: true,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return _vehicleLoadingPlaceholder(context);
              },
              errorBuilder: (context, error, stackTrace) => _vehicleFallback(context),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              width: width,
              height: height,
              fit: fit,
              memCacheWidth: cacheWidth,
              memCacheHeight: cacheHeight,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (context, url) => _vehicleLoadingPlaceholder(context),
              errorWidget: (context, url, error) => _vehicleFallback(context),
            ),
    );
  }

  Widget _vehicleLoadingPlaceholder(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
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

  Widget _vehicleFallback(BuildContext context) {
    if (fallbackToArtwork) {
      return _FeaturedVehicleFallback(vehicle: vehicle, borderRadius: borderRadius);
    }

    final colors = AppPalette.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.brandTintStrong,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        vehicle.type.icon,
        color: colors.brand,
        size: 28,
      ),
    );
  }
}

class _FeaturedVehicleFallback extends StatelessWidget {
  const _FeaturedVehicleFallback({
    required this.vehicle,
    required this.borderRadius,
  });

  final Vehicle vehicle;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: [colors.brandSoft, colors.brandDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          vehicle.type.icon,
          size: 72,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _BookingHistoryCard extends StatelessWidget {
  const _BookingHistoryCard({
    required this.booking,
    this.isAdmin = false,
    this.onStatusSelected,
    this.onCancel,
    this.onSupportTap,
  });

  final BookingRecord booking;
  final bool isAdmin;
  final ValueChanged<BookingStatus>? onStatusSelected;
  final VoidCallback? onCancel;
  final Future<void> Function()? onSupportTap;

  Future<void> _showBookingDetails(BuildContext context) async {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final rentalSubtotal = booking.totalPrice - booking.deliveryFee;

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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: _VehiclePreviewImage(
                    vehicle: booking.vehicle,
                    width: double.infinity,
                    height: 108,
                    borderRadius: 28,
                    fallbackToArtwork: true,
                  ),
                ),
                const SizedBox(height: 12),
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
                          const SizedBox(height: 4),
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
                    _BookingStatusChip(status: booking.status),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _BookingQuickInfoPill(
                      icon: Icons.calendar_month_rounded,
                      label: 'Start',
                      value:
                          '${_formatBookingDate(booking.startDate)} | ${_formatBookingTime(booking.startDate)}',
                    ),
                    _BookingQuickInfoPill(
                      icon: Icons.payments_outlined,
                      label: 'Total',
                      value: '\$${_formatBookingPrice(booking.totalPrice)}',
                    ),
                    _BookingQuickInfoPill(
                      icon: booking.fulfillmentMethod == 'delivery'
                          ? Icons.local_shipping_outlined
                          : Icons.storefront_outlined,
                      label: booking.fulfillmentMethod == 'delivery' ? 'Delivery' : 'Pickup',
                      value: booking.fulfillmentMethod == 'delivery'
                          ? 'Customer address'
                          : booking.pickupHub,
                    ),
                  ],
                ),
                if (isAdmin && booking.account != null) ...[
                  const SizedBox(height: 14),
                  _BookingSectionHeader(
                    title: 'Customer',
                  ),
                  const SizedBox(height: 10),
                  _BookingAccountCard(account: booking.account!),
                ],
                const SizedBox(height: 16),
                _BookingTimelineCard(booking: booking),
                if (isAdmin && onStatusSelected != null) ...[
                  const SizedBox(height: 14),
                  _BookingSectionHeader(
                    title: 'Update status',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: switch (booking.status) {
                      BookingStatus.pending => [
                          _AdminStatusActionButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onStatusSelected?.call(BookingStatus.confirmed);
                            },
                            icon: Icons.play_circle_outline_rounded,
                            label: 'Ongoing',
                            backgroundColor: const Color(0xFFD8ECFF),
                            foregroundColor: const Color(0xFF0F4C81),
                          ),
                          _AdminStatusActionButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onStatusSelected?.call(BookingStatus.cancelled);
                            },
                            icon: Icons.cancel_outlined,
                            label: 'Cancelled',
                            backgroundColor: colors.errorSoft,
                            foregroundColor: colors.errorText,
                          ),
                        ],
                      BookingStatus.confirmed => [
                          _AdminStatusActionButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onStatusSelected?.call(BookingStatus.completed);
                            },
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Returned',
                            backgroundColor: const Color(0xFFE6F6ED),
                            foregroundColor: const Color(0xFF155B3C),
                          ),
                          _AdminStatusActionButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onStatusSelected?.call(BookingStatus.cancelled);
                            },
                            icon: Icons.cancel_outlined,
                            label: 'Cancelled',
                            backgroundColor: colors.errorSoft,
                            foregroundColor: colors.errorText,
                          ),
                        ],
                      BookingStatus.completed => const <Widget>[],
                      BookingStatus.cancelled => const <Widget>[],
                    },
                  ),
                ],
                const SizedBox(height: 14),
                _BookingSectionHeader(
                  title: 'Booking details',
                ),
                const SizedBox(height: 10),
                if (isAdmin)
                  _AdminBookingDetailsPanel(
                    booking: booking,
                  )
                else
                  _BookingDetailCard(
                  children: [
                    _BookingDetailRow(
                      icon: booking.fulfillmentMethod == 'delivery'
                          ? Icons.local_shipping_outlined
                          : Icons.storefront_outlined,
                      label: booking.fulfillmentMethod == 'delivery' ? 'Delivery' : 'Pickup',
                      value: booking.fulfillmentMethod == 'delivery'
                          ? (booking.deliveryAddress ?? 'Customer address')
                          : booking.pickupHub,
                    ),
                    const SizedBox(height: 12),
                    _BookingDetailRow(
                      icon: Icons.schedule_rounded,
                      label: 'Schedule',
                      value:
                          '${_formatBookingDate(booking.startDate)}\n${_formatBookingTime(booking.startDate)} | ${booking.quantity} ${booking.unit.label.toLowerCase()} rental',
                    ),
                    const SizedBox(height: 12),
                    _BookingDetailRow(
                      icon: Icons.flag_outlined,
                      label: 'Return',
                      value:
                          '${_formatBookingDate(booking.endDate)}\n${_formatBookingTime(booking.endDate)}',
                    ),
                    const SizedBox(height: 12),
                    _BookingDetailRow(
                      icon: Icons.assignment_rounded,
                      label: 'Booking status',
                      value: booking.status.label,
                    ),
                    const SizedBox(height: 12),
                    _BookingDetailRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Booking reference',
                      value: booking.id,
                      maxLines: 1,
                    ),
                    if ((booking.deliveryNotes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _BookingDetailRow(
                        icon: Icons.notes_rounded,
                        label: 'Notes',
                        value: booking.deliveryNotes!.trim(),
                        maxLines: 4,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _BookingHighlightCard(
                  icon: Icons.payments_outlined,
                  label: 'Booking total',
                  value: '\$${_formatBookingPrice(booking.totalPrice)}',
                ),
                if (!isAdmin) ...[
                  const SizedBox(height: 14),
                  _BookingReminderCard(booking: booking),
                ],
                if (!isAdmin && onSupportTap != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await onSupportTap?.call();
                      },
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text('Customer support'),
                    ),
                  ),
                ],
                if (!isAdmin) ...[
                  const SizedBox(height: 14),
                  _BookingSectionHeader(
                    title: 'Price breakdown',
                  ),
                  const SizedBox(height: 10),
                  _BookingDetailCard(
                    children: [
                      _BookingDetailRow(
                        icon: Icons.calculate_outlined,
                        label: 'Price breakdown',
                        value:
                            'Rental: \$${_formatBookingPrice(rentalSubtotal)}\nDelivery: \$${_formatBookingPrice(booking.deliveryFee)}',
                      ),
                    ],
                  ),
                ],
                if (onCancel != null) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onCancel?.call();
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel booking'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.errorText,
                        side: BorderSide(color: colors.errorText.withValues(alpha: 0.24)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final accentTextColor = theme.brightness == Brightness.light
        ? colors.textPrimary
        : colors.brand;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBookingDetails(context),
        borderRadius: BorderRadius.circular(24),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _VehiclePreviewImage(
                      vehicle: booking.vehicle,
                      width: _VehiclePreviewImage.bookingThumbWidth,
                      height: _VehiclePreviewImage.bookingThumbHeight,
                      borderRadius: _VehiclePreviewImage.bookingThumbRadius,
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              booking.vehicle.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _BookingStatusChip(status: booking.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _BookingMetaLine(
                        icon: booking.fulfillmentMethod == 'delivery'
                            ? Icons.local_shipping_outlined
                            : Icons.storefront_outlined,
                        text: booking.fulfillmentMethod == 'delivery'
                            ? 'Delivery to ${booking.deliveryAddress ?? 'your address'}'
                            : 'Pickup at ${booking.pickupHub}',
                      ),
                      const SizedBox(height: 8),
                      _BookingMetaLine(
                        icon: Icons.schedule_rounded,
                        text:
                            '${_formatBookingDate(booking.startDate)} | ${_formatBookingTime(booking.startDate)} | ${booking.quantity} ${booking.unit.label.toLowerCase()} rental',
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 230;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${_formatBookingPrice(booking.totalPrice)} total',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: accentTextColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (isAdmin && onStatusSelected != null)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: PopupMenuButton<BookingStatus>(
                                    onSelected: onStatusSelected,
                                    itemBuilder: (context) => BookingStatus.values
                                        .map(
                                          (status) => PopupMenuItem<BookingStatus>(
                                            value: status,
                                            child: Text(status.label),
                                          ),
                                        )
                                        .toList(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceSoft,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: colors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Update',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 18,
                                            color: colors.textSecondary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: isCompact
                                      ? WrapAlignment.start
                                      : WrapAlignment.end,
                                  children: [
                                    if (!isAdmin && onSupportTap != null)
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          await onSupportTap?.call();
                                        },
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          side: BorderSide(color: colors.border),
                                        ),
                                        icon: const Icon(
                                          Icons.support_agent_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Support'),
                                      ),
                                  ],
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel booking'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.errorText,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingGroupSection extends StatelessWidget {
  const _BookingGroupSection({
    required this.title,
    required this.subtitle,
    required this.bookings,
    required this.isAdmin,
    this.onStatusSelected,
    this.onCancelBooking,
    this.onSupportBooking,
  });

  final String title;
  final String subtitle;
  final List<BookingRecord> bookings;
  final bool isAdmin;
  final void Function(BookingRecord booking, BookingStatus status)? onStatusSelected;
  final Future<void> Function(BookingRecord booking)? onCancelBooking;
  final Future<void> Function(BookingRecord booking)? onSupportBooking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...bookings.map(
          (booking) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _BookingHistoryCard(
              booking: booking,
              isAdmin: isAdmin,
              onStatusSelected: onStatusSelected == null
                  ? null
                  : (status) => onStatusSelected!(booking, status),
              onCancel: booking.status == BookingStatus.pending && onCancelBooking != null
                  ? () => onCancelBooking!(booking)
                  : null,
              onSupportTap: !isAdmin && onSupportBooking != null
                  ? () async => onSupportBooking!(booking)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingSectionHeader extends StatelessWidget {
  const _BookingSectionHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _BookingQuickInfoPill extends StatelessWidget {
  const _BookingQuickInfoPill({
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
    final isDarkMode = theme.brightness == Brightness.dark;
    final (background, iconSurface, iconTint, iconBorderColor) = switch (label) {
      'Total' => (
          isDarkMode ? const Color(0xFF1C3347) : const Color(0xFFE3F7EE),
          isDarkMode ? const Color(0xFFDDF7E8) : const Color(0xFFBEE8D0),
          isDarkMode ? const Color(0xFF47A978) : const Color(0xFF145235),
          isDarkMode ? const Color(0xCCBFE8CF) : const Color(0x00000000),
        ),
      'Start' => (
          isDarkMode ? const Color(0xFF1C3347) : const Color(0xFFE3F7EE),
          isDarkMode ? const Color(0xFFDDF7E8) : const Color(0xFFBEE8D0),
          isDarkMode ? const Color(0xFF47A978) : const Color(0xFF145235),
          isDarkMode ? const Color(0xCCBFE8CF) : const Color(0x00000000),
        ),
      _ => (
          colors.surfaceSoft,
          isDarkMode ? const Color(0xFFF3FAF2) : const Color(0xFFD7EACF),
          colors.textSecondary,
          isDarkMode ? const Color(0x99FFFFFF) : colors.borderSoft,
        ),
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 104),
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
          Flexible(
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
                    height: 1.3,
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

class _BookingAccountCard extends StatelessWidget {
  const _BookingAccountCard({
    required this.account,
  });

  final BookingAccountSummary account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final email = account.email.trim();
    final phone = account.phoneNumber.trim();
    final hasPhoto = (account.photoUrl ?? '').trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.surfaceSoft,
            Color.lerp(colors.surfaceSoft, colors.surface, 0.45) ?? colors.surfaceSoft,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.surface,
            backgroundImage: hasPhoto
                ? NetworkImage(account.photoUrl!.trim())
                : null,
            child: !hasPhoto
                ? Text(
                    account.displayName.isEmpty
                        ? '?'
                        : account.displayName.trim().substring(0, 1).toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (email.isNotEmpty || phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (email.isNotEmpty)
                        _BookingContactChip(
                          icon: Icons.mail_outline_rounded,
                          text: email,
                        ),
                      if (phone.isNotEmpty)
                        _BookingContactChip(
                          icon: Icons.call_outlined,
                          text: phone,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingContactChip extends StatelessWidget {
  const _BookingContactChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStatusActionButton extends StatelessWidget {
  const _AdminStatusActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
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
    final primaryLocation = booking.fulfillmentMethod == 'delivery'
        ? (booking.deliveryAddress ?? 'Customer address')
        : booking.pickupHub;

    return _BookingDetailCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _BookingInlineFact(
                icon: booking.fulfillmentMethod == 'delivery'
                    ? Icons.local_shipping_outlined
                    : Icons.storefront_outlined,
                label: booking.fulfillmentMethod == 'delivery' ? 'Delivery' : 'Pickup',
                value: primaryLocation,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BookingInlineFact(
                icon: Icons.assignment_rounded,
                label: 'Status',
                value: booking.status.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _BookingDetailRow(
          icon: Icons.schedule_rounded,
          label: 'Schedule',
          value:
              '${_formatBookingDate(booking.startDate)}\n${_formatBookingTime(booking.startDate)} | ${booking.quantity} ${booking.unit.label.toLowerCase()} rental',
        ),
        const SizedBox(height: 12),
        _BookingDetailRow(
          icon: Icons.flag_outlined,
          label: 'Return',
          value:
              '${_formatBookingDate(booking.endDate)}\n${_formatBookingTime(booking.endDate)}',
        ),
        const SizedBox(height: 12),
        _BookingDetailRow(
          icon: Icons.receipt_long_outlined,
          label: 'Reference',
          value: booking.id,
          maxLines: 1,
        ),
        if ((booking.deliveryNotes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _BookingDetailRow(
            icon: Icons.notes_rounded,
            label: 'Notes',
            value: booking.deliveryNotes!.trim(),
            maxLines: 4,
          ),
        ],
      ],
    );
  }
}

class _BookingInlineFact extends StatelessWidget {
  const _BookingInlineFact({
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: colors.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _BookingDetailCard extends StatelessWidget {
  const _BookingDetailCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _BookingDetailRow extends StatelessWidget {
  const _BookingDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  final IconData icon;
  final String label;
  final String value;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final displayValue = value.replaceAll('\n', ' | ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: colors.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayValue,
                maxLines: maxLines,
                overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingHighlightCard extends StatelessWidget {
  const _BookingHighlightCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.brandDeep, colors.brandMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
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

class _BookingMetaLine extends StatelessWidget {
  const _BookingMetaLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final selectedForeground = theme.brightness == Brightness.light
        ? colors.brandDeep
        : colors.brand;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.brandTintStrong : colors.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.brand : colors.border,
          ),
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

class _BookingStatusChip extends StatelessWidget {
  const _BookingStatusChip({
    required this.status,
  });

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final (background, foreground) = _colorsFor(status, colors, theme.brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (Color, Color) _colorsFor(
    BookingStatus status,
    AppPalette colors,
    Brightness brightness,
  ) {
    switch (status) {
      case BookingStatus.pending:
        return (colors.surfaceSoft, colors.textPrimary);
      case BookingStatus.confirmed:
        return (const Color(0xFFD8ECFF), const Color(0xFF0F4C81));
      case BookingStatus.completed:
        return brightness == Brightness.dark
            ? (const Color(0xFFDFF6E8), const Color(0xFF145235))
            : (const Color(0xFFE6F6ED), const Color(0xFF155B3C));
      case BookingStatus.cancelled:
        return (colors.errorSoft, colors.errorText);
    }
  }
}

class _BookingTimelineCard extends StatelessWidget {
  const _BookingTimelineCard({
    required this.booking,
  });

  final BookingRecord booking;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final steps = [
      (BookingStatus.pending, 'Requested'),
      (BookingStatus.confirmed, 'Ongoing'),
      (BookingStatus.completed, 'Returned'),
    ];
    final activeIndex = switch (booking.status) {
      BookingStatus.pending => 0,
      BookingStatus.confirmed => 1,
      BookingStatus.completed => 2,
      BookingStatus.cancelled => 0,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: booking.status == BookingStatus.cancelled ? colors.errorSoft : colors.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: booking.status == BookingStatus.cancelled
              ? colors.errorText.withValues(alpha: 0.16)
              : colors.borderSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booking.status == BookingStatus.cancelled ? 'Booking ended' : 'Trip timeline',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (booking.status == BookingStatus.cancelled)
            Text(
              'This booking was cancelled before completion.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.errorText,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Row(
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  Expanded(
                    child: _BookingTimelineStep(
                      label: steps[index].$2,
                      active: index <= activeIndex,
                      current: index == activeIndex,
                    ),
                  ),
                  if (index != steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: index < activeIndex ? colors.brandDeep : colors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _BookingTimelineStep extends StatelessWidget {
  const _BookingTimelineStep({
    required this.label,
    required this.active,
    required this.current,
  });

  final String label;
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: active ? colors.brandDeep : colors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: active ? colors.brandDeep : colors.border),
          ),
          child: Icon(
            current ? Icons.radio_button_checked_rounded : Icons.check_rounded,
            size: 16,
            color: active ? Colors.white : colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: active ? colors.textPrimary : colors.textSecondary,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BookingReminderCard extends StatelessWidget {
  const _BookingReminderCard({
    required this.booking,
  });

  final BookingRecord booking;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final message = switch (booking.status) {
      BookingStatus.pending => 'We are waiting for admin approval before your vehicle is released.',
      BookingStatus.confirmed => 'You are currently using this vehicle. Once it is returned, admin will mark it complete.',
      BookingStatus.completed => 'This rental is finished and saved in your booking history.',
      BookingStatus.cancelled => 'This rental was cancelled and is no longer active.',
    };
    final reminderIconBackground = switch (booking.status) {
      BookingStatus.pending => isDarkMode ? const Color(0xFF233126) : colors.brandTintStrong,
      BookingStatus.confirmed => isDarkMode ? const Color(0xFF223043) : const Color(0xFFE3F0FF),
      BookingStatus.completed => isDarkMode ? const Color(0xFF1F372A) : const Color(0xFFE6F6ED),
      BookingStatus.cancelled => isDarkMode ? const Color(0xFF382423) : colors.errorSoft,
    };
    final reminderIconColor = switch (booking.status) {
      BookingStatus.pending => isDarkMode ? const Color(0xFF93D7B8) : colors.brandDeep,
      BookingStatus.confirmed => const Color(0xFF0F4C81),
      BookingStatus.completed => const Color(0xFF155B3C),
      BookingStatus.cancelled => colors.errorText,
    };
    final reminderIcon = switch (booking.status) {
      BookingStatus.pending => Icons.hourglass_top_rounded,
      BookingStatus.confirmed => Icons.electric_car_rounded,
      BookingStatus.completed => Icons.check_circle_rounded,
      BookingStatus.cancelled => Icons.cancel_rounded,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.surface, colors.surfaceSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: reminderIconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(reminderIcon, color: reminderIconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What happens next',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
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

String _formatBookingDate(DateTime value) {
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

String _formatBookingTime(DateTime value) {
  final hour24 = value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:$minute $period';
}

String _favoriteVehicleTypeLabel(List<BookingRecord> bookings) {
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

String _favoritePickupHub(List<BookingRecord> bookings) {
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

String _formatBookingPrice(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

class _FeaturedVehicleCard extends StatelessWidget {
  const _FeaturedVehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.actionLabel,
    this.swipeProgress = 0,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final String actionLabel;
  final double swipeProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final clampedProgress = swipeProgress.clamp(-1.0, 1.0);
    final imageShift = clampedProgress * 24;
    final contentShift = clampedProgress * -12;
    final imageTilt = clampedProgress * 0.06;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: colors.surfaceSoft,
            border: Border.all(color: colors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 22 + (clampedProgress.abs() * 10),
                offset: Offset(clampedProgress * -4, 14 + (clampedProgress.abs() * 6)),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 28,
                right: 28,
                bottom: 18,
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.28),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Transform.translate(
                  offset: Offset(imageShift, 0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0013)
                      ..rotateX(0.07)
                      ..rotateY(-0.06 + imageTilt),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _VehiclePreviewImage(
                          vehicle: vehicle,
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 28,
                          fit: BoxFit.cover,
                          fallbackToArtwork: true,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1.2,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.22),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.20),
                              ],
                              stops: const [0, 0.34, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18 - (clampedProgress * 8),
                          top: 14,
                          child: Container(
                            width: 118,
                            height: 22,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.30),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.03),
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.52),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18 - contentShift,
                right: 18 + contentShift,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        vehicle.type.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      vehicle.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicle.location} | \$${vehicle.rateFor(RentalUnit.day).price.toStringAsFixed(0)} / day',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.brandDeep,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          actionLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
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

class _ProfilePrimaryActionCard extends StatelessWidget {
  const _ProfilePrimaryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final decorativeSurface = theme.brightness == Brightness.light
        ? colors.surfaceSoft
        : colors.brandTintStrong;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.surface, colors.surfaceSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: decorativeSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colors.brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyCustomerProfileCard extends StatelessWidget {
  const _ReadOnlyCustomerProfileCard({
    required this.profile,
    required this.onTap,
  });

  final UserProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final decorativeSurface = theme.brightness == Brightness.light
        ? colors.surfaceSoft
        : colors.brandTintStrong;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              ProfileAvatar(
                imageUrl: profile.photoUrl,
                initials: profile.initials,
                radius: 24,
                backgroundColor: decorativeSurface,
                textColor: colors.brandDeep,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName.isEmpty ? 'Unnamed customer' : profile.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.email.isEmpty ? 'No email saved' : profile.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ProfileTopPill(
                          icon: Icons.phone_iphone_rounded,
                          label: profile.phoneNumber.isEmpty ? 'No phone' : profile.phoneNumber,
                        ),
                        _ProfileTopPill(
                          icon: profile.profileComplete
                              ? Icons.verified_rounded
                              : Icons.pending_actions_rounded,
                          label: profile.profileComplete ? 'Complete' : 'Incomplete',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerBookingSummaryCard extends StatelessWidget {
  const _CustomerBookingSummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: colors.brandTintStrong,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: colors.brand),
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
                  style: theme.textTheme.titleMedium?.copyWith(
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

class _ProfileTopPill extends StatelessWidget {
  const _ProfileTopPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final valueColor = theme.brightness == Brightness.light
        ? colors.textPrimary
        : colors.textPrimary;
    final decorativeIconColor = theme.brightness == Brightness.light
        ? colors.brandDeep
        : colors.brand;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: colors.brandTintStrong,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: decorativeIconColor),
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
              const SizedBox(height: 3),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchSuggestionPanel extends StatelessWidget {
  const _SearchSuggestionPanel({
    required this.vehicles,
    required this.onSelect,
  });

  final List<Vehicle> vehicles;
  final ValueChanged<Vehicle> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    if (vehicles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded, color: colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No matching vehicles for this search.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < vehicles.length; index++) ...[
            _SearchSuggestionTile(
              vehicle: vehicles[index],
              onTap: () => onSelect(vehicles[index]),
            ),
            if (index != vehicles.length - 1)
              Divider(
                height: 1,
                color: colors.divider,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _SearchSuggestionTile extends StatelessWidget {
  const _SearchSuggestionTile({
    required this.vehicle,
    required this.onTap,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final hasImage = vehicle.imageUrl.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: hasImage
                  ? _VehiclePreviewImage(
                      vehicle: vehicle,
                      width: 56,
                      height: 56,
                      borderRadius: 14,
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: colors.brandTintStrong,
                      child: Icon(
                        vehicle.type.icon,
                        color: colors.brand,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vehicle.location,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${vehicle.rateFor(RentalUnit.day).price.toStringAsFixed(0)} / day',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.north_west_rounded,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

