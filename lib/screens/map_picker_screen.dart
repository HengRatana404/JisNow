import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/map_support.dart';
import '../theme/app_palette.dart';

class PickupHubMapScreen extends StatefulWidget {
  const PickupHubMapScreen({
    super.key,
    required this.hubs,
    required this.selectedHub,
  });

  final List<HubMapLocation> hubs;
  final String selectedHub;

  @override
  State<PickupHubMapScreen> createState() => _PickupHubMapScreenState();
}

class _PickupHubMapScreenState extends State<PickupHubMapScreen> {
  late String _selectedHub;
  GoogleMapController? _mapController;

  Future<void> _searchHub() async {
    final query = await _showMapSearchPrompt(
      context,
      title: 'Find pickup hub',
      hintText: 'Search hub name',
      initialValue: _selectedHub,
    );
    if (!mounted || query == null) {
      return;
    }
    final match = widget.hubs.where((hub) {
      final normalizedHub = hub.name.toLowerCase();
      final normalizedQuery = query.trim().toLowerCase();
      return normalizedHub.contains(normalizedQuery);
    }).toList();
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pickup hub matched that search.')),
      );
      return;
    }
    final hub = match.first;
    setState(() => _selectedHub = hub.name);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(hub.position, 14),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedHub = widget.selectedHub;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final selectedLocation = widget.hubs.firstWhere(
      (hub) => hub.name == _selectedHub,
      orElse: () => widget.hubs.first,
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Pickup hubs'),
        actions: [
          IconButton(
            onPressed: _searchHub,
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Find hub',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: selectedLocation.position,
              zoom: 13.2,
            ),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: {
              for (final hub in widget.hubs)
                Marker(
                  markerId: MarkerId(hub.name),
                  position: hub.position,
                  infoWindow: InfoWindow(title: hub.name),
                  onTap: () {
                    setState(() => _selectedHub = hub.name);
                  },
                ),
            },
          ),
          Positioned(
            right: 16,
            bottom: 184,
            child: FloatingActionButton.small(
              heroTag: 'pickup_hub_recenter',
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(selectedLocation.position, 14),
                );
              },
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.borderSoft),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selected hub',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedHub,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a marker to preview another hub, then confirm it below.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(_selectedHub),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Use this pickup hub'),
                    ),
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

class DeliveryMapPickerScreen extends StatefulWidget {
  const DeliveryMapPickerScreen({
    super.key,
    required this.initialPosition,
    this.initialAddress,
  });

  final LatLng initialPosition;
  final String? initialAddress;

  @override
  State<DeliveryMapPickerScreen> createState() => _DeliveryMapPickerScreenState();
}

class _DeliveryMapPickerScreenState extends State<DeliveryMapPickerScreen> {
  late LatLng _selectedPosition;
  String? _selectedAddress;
  bool _resolvingAddress = false;
  bool _locatingUser = false;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
    _selectedAddress = widget.initialAddress;
    if ((_selectedAddress ?? '').trim().isEmpty) {
      _resolveSelectedAddress();
    }
  }

  Future<void> _resolveSelectedAddress() async {
    setState(() => _resolvingAddress = true);
    final address = await reverseGeocodeAddress(_selectedPosition);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedAddress = address;
      _resolvingAddress = false;
    });
  }

  Future<void> _searchPlace() async {
    final query = await _showMapSearchPrompt(
      context,
      title: 'Search place',
      hintText: 'Street, landmark, area',
      initialValue: _selectedAddress,
    );
    if (!mounted || query == null) {
      return;
    }
    setState(() => _resolvingAddress = true);
    final selection = await searchAddressSelection(query);
    if (!mounted) {
      return;
    }
    if (selection == null) {
      setState(() => _resolvingAddress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find that place. Try another search.')),
      );
      return;
    }
    setState(() {
      _selectedPosition = selection.position;
      _selectedAddress = selection.address;
      _resolvingAddress = false;
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(selection.position, 15),
    );
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locatingUser = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is needed to use current location.')),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final target = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedPosition = target;
        _selectedAddress = null;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 15),
      );
      await _resolveSelectedAddress();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location right now.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locatingUser = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Pick delivery location'),
        actions: [
          IconButton(
            onPressed: _searchPlace,
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search place',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 14,
            ),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onTap: (position) {
              setState(() {
                _selectedPosition = position;
                _selectedAddress = null;
              });
              _resolveSelectedAddress();
            },
            markers: {
              Marker(
                markerId: const MarkerId('delivery_pin'),
                position: _selectedPosition,
                draggable: true,
                onDragEnd: (position) {
                  setState(() {
                    _selectedPosition = position;
                    _selectedAddress = null;
                  });
                  _resolveSelectedAddress();
                },
              ),
            },
          ),
          Positioned(
            right: 16,
            bottom: 218,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'delivery_location_me',
                  onPressed: _locatingUser ? null : _goToCurrentLocation,
                  child: _locatingUser
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'delivery_recenter',
                  onPressed: () {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_selectedPosition, 15),
                    );
                  },
                  child: const Icon(Icons.center_focus_strong_rounded),
                ),
              ],
            ),
          ),
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.borderSoft),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: colors.brand, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap the map or drag the pin to set delivery location.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.borderSoft),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selected delivery address',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _resolvingAddress
                        ? 'Finding address...'
                        : (_selectedAddress ?? 'Tap the map to choose a location'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Confirm this pin only after the marker and address look correct.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Lat ${_selectedPosition.latitude.toStringAsFixed(5)} • Lng ${_selectedPosition.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _resolvingAddress
                          ? null
                          : () => Navigator.of(context).pop(
                                DeliveryMapSelection(
                                  address: _selectedAddress ?? '',
                                  position: _selectedPosition,
                                ),
                              ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Use this delivery address'),
                    ),
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

class PickupHubPositionEditorScreen extends StatefulWidget {
  const PickupHubPositionEditorScreen({
    super.key,
    required this.hubName,
    required this.initialPosition,
  });

  final String hubName;
  final LatLng initialPosition;

  @override
  State<PickupHubPositionEditorScreen> createState() =>
      _PickupHubPositionEditorScreenState();
}

class _PickupHubPositionEditorScreenState
    extends State<PickupHubPositionEditorScreen> {
  late LatLng _selectedPosition;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.hubName),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 14,
            ),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onTap: (position) {
              setState(() => _selectedPosition = position);
            },
            markers: {
              Marker(
                markerId: MarkerId(widget.hubName),
                position: _selectedPosition,
                draggable: true,
                infoWindow: InfoWindow(title: widget.hubName),
                onDragEnd: (position) {
                  setState(() => _selectedPosition = position);
                },
              ),
            },
          ),
          Positioned(
            right: 16,
            bottom: 196,
            child: FloatingActionButton.small(
              heroTag: 'hub_editor_recenter',
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_selectedPosition, 15),
                );
              },
              child: const Icon(Icons.center_focus_strong_rounded),
            ),
          ),
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.borderSoft),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_rounded, color: colors.brand, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap the map or drag the pin to update this shared hub position.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.borderSoft),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Shared pickup hub pin',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.hubName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_selectedPosition.latitude.toStringAsFixed(5)}, ${_selectedPosition.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(_selectedPosition),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Use this hub position'),
                    ),
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

Future<String?> _showMapSearchPrompt(
  BuildContext context, {
  required String title,
  required String hintText,
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  final value = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Search'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return value;
}
