import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/rental_models.dart';
import 'auth_repository.dart';
import 'profile_repository.dart';

class BookingConflictException implements Exception {
  const BookingConflictException(this.message);

  final String message;

  @override
  String toString() => 'BookingConflictException: $message';
}

bool bookingRangesOverlap({
  required DateTime existingStart,
  required DateTime existingEnd,
  required DateTime requestedStart,
  required DateTime requestedEnd,
}) {
  return requestedStart.isBefore(existingEnd) &&
      requestedEnd.isAfter(existingStart);
}

bool bookingCountsTowardAvailability(BookingRecord booking) {
  return booking.status == BookingStatus.pending ||
      booking.status == BookingStatus.confirmed;
}

int overlappingBookingCountForVehicle({
  required String vehicleId,
  required List<BookingRecord> bookings,
  required DateTime requestedStart,
  required DateTime requestedEnd,
}) {
  return bookings.where((booking) {
    if (booking.vehicle.id != vehicleId || !bookingCountsTowardAvailability(booking)) {
      return false;
    }
    return bookingRangesOverlap(
      existingStart: booking.startDate,
      existingEnd: booking.endDate,
      requestedStart: requestedStart,
      requestedEnd: requestedEnd,
    );
  }).length;
}

int remainingVehicleAvailability({
  required Vehicle vehicle,
  required List<BookingRecord> bookings,
  required DateTime requestedStart,
  required DateTime requestedEnd,
}) {
  final reservedCount = overlappingBookingCountForVehicle(
    vehicleId: vehicle.id,
    bookings: bookings,
    requestedStart: requestedStart,
    requestedEnd: requestedEnd,
  );
  final remaining = vehicle.inventoryCount - reservedCount;
  return remaining < 0 ? 0 : remaining;
}

class BookingDraft {
  const BookingDraft({
    required this.vehicle,
    required this.unit,
    required this.quantity,
    required this.startDate,
    required this.endDate,
    required this.fulfillmentMethod,
    required this.pickupHub,
    required this.deliveryFee,
    required this.totalPrice,
    this.deliveryAddress,
    this.deliveryNotes,
  });

  final Vehicle vehicle;
  final RentalUnit unit;
  final int quantity;
  final DateTime startDate;
  final DateTime endDate;
  final String fulfillmentMethod;
  final String pickupHub;
  final String? deliveryAddress;
  final String? deliveryNotes;
  final double deliveryFee;
  final double totalPrice;
}

abstract class BookingRepository {
  Stream<List<BookingRecord>> watchBookings(String userId);

  Stream<List<BookingRecord>> watchAllBookings();

  Future<BookingRecord?> getBookingById(String bookingId);

  Future<String> createBooking({
    required AuthUser authUser,
    required UserProfile userProfile,
    required BookingDraft draft,
  });

  Future<void> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
    BookingCancellationSource? cancellationSource,
  });
}

class FirebaseBookingRepository implements BookingRepository {
  FirebaseBookingRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _firestore.collection('bookings');

  List<BookingRecord> _sortedBookingsFrom(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final bookings = snapshot.docs
        .map((doc) => BookingRecord.fromMap(doc.id, doc.data()))
        .toList();
    bookings.sort((a, b) {
      final startDateComparison = b.startDate.compareTo(a.startDate);
      if (startDateComparison != 0) {
        return startDateComparison;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return bookings;
  }

  @override
  Stream<List<BookingRecord>> watchBookings(String userId) {
    return _bookingsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(_sortedBookingsFrom);
  }

  @override
  Stream<List<BookingRecord>> watchAllBookings() {
    return _bookingsCollection.snapshots().map(_sortedBookingsFrom);
  }

  @override
  Future<BookingRecord?> getBookingById(String bookingId) async {
    final snapshot = await _bookingsCollection.doc(bookingId).get();
    if (!snapshot.exists) {
      return null;
    }
    return BookingRecord.fromMap(snapshot.id, snapshot.data()!);
  }

  @override
  Future<String> createBooking({
    required AuthUser authUser,
    required UserProfile userProfile,
    required BookingDraft draft,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw const BookingConflictException(
          'Your session has ended. Please sign in again before booking.',
        );
      }

      final idToken = await currentUser.getIdToken(true);
      final response = await http.post(
        Uri.parse('https://us-central1-ecorent-ab12b.cloudfunctions.net/createBookingHttp'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(<String, dynamic>{
        'vehicleId': draft.vehicle.id,
        'unit': draft.unit.key,
        'quantity': draft.quantity,
        'startDate': draft.startDate.toUtc().toIso8601String(),
        'fulfillmentMethod': draft.fulfillmentMethod,
        'pickupHub': draft.pickupHub,
        'deliveryAddress': draft.deliveryAddress,
        'deliveryNotes': draft.deliveryNotes,
        }),
      );
      final decodedBody = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 400) {
        final errorBody = decodedBody['error'];
        final message = errorBody is Map<String, dynamic>
            ? errorBody['message']?.toString()
            : null;
        throw BookingConflictException(
          message ?? 'Could not save booking right now. Please try again.',
        );
      }

      final data = decodedBody;
      final bookingId = data['bookingId']?.toString() ?? '';
      if (bookingId.isEmpty) {
        throw const FormatException('Missing bookingId in createBooking response.');
      }
      return bookingId;
    } on BookingConflictException {
      rethrow;
    } catch (error) {
      debugPrint('createBooking failed: $error');
      throw const BookingConflictException(
        'Could not save booking right now. Please try again.',
      );
    }
  }

  @override
  Future<void> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
    BookingCancellationSource? cancellationSource,
  }) async {
    final payload = <String, dynamic>{
      'status': status.key,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == BookingStatus.cancelled) {
      payload['cancellationSource'] = cancellationSource?.name;
    } else {
      payload['cancellationSource'] = FieldValue.delete();
    }
    await _bookingsCollection.doc(bookingId).update(payload);
  }
}
