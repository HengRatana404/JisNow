import 'package:flutter/material.dart';

import '../models/rental_models.dart';
import '../services/auth_repository.dart';
import '../services/booking_repository.dart';
import '../services/map_support.dart';
import '../services/notification_repository.dart';
import '../services/profile_repository.dart';
import '../theme/app_palette.dart';
import '../widgets/rental_widgets.dart';
import 'map_picker_screen.dart';
import 'rental_app.dart';

enum FulfillmentMethod { pickup, delivery }

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.vehicle,
    required this.bookingRepository,
    required this.notificationRepository,
    required this.authUser,
    required this.userProfile,
  });

  final Vehicle vehicle;
  final BookingRepository bookingRepository;
  final NotificationRepository notificationRepository;
  final AuthUser authUser;
  final UserProfile userProfile;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  RentalUnit selectedUnit = RentalUnit.day;
  int quantity = 1;
  DateTime startDate = DateTime.now().add(const Duration(hours: 1));
  FulfillmentMethod fulfillmentMethod = FulfillmentMethod.pickup;
  late String selectedPickupHub;
  final TextEditingController _deliveryAddressController = TextEditingController();
  final TextEditingController _deliveryNotesController = TextEditingController();
  DeliveryMapSelection? _deliveryMapSelection;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    selectedPickupHub = widget.vehicle.primaryPickupHub;
  }

  BookingQuote get quote => BookingQuote(
        vehicle: widget.vehicle,
        unit: selectedUnit,
        quantity: quantity,
        startDate: startDate,
      );

  double get deliveryFee {
    if (fulfillmentMethod == FulfillmentMethod.pickup) {
      return 0;
    }
    switch (widget.vehicle.type) {
      case VehicleType.car:
        return 3;
      case VehicleType.motorbike:
        return 1.5;
      case VehicleType.bicycle:
        return 1;
    }
  }

  double get bookingTotal => quote.totalPrice + deliveryFee;

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    _deliveryNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final currentRate = widget.vehicle.rateFor(selectedUnit).price;
    final pickupHubs = widget.vehicle.pickupHubs;
    final pickupSubtitle = pickupHubs.length > 1
        ? '${pickupHubs.length} pickup hubs available'
        : widget.vehicle.primaryPickupHub;

    if (widget.userProfile.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Booking'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 52,
                  color: colors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Admin booking is disabled',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Admin accounts can review customer bookings and manage vehicles, but cannot create bookings themselves.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Back to admin'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking'),
        actions: [
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
        child: StreamBuilder<List<BookingRecord>>(
          stream: widget.bookingRepository.watchAllBookings(),
          builder: (context, snapshot) {
            final allBookings = snapshot.data ?? const <BookingRecord>[];
            final remainingUnits = remainingVehicleAvailability(
              vehicle: widget.vehicle,
              bookings: allBookings,
              requestedStart: startDate,
              requestedEnd: quote.endDate,
            );
            final isSoldOutForSelection = remainingUnits <= 0;

            return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            VehicleCard(
              vehicle: widget.vehicle,
              selectedUnit: selectedUnit,
              isSelected: false,
              onTap: () {},
            ),
            const SizedBox(height: 18),
            AppInlineNotice(
              icon: Icons.event_available_rounded,
              title: 'Reservation preview',
              message:
                  '${_formatDate(startDate)} at ${_formatTime(startDate)} to ${_formatDate(quote.endDate)} at ${_formatTime(quote.endDate)} for $quantity ${selectedUnit.pluralize(quantity)}.',
              tone: AppBannerTone.info,
            ),
            if (isSoldOutForSelection) ...[
              const SizedBox(height: 14),
              const AppInlineNotice(
                icon: Icons.schedule_outlined,
                title: 'That time is fully booked',
                message:
                    'Adjust the start date, time, or duration to find the next available slot.',
                tone: AppBannerTone.warning,
              ),
            ],
            const SizedBox(height: 18),
            _BookingSection(
              title: 'Rental plan',
              subtitle: 'Choose how long you want this vehicle and when the trip should start.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: RentalUnit.values
                        .map(
                          (unit) => ChoiceChip(
                            label: Text(unit.label),
                            selected: selectedUnit == unit,
                            onSelected: (_) => setState(() => selectedUnit = unit),
                            selectedColor: colors.brandTint,
                            backgroundColor: colors.surfaceSoft,
                            showCheckmark: false,
                            labelStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: selectedUnit == unit ? colors.textPrimary : colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide(
                              color: selectedUnit == unit ? colors.brand : colors.border,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: colors.borderSoft),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Duration',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$quantity ${selectedUnit.pluralize(quantity)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StepperButton(
                          icon: Icons.remove_rounded,
                          onTap: quantity > 1 ? () => setState(() => quantity--) : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            quantity.toString(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StepperButton(
                          icon: Icons.add_rounded,
                          onTap: () => setState(() => quantity++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 520;
                      if (stacked) {
                        return _CompactSchedulePanel(
                          dateValue: _formatDate(startDate),
                          timeValue: _formatTime(startDate),
                          onPickDate: _pickStartDate,
                          onPickTime: _pickStartTime,
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: _ScheduleCard(
                              icon: Icons.calendar_today_rounded,
                              title: 'Start date',
                              value: _formatDate(startDate),
                              actionLabel: 'Change',
                              onTap: _pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ScheduleCard(
                              icon: Icons.schedule_rounded,
                              title: 'Pickup time',
                              value: _formatTime(startDate),
                              actionLabel: 'Adjust',
                              onTap: _pickStartTime,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _BookingSection(
              title: 'Pickup or delivery',
              subtitle: 'Choose whether you want to collect the vehicle yourself or have it delivered.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 520;
                      if (stacked) {
                        return _CompactFulfillmentSelector(
                          fulfillmentMethod: fulfillmentMethod,
                          pickupSubtitle: pickupSubtitle,
                          onSelect: (method) {
                            setState(() => fulfillmentMethod = method);
                          },
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: _FulfillmentOptionCard(
                              icon: Icons.storefront_rounded,
                              title: 'Pickup at hub',
                              subtitle: pickupSubtitle,
                              badge: null,
                              isSelected: fulfillmentMethod == FulfillmentMethod.pickup,
                              onTap: () => setState(() => fulfillmentMethod = FulfillmentMethod.pickup),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FulfillmentOptionCard(
                              icon: Icons.local_shipping_rounded,
                              title: 'Deliver to me',
                              subtitle: 'We bring it to your address',
                              badge: null,
                              isSelected: fulfillmentMethod == FulfillmentMethod.delivery,
                              onTap: () => setState(() => fulfillmentMethod = FulfillmentMethod.delivery),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: fulfillmentMethod == FulfillmentMethod.delivery
                          ? colors.brandTint
                          : colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: fulfillmentMethod == FulfillmentMethod.delivery
                            ? colors.brandSoft
                            : colors.borderSoft,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: fulfillmentMethod == FulfillmentMethod.delivery
                                    ? colors.brand
                                    : colors.brandTintStrong,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                fulfillmentMethod == FulfillmentMethod.delivery
                                    ? Icons.pin_drop_rounded
                                    : Icons.location_city_rounded,
                                color: fulfillmentMethod == FulfillmentMethod.delivery
                                    ? Colors.white
                                    : colors.brand,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fulfillmentMethod == FulfillmentMethod.pickup
                                        ? 'Pickup hub'
                                        : 'Delivery details',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    fulfillmentMethod == FulfillmentMethod.pickup
                                        ? 'Go to the selected hub at your chosen pickup time.'
                                        : 'Enter the address where our team should deliver the vehicle.',
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
                        if (fulfillmentMethod == FulfillmentMethod.pickup)
                          pickupHubs.length <= 1
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: colors.borderSoft),
                                      ),
                                      child: Text(
                                        selectedPickupHub,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: pickupHubs.isEmpty
                                            ? null
                                            : _openPickupHubMap,
                                        icon: const Icon(Icons.map_outlined),
                                        label: const Text('View pickup hub on map'),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedPickupHub,
                                      decoration: const InputDecoration(
                                        labelText: 'Pickup hub',
                                        prefixIcon: Icon(Icons.place_outlined),
                                      ),
                                      items: pickupHubs
                                          .map(
                                            (hub) => DropdownMenuItem<String>(
                                              value: hub,
                                              child: Text(hub),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() => selectedPickupHub = value);
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: pickupHubs.isEmpty
                                            ? null
                                            : _openPickupHubMap,
                                        icon: const Icon(Icons.map_outlined),
                                        label: const Text('Choose pickup hub on map'),
                                      ),
                                    ),
                                  ],
                                ),
                        if (fulfillmentMethod == FulfillmentMethod.delivery) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openDeliveryMapPicker,
                              icon: const Icon(Icons.pin_drop_outlined),
                              label: const Text('Pick delivery address on map'),
                            ),
                          ),
                          if (_deliveryMapSelection != null) ...[
                            const SizedBox(height: 12),
                            AppInlineNotice(
                              icon: Icons.check_circle_outline_rounded,
                              title: 'Map location selected',
                              message: _deliveryMapSelection!.address,
                              tone: AppBannerTone.success,
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: _deliveryAddressController,
                            minLines: 2,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Delivery address',
                              hintText: 'Street, building, area, and nearby landmark',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _deliveryNotesController,
                            minLines: 2,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Driver notes',
                              hintText: 'Gate code, parking note, or preferred contact detail',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Delivery fee: \$${_formatPrice(deliveryFee)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppInlineNotice(
              icon: fulfillmentMethod == FulfillmentMethod.pickup
                  ? Icons.storefront_rounded
                  : Icons.local_shipping_rounded,
              title: 'What happens next',
              message: fulfillmentMethod == FulfillmentMethod.pickup
                  ? 'After you confirm, admin will review the booking and you can collect the vehicle from $selectedPickupHub at the scheduled time.'
                  : 'After you confirm, admin will review the booking, contact you if needed, and deliver the vehicle to your saved address.',
              tone: AppBannerTone.info,
            ),
            const SizedBox(height: 18),
            _BookingSection(
              title: 'Price summary',
              subtitle: 'Review everything once before you confirm the reservation.',
              child: Column(
                children: [
                  _SummaryGroup(
                    rows: [
                      _SummaryItem(
                        label: 'Rate',
                        value:
                            '\$${currentRate.toStringAsFixed(0)} / ${selectedUnit.label.toLowerCase()}',
                      ),
                      _SummaryItem(
                        label: 'Rental period',
                        value: '$quantity ${selectedUnit.pluralize(quantity)}',
                      ),
                      _SummaryItem(
                        label: 'Fulfillment',
                        value: fulfillmentMethod == FulfillmentMethod.pickup
                            ? 'Pickup'
                            : 'Delivery',
                      ),
                      _SummaryItem(
                        label: fulfillmentMethod == FulfillmentMethod.pickup
                            ? 'Pickup hub'
                            : 'Delivery area',
                        value: fulfillmentMethod == FulfillmentMethod.pickup
                            ? selectedPickupHub
                            : 'Customer address',
                      ),
                      if (fulfillmentMethod == FulfillmentMethod.delivery)
                        _SummaryItem(
                          label: 'Delivery fee',
                          value: '\$${_formatPrice(deliveryFee)}',
                        ),
                      _SummaryItem(
                        label: 'Pickup',
                        value: '${_formatDate(startDate)} | ${_formatTime(startDate)}',
                      ),
                      _SummaryItem(
                        label: 'Return',
                        value: '${_formatDate(quote.endDate)} | ${_formatTime(quote.endDate)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.borderSoft),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated total',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${_formatPrice(bookingTotal)}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fulfillmentMethod == FulfillmentMethod.pickup
                                    ? 'Pickup hub: $selectedPickupHub'
                                    : 'Delivery to your address',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: _isSubmitting || isSoldOutForSelection
                              ? null
                              : () => _confirmBooking(context, quote),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.brand,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isSoldOutForSelection ? 'Unavailable' : 'Confirm',
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: startDate,
    );

    if (picked != null) {
      setState(() {
        startDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          startDate.hour,
          startDate.minute,
        );
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startDate),
    );

    if (picked != null) {
      setState(() {
        startDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _confirmBooking(BuildContext context, BookingQuote quote) async {
    if (widget.userProfile.isAdmin) {
      showAppBanner(
        context,
        message: 'Admin accounts cannot create bookings.',
        tone: AppBannerTone.info,
      );
      return;
    }

    if (fulfillmentMethod == FulfillmentMethod.delivery &&
        _deliveryAddressController.text.trim().isEmpty) {
      showAppBanner(
        context,
        message: 'Enter a delivery address before confirming.',
        tone: AppBannerTone.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.bookingRepository.createBooking(
        authUser: widget.authUser,
        userProfile: widget.userProfile,
        draft: BookingDraft(
          vehicle: quote.vehicle,
          unit: quote.unit,
          quantity: quote.quantity,
          startDate: quote.startDate,
          endDate: quote.endDate,
          fulfillmentMethod: fulfillmentMethod.name,
          pickupHub: selectedPickupHub,
          deliveryAddress: fulfillmentMethod == FulfillmentMethod.delivery
              ? _deliveryAddressController.text.trim()
              : null,
          deliveryNotes: fulfillmentMethod == FulfillmentMethod.delivery
              ? _deliveryNotesController.text.trim()
              : null,
          deliveryFee: deliveryFee,
          totalPrice: bookingTotal,
        ),
      );
      if (!mounted) {
        return;
      }
      await _showBookingSheet(this.context, quote);
    } on BookingConflictException catch (error) {
      if (!mounted) {
        return;
      }
      showAppBanner(
        this.context,
        message: error.message,
        tone: AppBannerTone.warning,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppBanner(
        this.context,
        message: 'Could not save booking. Please try again.',
        tone: AppBannerTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openPickupHubMap() async {
    final locations = await loadPickupHubLocationsForVehicle(widget.vehicle);
    if (!mounted || locations.isEmpty) {
      return;
    }
    final selectedHub = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => PickupHubMapScreen(
          hubs: locations,
          selectedHub: selectedPickupHub,
        ),
      ),
    );
    if (!mounted || selectedHub == null || selectedHub.isEmpty) {
      return;
    }
    setState(() => selectedPickupHub = selectedHub);
  }

  Future<void> _openDeliveryMapPicker() async {
    final initialPosition = _deliveryMapSelection?.position ??
        await loadPickupHubPosition(selectedPickupHub);
    if (!mounted) {
      return;
    }
    final selection = await Navigator.of(context).push<DeliveryMapSelection>(
      MaterialPageRoute<DeliveryMapSelection>(
        builder: (_) => DeliveryMapPickerScreen(
          initialPosition: initialPosition,
          initialAddress: _deliveryAddressController.text.trim().isEmpty
              ? _deliveryMapSelection?.address
              : _deliveryAddressController.text.trim(),
        ),
      ),
    );
    if (!mounted || selection == null) {
      return;
    }
    setState(() {
      _deliveryMapSelection = selection;
      _deliveryAddressController.text = selection.address;
    });
  }

  Future<void> _showBookingSheet(BuildContext context, BookingQuote quote) async {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final successIconBackground = isDarkMode
        ? const Color(0xFF183529)
        : colors.brandTintStrong;
    final successIconColor = isDarkMode
        ? const Color(0xFF7EE0B3)
        : colors.brandDeep;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
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
                const SizedBox(height: 20),
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: successIconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: successIconColor,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Booking request sent',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your ${quote.vehicle.name} request is waiting for admin approval. Once approved, the booking will show as ongoing until the vehicle is returned and marked complete.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                _SummaryRow(label: 'Vehicle', value: quote.vehicle.name),
                const SizedBox(height: 10),
                _SummaryRow(
                  label: fulfillmentMethod == FulfillmentMethod.pickup
                      ? 'Pickup hub'
                      : 'Delivery address',
                  value: fulfillmentMethod == FulfillmentMethod.pickup
                      ? selectedPickupHub
                      : _deliveryAddressController.text.trim(),
                ),
                if (fulfillmentMethod == FulfillmentMethod.delivery) ...[
                  const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'Delivery fee',
                      value: '\$${_formatPrice(deliveryFee)}',
                    ),
                  ],
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'Total',
                    value: '\$${_formatPrice(bookingTotal)}',
                    emphasize: true,
                  ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(this.context).pop();
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime value) {
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

  String _formatTime(DateTime value) {
    final hour24 = value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minute $period';
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _BookingSection extends StatelessWidget {
  const _BookingSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
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
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.brand, size: 20),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onTap,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _CompactSchedulePanel extends StatelessWidget {
  const _CompactSchedulePanel({
    required this.dateValue,
    required this.timeValue,
    required this.onPickDate,
    required this.onPickTime,
  });

  final String dateValue;
  final String timeValue;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        children: [
          _CompactScheduleRow(
            icon: Icons.calendar_today_rounded,
            title: 'Start date',
            value: dateValue,
            actionLabel: 'Change',
            onTap: onPickDate,
          ),
          Divider(
            height: 24,
            color: colors.divider,
          ),
          _CompactScheduleRow(
            icon: Icons.schedule_rounded,
            title: 'Pickup time',
            value: timeValue,
            actionLabel: 'Adjust',
            onTap: onPickTime,
          ),
        ],
      ),
    );
  }
}

class _CompactScheduleRow extends StatelessWidget {
  const _CompactScheduleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: colors.brandTintStrong,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.brand, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
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
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _FulfillmentOptionCard extends StatelessWidget {
  const _FulfillmentOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
          color: isSelected ? colors.brandTint : colors.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? colors.brand : colors.borderSoft,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: isSelected ? colors.brand : colors.surface,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : colors.brand,
                    size: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  child: badge == null
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.brand : colors.surface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isSelected ? Colors.white : colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactFulfillmentSelector extends StatelessWidget {
  const _CompactFulfillmentSelector({
    required this.fulfillmentMethod,
    required this.pickupSubtitle,
    required this.onSelect,
  });

  final FulfillmentMethod fulfillmentMethod;
  final String pickupSubtitle;
  final ValueChanged<FulfillmentMethod> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        children: [
          _CompactFulfillmentRow(
            icon: Icons.storefront_rounded,
            title: 'Pickup at hub',
            subtitle: pickupSubtitle,
            selected: fulfillmentMethod == FulfillmentMethod.pickup,
            onTap: () => onSelect(FulfillmentMethod.pickup),
          ),
          Divider(
            height: 1,
            color: colors.divider,
            indent: 16,
            endIndent: 16,
          ),
          _CompactFulfillmentRow(
            icon: Icons.local_shipping_rounded,
            title: 'Deliver to me',
            subtitle: 'We bring it to your address',
            selected: fulfillmentMethod == FulfillmentMethod.delivery,
            onTap: () => onSelect(FulfillmentMethod.delivery),
          ),
        ],
      ),
    );
  }
}

class _CompactFulfillmentRow extends StatelessWidget {
  const _CompactFulfillmentRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: selected ? colors.brand : colors.brandTintStrong,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : colors.brand,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: selected ? colors.brand : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.brand : colors.border,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: onTap == null ? colors.surfacePill : colors.brandTint,
          borderRadius: BorderRadius.circular(14),
          border: onTap == null ? null : Border.all(color: colors.borderSoft),
        ),
        child: Icon(
          icon,
          color: onTap == null ? colors.textSecondary : colors.brand,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final isLightMode = theme.brightness == Brightness.light;
    final emphasisTextColor = isLightMode ? colors.textPrimary : colors.brand;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useStackedLayout = constraints.maxWidth < 280;

        if (useStackedLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (emphasize ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
                      ?.copyWith(
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                    color: emphasize ? emphasisTextColor : colors.textPrimary,
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (emphasize ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
                    ?.copyWith(
                  fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                  color: emphasize ? emphasisTextColor : colors.textPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _SummaryGroup extends StatelessWidget {
  const _SummaryGroup({
    required this.rows,
  });

  final List<_SummaryItem> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          _SummaryRow(
            label: rows[index].label,
            value: rows[index].value,
          ),
          if (index != rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
