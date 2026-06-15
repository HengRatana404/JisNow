import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/rental_models.dart';

class HubMapLocation {
  const HubMapLocation({
    required this.name,
    required this.position,
  });

  final String name;
  final LatLng position;
}

class DeliveryMapSelection {
  const DeliveryMapSelection({
    required this.address,
    required this.position,
  });

  final String address;
  final LatLng position;
}

const LatLng _phnomPenhCenter = LatLng(11.5564, 104.9282);

const Map<String, LatLng> _knownHubCoordinates = {
  'Wat Phnom': LatLng(11.5763, 104.9288),
  'BKK1 Phnom Penh': LatLng(11.5489, 104.9214),
  'Riverside Phnom Penh': LatLng(11.5681, 104.9286),
  'Phnom Penh Airport': LatLng(11.5466, 104.8441),
  'Tuol Kork Hub': LatLng(11.5735, 104.8880),
};

const String _pickupHubConfigCollection = 'app_config';
const String _pickupHubConfigDocId = 'pickup_hub_positions';

LatLng pickupHubPosition(String hub) {
  return _knownHubCoordinates[hub.trim()] ?? _phnomPenhCenter;
}

List<HubMapLocation> pickupHubLocationsForVehicle(Vehicle vehicle) {
  return vehicle.pickupHubs
      .map(
        (hub) => HubMapLocation(
          name: hub,
          position: pickupHubPosition(hub),
        ),
      )
      .toList();
}

Future<Map<String, LatLng>> loadPickupHubPositionOverrides({
  FirebaseFirestore? firestore,
}) async {
  try {
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection(_pickupHubConfigCollection)
        .doc(_pickupHubConfigDocId)
        .get();
    final data = snapshot.data();
    final rawMap = data?['pickupHubPositions'];
    if (rawMap is! Map) {
      return const {};
    }
    final overrides = <String, LatLng>{};
    for (final entry in rawMap.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value;
      if (key.isEmpty || value is! Map) {
        continue;
      }
      final lat = (value['lat'] as num?)?.toDouble();
      final lng = (value['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        continue;
      }
      overrides[key] = LatLng(lat, lng);
    }
    return overrides;
  } catch (_) {
    return const {};
  }
}

Future<List<HubMapLocation>> loadPickupHubLocationsForVehicle(
  Vehicle vehicle, {
  FirebaseFirestore? firestore,
}) async {
  final overrides = await loadPickupHubPositionOverrides(firestore: firestore);
  return vehicle.pickupHubs
      .map(
        (hub) => HubMapLocation(
          name: hub,
          position: overrides[hub.trim()] ?? pickupHubPosition(hub),
        ),
      )
      .toList();
}

Future<LatLng> loadPickupHubPosition(
  String hub, {
  FirebaseFirestore? firestore,
}) async {
  final overrides = await loadPickupHubPositionOverrides(firestore: firestore);
  return overrides[hub.trim()] ?? pickupHubPosition(hub);
}

Future<void> saveSharedPickupHubPosition(
  String hub,
  LatLng position, {
  FirebaseFirestore? firestore,
}) {
  final normalizedHub = hub.trim();
  return (firestore ?? FirebaseFirestore.instance)
      .collection(_pickupHubConfigCollection)
      .doc(_pickupHubConfigDocId)
      .set({
        'pickupHubPositions': {
          normalizedHub: {
            'lat': position.latitude,
            'lng': position.longitude,
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}

Future<String> reverseGeocodeAddress(LatLng position) async {
  try {
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isEmpty) {
      return _fallbackCoordinateLabel(position);
    }
    final place = placemarks.first;
    final parts = <String>[
      if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
      if ((place.subLocality ?? '').trim().isNotEmpty) place.subLocality!.trim(),
      if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
      if ((place.country ?? '').trim().isNotEmpty) place.country!.trim(),
    ];
    if (parts.isEmpty) {
      return _fallbackCoordinateLabel(position);
    }
    return parts.join(', ');
  } catch (_) {
    return _fallbackCoordinateLabel(position);
  }
}

Future<DeliveryMapSelection?> searchAddressSelection(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    final locations = await locationFromAddress(trimmed);
    if (locations.isEmpty) {
      return null;
    }
    final match = locations.first;
    final position = LatLng(match.latitude, match.longitude);
    final address = await reverseGeocodeAddress(position);
    return DeliveryMapSelection(
      address: address,
      position: position,
    );
  } catch (_) {
    return null;
  }
}

String _fallbackCoordinateLabel(LatLng position) {
  return 'Pinned location (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
}
