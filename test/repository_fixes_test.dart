import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jisnow/services/notification_repository.dart';
import 'package:jisnow/services/profile_repository.dart';
import 'package:jisnow/services/support_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification queries only return the current customer records', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirebaseNotificationRepository(firestore: firestore);

    await firestore.collection('notifications').add({
      'recipientUserId': 'user-1',
      'recipientRole': null,
      'title': 'Customer booking',
      'body': 'For user 1',
      'imageUrl': null,
      'bookingId': 'booking-1',
      'read': false,
      'createdAt': Timestamp.fromDate(DateTime(2026, 6, 4, 10, 0)),
    });
    await firestore.collection('notifications').add({
      'recipientUserId': 'user-2',
      'recipientRole': null,
      'title': 'Other customer booking',
      'body': 'For user 2',
      'imageUrl': null,
      'bookingId': 'booking-2',
      'read': false,
      'createdAt': Timestamp.fromDate(DateTime(2026, 6, 4, 11, 0)),
    });

    final notifications = await repository
        .watchNotifications(userId: 'user-1', isAdmin: false)
        .first;

    expect(notifications.map((item) => item.title), ['Customer booking']);
  });

  test('notification queries only return admin-targeted records for admins', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirebaseNotificationRepository(firestore: firestore);

    await firestore.collection('notifications').add({
      'recipientUserId': null,
      'recipientRole': 'admin',
      'title': 'Customer cancellation',
      'body': 'Admin should see this',
      'imageUrl': null,
      'bookingId': 'booking-1',
      'read': false,
      'createdAt': Timestamp.fromDate(DateTime(2026, 6, 4, 12, 0)),
    });
    await firestore.collection('notifications').add({
      'recipientUserId': 'user-1',
      'recipientRole': null,
      'title': 'Customer-only update',
      'body': 'Admin should not see this',
      'imageUrl': null,
      'bookingId': 'booking-2',
      'read': false,
      'createdAt': Timestamp.fromDate(DateTime(2026, 6, 4, 13, 0)),
    });

    final notifications = await repository
        .watchNotifications(userId: 'admin-1', isAdmin: true)
        .first;

    expect(notifications.map((item) => item.title), ['Customer cancellation']);
  });

  test('support messages preserve the original conversation creation time', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirebaseSupportRepository(firestore: firestore);
    final originalCreatedAt = DateTime(2026, 6, 4, 9, 30);
    final conversation = SupportConversation(
      id: 'booking_123',
      type: 'booking',
      customerUserId: 'user-1',
      customerName: 'Jamie Rider',
      customerEmail: 'jamie@example.com',
      customerPhoneNumber: '012345678',
      subject: 'Support for Test Ride',
      bookingId: 'booking-123',
      bookingVehicleName: 'Test Ride',
      bookingImageUrl: null,
      bookingPickupHub: 'Wat Phnom',
      bookingScheduleLabel: '2026-06-04 09:30 - 1 day rental',
      bookingStatusLabel: 'Pending',
      createdAt: originalCreatedAt,
      updatedAt: originalCreatedAt,
      lastMessageAt: originalCreatedAt,
    );
    const senderProfile = UserProfile(
      userId: 'user-1',
      firstName: 'Jamie',
      lastName: 'Rider',
      phoneNumber: '012345678',
      email: 'jamie@example.com',
      profileComplete: true,
      isAdmin: false,
    );

    await repository.sendMessage(
      conversation: conversation,
      senderProfile: senderProfile,
      text: 'Hello support',
    );

    final snapshot = await firestore
        .collection('support_conversations')
        .doc(conversation.id)
        .get();
    final data = snapshot.data()!;

    expect((data['createdAt'] as Timestamp).toDate(), originalCreatedAt);
    expect(data['lastMessage'], 'Hello support');
  });
}
