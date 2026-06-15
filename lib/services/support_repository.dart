import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/rental_models.dart';
import 'profile_repository.dart';

DateTime _supportDateTimeFromFirestoreValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

@immutable
class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.type,
    required this.customerUserId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhoneNumber,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    this.customerPhotoUrl,
    this.bookingId,
    this.bookingVehicleName,
    this.bookingImageUrl,
    this.bookingPickupHub,
    this.bookingScheduleLabel,
    this.bookingStatusLabel,
    this.lastMessage = '',
    this.lastMessageSenderId = '',
  });

  final String id;
  final String type;
  final String customerUserId;
  final String customerName;
  final String customerEmail;
  final String customerPhoneNumber;
  final String? customerPhotoUrl;
  final String subject;
  final String? bookingId;
  final String? bookingVehicleName;
  final String? bookingImageUrl;
  final String? bookingPickupHub;
  final String? bookingScheduleLabel;
  final String? bookingStatusLabel;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastMessageAt;

  bool get isBookingConversation => type == 'booking';

  factory SupportConversation.fromMap(String id, Map<String, dynamic> data) {
    return SupportConversation(
      id: id,
      type: data['type'] as String? ?? 'general',
      customerUserId: data['customerUserId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? 'Customer',
      customerEmail: data['customerEmail'] as String? ?? '',
      customerPhoneNumber: data['customerPhoneNumber'] as String? ?? '',
      customerPhotoUrl: data['customerPhotoUrl'] as String?,
      subject: data['subject'] as String? ?? 'Support',
      bookingId: data['bookingId'] as String?,
      bookingVehicleName: data['bookingVehicleName'] as String?,
      bookingImageUrl: data['bookingImageUrl'] as String?,
      bookingPickupHub: data['bookingPickupHub'] as String?,
      bookingScheduleLabel: data['bookingScheduleLabel'] as String?,
      bookingStatusLabel: data['bookingStatusLabel'] as String?,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] as String? ?? '',
      createdAt: _supportDateTimeFromFirestoreValue(data['createdAt']),
      updatedAt: _supportDateTimeFromFirestoreValue(data['updatedAt']),
      lastMessageAt: _supportDateTimeFromFirestoreValue(data['lastMessageAt']),
    );
  }
}

@immutable
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.text,
    required this.isAdminSender,
    required this.createdAt,
    this.senderPhotoUrl,
  });

  final String id;
  final String senderUserId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final bool isAdminSender;
  final DateTime createdAt;

  factory SupportMessage.fromMap(String id, Map<String, dynamic> data) {
    return SupportMessage(
      id: id,
      senderUserId: data['senderUserId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Support',
      senderPhotoUrl: data['senderPhotoUrl'] as String?,
      text: data['text'] as String? ?? '',
      isAdminSender: data['isAdminSender'] as bool? ?? false,
      createdAt: _supportDateTimeFromFirestoreValue(data['createdAt']),
    );
  }
}

abstract class SupportRepository {
  Stream<List<SupportConversation>> watchConversations({
    required String userId,
    required bool isAdmin,
  });

  Stream<List<SupportMessage>> watchMessages(String conversationId);

  Future<SupportConversation> getOrCreateGeneralConversation({
    required UserProfile customerProfile,
  });

  Future<SupportConversation> getOrCreateBookingConversation({
    required UserProfile customerProfile,
    required BookingRecord booking,
  });

  Future<void> sendMessage({
    required SupportConversation conversation,
    required UserProfile senderProfile,
    required String text,
  });
}

class FirebaseSupportRepository implements SupportRepository {
  FirebaseSupportRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('support_conversations');

  String _generalConversationId(String userId) => 'general_$userId';

  String _bookingConversationId(String bookingId) => 'booking_$bookingId';

  Map<String, dynamic> _conversationPayload({
    required String type,
    required UserProfile customerProfile,
    required String subject,
    String? bookingId,
    String? bookingVehicleName,
    String? bookingImageUrl,
    String? bookingPickupHub,
    String? bookingScheduleLabel,
    String? bookingStatusLabel,
  }) {
    return <String, dynamic>{
      'type': type,
      'customerUserId': customerProfile.userId,
      'customerName': customerProfile.displayName.isEmpty
          ? 'Customer'
          : customerProfile.displayName,
      'customerEmail': customerProfile.email,
      'customerPhoneNumber': customerProfile.phoneNumber,
      'customerPhotoUrl': customerProfile.photoUrl,
      'subject': subject,
      'bookingId': bookingId,
      'bookingVehicleName': bookingVehicleName,
      'bookingImageUrl': bookingImageUrl,
      'bookingPickupHub': bookingPickupHub,
      'bookingScheduleLabel': bookingScheduleLabel,
      'bookingStatusLabel': bookingStatusLabel,
      'lastMessage': '',
      'lastMessageSenderId': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
  }

  SupportConversation _localConversationFromPayload({
    required String conversationId,
    required Map<String, dynamic> payload,
  }) {
    final now = DateTime.now();
    return SupportConversation(
      id: conversationId,
      type: payload['type'] as String? ?? 'general',
      customerUserId: payload['customerUserId'] as String? ?? '',
      customerName: payload['customerName'] as String? ?? 'Customer',
      customerEmail: payload['customerEmail'] as String? ?? '',
      customerPhoneNumber: payload['customerPhoneNumber'] as String? ?? '',
      customerPhotoUrl: payload['customerPhotoUrl'] as String?,
      subject: payload['subject'] as String? ?? 'Support',
      bookingId: payload['bookingId'] as String?,
      bookingVehicleName: payload['bookingVehicleName'] as String?,
      bookingImageUrl: payload['bookingImageUrl'] as String?,
      bookingPickupHub: payload['bookingPickupHub'] as String?,
      bookingScheduleLabel: payload['bookingScheduleLabel'] as String?,
      bookingStatusLabel: payload['bookingStatusLabel'] as String?,
      lastMessage: payload['lastMessage'] as String? ?? '',
      lastMessageSenderId: payload['lastMessageSenderId'] as String? ?? '',
      createdAt: now,
      updatedAt: now,
      lastMessageAt: now,
    );
  }

  @override
  Stream<List<SupportConversation>> watchConversations({
    required String userId,
    required bool isAdmin,
  }) {
    final stream = isAdmin
        ? _conversations.snapshots()
        : _conversations
            .where('customerUserId', isEqualTo: userId)
            .snapshots();

    return stream.map((snapshot) {
      final conversations = snapshot.docs
          .map((doc) => SupportConversation.fromMap(doc.id, doc.data()))
          .toList();
      conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return conversations;
    });
  }

  @override
  Stream<List<SupportMessage>> watchMessages(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SupportMessage.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Future<SupportConversation> getOrCreateGeneralConversation({
    required UserProfile customerProfile,
  }) {
    return Future<SupportConversation>.value(
      _localConversationFromPayload(
      conversationId: _generalConversationId(customerProfile.userId),
      payload: _conversationPayload(
        type: 'general',
        customerProfile: customerProfile,
        subject: 'General support',
      ),
    ));
  }

  @override
  Future<SupportConversation> getOrCreateBookingConversation({
    required UserProfile customerProfile,
    required BookingRecord booking,
  }) {
    return Future<SupportConversation>.value(
      _localConversationFromPayload(
      conversationId: _bookingConversationId(booking.id),
      payload: _conversationPayload(
        type: 'booking',
        customerProfile: customerProfile,
        subject: 'Support for ${booking.vehicle.name}',
        bookingId: booking.id,
        bookingVehicleName: booking.vehicle.name,
        bookingImageUrl: booking.vehicle.imageUrl,
        bookingPickupHub: booking.pickupHub,
        bookingScheduleLabel:
            '${booking.startDate.year}-${booking.startDate.month.toString().padLeft(2, '0')}-${booking.startDate.day.toString().padLeft(2, '0')} ${booking.startDate.hour.toString().padLeft(2, '0')}:${booking.startDate.minute.toString().padLeft(2, '0')} - ${booking.quantity} ${booking.unit.label.toLowerCase()} rental',
        bookingStatusLabel: booking.status.label,
      ),
    ));
  }

  @override
  Future<void> sendMessage({
    required SupportConversation conversation,
    required UserProfile senderProfile,
    required String text,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }

    final conversationRef = _conversations.doc(conversation.id);
    final messagesRef = conversationRef.collection('messages');
    final batch = _firestore.batch();
    final messageRef = messagesRef.doc();

    batch.set(
      conversationRef,
      <String, dynamic>{
        'type': conversation.type,
        'customerUserId': conversation.customerUserId,
        'customerName': conversation.customerName,
        'customerEmail': conversation.customerEmail,
        'customerPhoneNumber': conversation.customerPhoneNumber,
        'customerPhotoUrl': conversation.customerPhotoUrl,
        'subject': conversation.subject,
        'bookingId': conversation.bookingId,
        'bookingVehicleName': conversation.bookingVehicleName,
        'bookingImageUrl': conversation.bookingImageUrl,
        'bookingPickupHub': conversation.bookingPickupHub,
        'bookingScheduleLabel': conversation.bookingScheduleLabel,
        'bookingStatusLabel': conversation.bookingStatusLabel,
        'lastMessage': normalizedText,
        'lastMessageSenderId': senderProfile.userId,
        'createdAt': conversation.createdAt,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(messageRef, <String, dynamic>{
      'senderUserId': senderProfile.userId,
      'senderName': senderProfile.displayName.isEmpty
          ? senderProfile.email
          : senderProfile.displayName,
      'senderPhotoUrl': senderProfile.photoUrl,
      'text': normalizedText,
      'isAdminSender': senderProfile.isAdmin,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
