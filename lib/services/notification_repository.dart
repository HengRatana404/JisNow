import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.imageUrl,
    this.bookingId,
    this.recipientUserId,
    this.recipientRole,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? imageUrl;
  final String? bookingId;
  final String? recipientUserId;
  final String? recipientRole;
  final bool read;

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    final rawCreatedAt = data['createdAt'];
    return AppNotification(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      bookingId: data['bookingId'] as String?,
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : DateTime.tryParse(rawCreatedAt?.toString() ?? '') ?? DateTime.now(),
      recipientUserId: data['recipientUserId'] as String?,
      recipientRole: data['recipientRole'] as String?,
      read: data['read'] as bool? ?? false,
    );
  }
}

abstract class NotificationRepository {
  Stream<List<AppNotification>> watchNotifications({
    required String userId,
    required bool isAdmin,
  });

  Future<void> createNotification({
    String? recipientUserId,
    String? recipientRole,
    required String title,
    required String body,
    String? imageUrl,
    String? bookingId,
  });
}

class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  @override
  Stream<List<AppNotification>> watchNotifications({
    required String userId,
    required bool isAdmin,
  }) {
    final query = isAdmin
        ? _notifications
            .where('recipientRole', isEqualTo: 'admin')
            .orderBy('createdAt', descending: true)
            .limit(30)
        : _notifications
            .where('recipientUserId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(30);

    return query
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
              .toList();
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }

  @override
  Future<void> createNotification({
    String? recipientUserId,
    String? recipientRole,
    required String title,
    required String body,
    String? imageUrl,
    String? bookingId,
  }) async {
    await _notifications.add({
      'recipientUserId': recipientUserId,
      'recipientRole': recipientRole,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'bookingId': bookingId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
