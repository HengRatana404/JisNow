import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

enum VehicleType { car, motorbike, bicycle }

enum RentalUnit { hour, day, week, month }

enum BookingStatus { pending, confirmed, completed, cancelled }

enum BookingCancellationSource { customer, admin }

VehicleType vehicleTypeFromKey(String value) {
  switch (value) {
    case 'car':
      return VehicleType.car;
    case 'motorbike':
      return VehicleType.motorbike;
    case 'bicycle':
      return VehicleType.bicycle;
    default:
      return VehicleType.car;
  }
}

RentalUnit rentalUnitFromKey(String value) {
  switch (value) {
    case 'hour':
      return RentalUnit.hour;
    case 'day':
      return RentalUnit.day;
    case 'week':
      return RentalUnit.week;
    case 'month':
      return RentalUnit.month;
    default:
      return RentalUnit.day;
  }
}

BookingStatus bookingStatusFromKey(String value) {
  switch (value) {
    case 'pending':
      return BookingStatus.pending;
    case 'confirmed':
      return BookingStatus.confirmed;
    case 'completed':
      return BookingStatus.completed;
    case 'cancelled':
      return BookingStatus.cancelled;
    default:
      return BookingStatus.pending;
  }
}

extension VehicleTypeX on VehicleType {
  String get key {
    switch (this) {
      case VehicleType.car:
        return 'car';
      case VehicleType.motorbike:
        return 'motorbike';
      case VehicleType.bicycle:
        return 'bicycle';
    }
  }

  String get label {
    switch (this) {
      case VehicleType.car:
        return 'Car';
      case VehicleType.motorbike:
        return 'Moto';
      case VehicleType.bicycle:
        return 'Bicycle';
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleType.car:
        return Icons.directions_car_filled_rounded;
      case VehicleType.motorbike:
        return Icons.two_wheeler_rounded;
      case VehicleType.bicycle:
        return Icons.pedal_bike_rounded;
    }
  }
}

extension RentalUnitX on RentalUnit {
  String get key {
    switch (this) {
      case RentalUnit.hour:
        return 'hour';
      case RentalUnit.day:
        return 'day';
      case RentalUnit.week:
        return 'week';
      case RentalUnit.month:
        return 'month';
    }
  }

  String get label {
    switch (this) {
      case RentalUnit.hour:
        return 'Hour';
      case RentalUnit.day:
        return 'Day';
      case RentalUnit.week:
        return 'Week';
      case RentalUnit.month:
        return 'Month';
    }
  }

  String pluralize(int quantity) {
    return quantity == 1 ? label : '${label}s';
  }
}

extension BookingStatusX on BookingStatus {
  String get key {
    switch (this) {
      case BookingStatus.pending:
        return 'pending';
      case BookingStatus.confirmed:
        return 'confirmed';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Ongoing';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class VehicleRate {
  const VehicleRate({
    required this.unit,
    required this.price,
  });

  final RentalUnit unit;
  final double price;

  Map<String, dynamic> toMap() {
    return {
      'unit': unit.key,
      'price': price,
    };
  }

  factory VehicleRate.fromMap(Map<String, dynamic> data) {
    return VehicleRate(
      unit: rentalUnitFromKey(data['unit'] as String? ?? 'day'),
      price: (data['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    required this.type,
    required this.imageUrl,
    required this.location,
    required this.description,
    required this.seats,
    required this.transmission,
    required this.energy,
    required this.rating,
    required this.availableNow,
    required this.inventoryCount,
    required this.rates,
    this.imageStoragePath,
    this.galleryImageUrls = const [],
  });

  final String id;
  final String name;
  final VehicleType type;
  final String imageUrl;
  final String location;
  final String description;
  final int seats;
  final String transmission;
  final String energy;
  final double rating;
  final bool availableNow;
  final int inventoryCount;
  final List<VehicleRate> rates;
  final String? imageStoragePath;
  final List<String> galleryImageUrls;

  List<String> get allImageUrls {
    final urls = <String>[];
    if (imageUrl.trim().isNotEmpty) {
      urls.add(imageUrl.trim());
    }
    for (final url in galleryImageUrls) {
      final normalized = url.trim();
      if (normalized.isNotEmpty && !urls.contains(normalized)) {
        urls.add(normalized);
      }
    }
    return urls;
  }

  List<String> get pickupHubs {
    return location
        .split(RegExp(r'[\n,]+'))
        .map((hub) => hub.trim())
        .where((hub) => hub.isNotEmpty)
        .toList();
  }

  String get primaryPickupHub {
    final hubs = pickupHubs;
    if (hubs.isEmpty) {
      return location.trim();
    }
    return hubs.first;
  }

  String get displayEnergyLabel {
    final normalized = energy.trim();
    if (type == VehicleType.bicycle) {
      if (normalized.toLowerCase().contains('electric')) {
        return 'Electric assist';
      }
      return 'Leg power';
    }
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return 'Electric';
  }

  VehicleRate rateFor(RentalUnit unit) {
    return rates.firstWhere((rate) => rate.unit == unit);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.key,
      'imageUrl': imageUrl,
      'location': location,
      'description': description,
      'seats': seats,
      'transmission': transmission,
      'energy': energy,
      'rating': rating,
      'availableNow': availableNow,
      'inventoryCount': inventoryCount,
      'rates': rates.map((rate) => rate.toMap()).toList(),
      'imageStoragePath': imageStoragePath,
      'galleryImageUrls': allImageUrls,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> data) {
    final rateMaps = (data['rates'] as List<dynamic>? ?? const [])
        .map(
          (rate) => rate is Map<String, dynamic>
              ? rate
              : Map<String, dynamic>.from(rate as Map),
        )
        .toList();
    return Vehicle(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      type: vehicleTypeFromKey(data['type'] as String? ?? 'car'),
      imageUrl: data['imageUrl'] as String? ?? '',
      location: data['location'] as String? ?? '',
      description: data['description'] as String? ?? '',
      seats: data['seats'] as int? ?? 1,
      transmission: data['transmission'] as String? ?? '',
      energy: data['energy'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      availableNow: data['availableNow'] as bool? ?? false,
      inventoryCount: (data['inventoryCount'] as int? ?? 1) < 1
          ? 1
          : (data['inventoryCount'] as int? ?? 1),
      rates: rateMaps.map(VehicleRate.fromMap).toList(),
      imageStoragePath: data['imageStoragePath'] as String?,
      galleryImageUrls: (data['galleryImageUrls'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList(),
    );
  }
}

class BookingQuote {
  const BookingQuote({
    required this.vehicle,
    required this.unit,
    required this.quantity,
    required this.startDate,
  });

  final Vehicle vehicle;
  final RentalUnit unit;
  final int quantity;
  final DateTime startDate;

  double get totalPrice => vehicle.rateFor(unit).price * quantity;

  DateTime get endDate {
    switch (unit) {
      case RentalUnit.hour:
        return startDate.add(Duration(hours: quantity));
      case RentalUnit.day:
        return startDate.add(Duration(days: quantity));
      case RentalUnit.week:
        return startDate.add(Duration(days: quantity * 7));
      case RentalUnit.month:
        return DateTime(
          startDate.year,
          startDate.month + quantity,
          startDate.day,
          startDate.hour,
          startDate.minute,
        );
    }
  }
}

class BookingRecord {
  const BookingRecord({
    required this.id,
    required this.userId,
    required this.vehicle,
    required this.unit,
    required this.quantity,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.fulfillmentMethod,
    required this.pickupHub,
    required this.deliveryFee,
    required this.totalPrice,
    required this.createdAt,
    this.cancellationSource,
    this.account,
    this.deliveryAddress,
    this.deliveryNotes,
  });

  final String id;
  final String userId;
  final Vehicle vehicle;
  final RentalUnit unit;
  final int quantity;
  final DateTime startDate;
  final DateTime endDate;
  final BookingStatus status;
  final String fulfillmentMethod;
  final String pickupHub;
  final String? deliveryAddress;
  final String? deliveryNotes;
  final double deliveryFee;
  final double totalPrice;
  final DateTime createdAt;
  final BookingCancellationSource? cancellationSource;
  final BookingAccountSummary? account;

  bool get cancelledByCustomer =>
      status == BookingStatus.cancelled &&
      cancellationSource == BookingCancellationSource.customer;

  bool get cancelledByAdmin =>
      status == BookingStatus.cancelled &&
      cancellationSource == BookingCancellationSource.admin;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'vehicle': vehicle.toMap(),
      'unit': unit.key,
      'quantity': quantity,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status.key,
      'fulfillmentMethod': fulfillmentMethod,
      'pickupHub': pickupHub,
      'deliveryAddress': deliveryAddress,
      'deliveryNotes': deliveryNotes,
      'deliveryFee': deliveryFee,
      'totalPrice': totalPrice,
      'createdAt': createdAt.toIso8601String(),
      'cancellationSource': cancellationSource?.name,
      'account': account?.toMap(),
    };
  }

  factory BookingRecord.fromMap(String id, Map<String, dynamic> data) {
    final rawStartDate = data['startDate'];
    final rawEndDate = data['endDate'];
    final rawCreatedAt = data['createdAt'];
    return BookingRecord(
      id: id,
      userId: data['userId'] as String? ?? '',
      vehicle: Vehicle.fromMap(
        (data['vehicle'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      ),
      unit: rentalUnitFromKey(data['unit'] as String? ?? 'day'),
      quantity: data['quantity'] as int? ?? 1,
      startDate: _dateTimeFromFirestoreValue(rawStartDate),
      endDate: _dateTimeFromFirestoreValue(rawEndDate),
      status: bookingStatusFromKey(data['status'] as String? ?? 'pending'),
      fulfillmentMethod: data['fulfillmentMethod'] as String? ?? 'pickup',
      pickupHub: data['pickupHub'] as String? ?? '',
      deliveryAddress: data['deliveryAddress'] as String?,
      deliveryNotes: data['deliveryNotes'] as String?,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0,
      createdAt: _dateTimeFromFirestoreValue(rawCreatedAt),
      cancellationSource: bookingCancellationSourceFromKey(
        data['cancellationSource'] as String?,
      ),
      account: data['account'] is Map
          ? BookingAccountSummary.fromMap(
              Map<String, dynamic>.from(data['account'] as Map),
            )
          : null,
    );
  }
}

BookingCancellationSource? bookingCancellationSourceFromKey(String? value) {
  switch (value) {
    case 'customer':
      return BookingCancellationSource.customer;
    case 'admin':
      return BookingCancellationSource.admin;
    default:
      return null;
  }
}

class BookingAccountSummary {
  const BookingAccountSummary({
    required this.userId,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String? photoUrl;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
    };
  }

  factory BookingAccountSummary.fromMap(Map<String, dynamic> data) {
    return BookingAccountSummary(
      userId: data['userId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
    );
  }
}

DateTime _dateTimeFromFirestoreValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
