import 'package:flutter/material.dart';
import 'package:jisnow/screens/admin_vehicles_screen.dart';
import 'package:jisnow/screens/rental_app.dart';
import 'package:jisnow/services/auth_repository.dart';
import 'package:jisnow/services/booking_repository.dart';
import 'package:jisnow/services/notification_repository.dart';
import 'package:jisnow/services/profile_repository.dart';
import 'package:jisnow/services/support_repository.dart';
import 'package:jisnow/services/vehicle_repository.dart';
import 'package:jisnow/theme/app_palette.dart';
import 'package:jisnow/models/rental_models.dart';
import 'package:jisnow/screens/profile_setup_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('shows login screen when signed out', (tester) async {
    await tester.pumpWidget(
      JisNowApp(
        authRepository: _FakeAuthRepository.signedOut(),
        profileRepository: _FakeProfileRepository(),
        vehicleRepository: _FakeVehicleRepository(),
        bookingRepository: _FakeBookingRepository(),
        notificationRepository: _FakeNotificationRepository(),
        supportRepository: _FakeSupportRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Sign in with email'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('shows home screen for signed-in users', (tester) async {
    await tester.pumpWidget(
      JisNowApp(
        authRepository: _FakeAuthRepository.signedIn(_demoAuthUser),
        profileRepository: _FakeProfileRepository(
          profile: _demoProfile,
        ),
        vehicleRepository: _FakeVehicleRepository(
          vehicles: [
            _vehicleWithLocation('Airport Hub, Downtown Hub'),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        notificationRepository: _FakeNotificationRepository(),
        supportRepository: _FakeSupportRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Jamie'), findsOneWidget);
    expect(find.text('Test Ride'), findsWidgets);
  });

  testWidgets('shows profile setup when signed-in profile is incomplete', (tester) async {
    await tester.pumpWidget(
      JisNowApp(
        authRepository: _FakeAuthRepository.signedIn(_demoAuthUser),
        profileRepository: _FakeProfileRepository(
          profile: const UserProfile(
            userId: 'user-1',
            firstName: 'Jamie',
            lastName: 'Rider',
            phoneNumber: '',
            email: 'jamie@example.com',
            profileComplete: false,
            isAdmin: false,
          ),
        ),
        vehicleRepository: _FakeVehicleRepository(),
        bookingRepository: _FakeBookingRepository(),
        notificationRepository: _FakeNotificationRepository(),
        supportRepository: _FakeSupportRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('Create your rider profile'), findsOneWidget);
    expect(find.text('Finish account setup'), findsOneWidget);
  });

  test('splits pickup hubs from a multi-location vehicle string', () {
    final vehicle = _vehicleWithLocation('Airport Hub, Downtown Hub\nRiverside Hub');

    expect(vehicle.pickupHubs, ['Airport Hub', 'Downtown Hub', 'Riverside Hub']);
    expect(vehicle.primaryPickupHub, 'Airport Hub');
  });

  test('deduplicates vehicle gallery urls with primary image first', () {
    const vehicle = Vehicle(
      id: 'gallery-1',
      name: 'Gallery Ride',
      type: VehicleType.car,
      imageUrl: 'https://example.com/main.jpg',
      location: 'Wat Phnom',
      description: 'Gallery test vehicle.',
      seats: 4,
      transmission: 'Auto',
      energy: 'Electric',
      rating: 4.9,
      availableNow: true,
      inventoryCount: 3,
      galleryImageUrls: [
        'https://example.com/main.jpg',
        'https://example.com/side.jpg',
        'https://example.com/rear.jpg',
      ],
      rates: [
        VehicleRate(unit: RentalUnit.day, price: 10),
      ],
    );

    expect(vehicle.allImageUrls, [
      'https://example.com/main.jpg',
      'https://example.com/side.jpg',
      'https://example.com/rear.jpg',
    ]);
  });

  testWidgets('groups booking history sections for customer bookings', (tester) async {
    await tester.pumpWidget(
      JisNowApp(
        authRepository: _FakeAuthRepository.signedIn(_demoAuthUser),
        profileRepository: _FakeProfileRepository(profile: _demoProfile),
        vehicleRepository: _FakeVehicleRepository(
          vehicles: [_vehicleWithLocation('Wat Phnom')],
        ),
        bookingRepository: _FakeBookingRepository(
          bookings: [
            _bookingRecord('pending', BookingStatus.pending),
            _bookingRecord('completed', BookingStatus.completed),
          ],
        ),
        notificationRepository: _FakeNotificationRepository(),
        supportRepository: _FakeSupportRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();

    expect(find.text('Active now'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
  });

  testWidgets('admin booking search matches split terms across fields', (tester) async {
    await tester.pumpWidget(
      _testApp(
        AdminVehiclesScreen(
          vehicleRepository: _FakeVehicleRepository(
            vehicles: [_vehicleWithLocation('Wat Phnom')],
          ),
          bookingRepository: _FakeBookingRepository(
            bookings: [
              _bookingRecord('booking-1', BookingStatus.pending),
              _bookingRecordWithAccount(
                'booking-2',
                BookingStatus.completed,
                const BookingAccountSummary(
                  userId: 'user-2',
                  displayName: 'Sokha Driver',
                  firstName: 'Sokha',
                  lastName: 'Driver',
                  email: 'sokha@example.com',
                  phoneNumber: '098765432',
                ),
              ),
            ],
          ),
          profileRepository: _FakeProfileRepository(profile: _adminProfile),
          notificationRepository: _FakeNotificationRepository(),
          isAdmin: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'driver sokha');
    await tester.pumpAndSettle();

    expect(find.text('Sokha Driver'), findsWidgets);
    expect(find.text('Jamie Rider'), findsNothing);
  });

  testWidgets('profile email update saves the new email value', (tester) async {
    final authRepository = _RecordingAuthRepository.signedIn(_demoAuthUser);
    final profileRepository = _RecordingProfileRepository(profile: _demoProfile);

    await tester.pumpWidget(
      _testApp(
        ProfileSetupScreen(
          authRepository: authRepository,
          profileRepository: profileRepository,
          authUser: _demoAuthUser,
          initialProfile: _demoProfile,
          isInitialSetup: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'updated@example.com',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(authRepository.updatedEmail, 'updated@example.com');
    expect(profileRepository.savedEmail, 'updated@example.com');
  });

  test('booking overlap helper detects intersecting reservations', () {
    expect(
      bookingRangesOverlap(
        existingStart: DateTime(2026, 6, 1, 10, 0),
        existingEnd: DateTime(2026, 6, 1, 12, 0),
        requestedStart: DateTime(2026, 6, 1, 11, 0),
        requestedEnd: DateTime(2026, 6, 1, 13, 0),
      ),
      isTrue,
    );
    expect(
      bookingRangesOverlap(
        existingStart: DateTime(2026, 6, 1, 10, 0),
        existingEnd: DateTime(2026, 6, 1, 12, 0),
        requestedStart: DateTime(2026, 6, 1, 12, 0),
        requestedEnd: DateTime(2026, 6, 1, 13, 0),
      ),
      isFalse,
    );
  });

  test('remaining availability respects vehicle inventory count', () {
    final vehicle = _vehicleWithLocation('Wat Phnom');
    final bookings = [
      _bookingRecord('active-1', BookingStatus.pending),
      BookingRecord(
        id: 'active-2',
        userId: 'user-2',
        vehicle: vehicle,
        unit: RentalUnit.day,
        quantity: 1,
        startDate: DateTime(2026, 5, 30, 12, 0),
        endDate: DateTime(2026, 5, 31, 12, 0),
        status: BookingStatus.confirmed,
        fulfillmentMethod: 'pickup',
        pickupHub: 'Wat Phnom',
        deliveryFee: 0,
        totalPrice: 20,
        createdAt: DateTime(2026, 5, 29, 10, 0),
      ),
    ];

    expect(
      remainingVehicleAvailability(
        vehicle: vehicle,
        bookings: bookings,
        requestedStart: DateTime(2026, 5, 30, 13, 0),
        requestedEnd: DateTime(2026, 5, 30, 18, 0),
      ),
      0,
    );
  });
}

const _demoAuthUser = AuthUser(
  id: 'user-1',
  email: 'jamie@example.com',
  providerIds: ['password'],
  displayName: 'Jamie Rider',
);

const _demoProfile = UserProfile(
  userId: 'user-1',
  firstName: 'Jamie',
  lastName: 'Rider',
  phoneNumber: '012345678',
  email: 'jamie@example.com',
  profileComplete: true,
  isAdmin: false,
);

const _adminProfile = UserProfile(
  userId: 'admin-1',
  firstName: 'Admin',
  lastName: 'User',
  phoneNumber: '099999999',
  email: 'admin@example.com',
  profileComplete: true,
  isAdmin: true,
);

Widget _testApp(Widget home) {
  return MaterialApp(
    theme: ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      extensions: const [AppPalette.light],
    ),
    home: home,
  );
}

Vehicle _vehicleWithLocation(String location) {
  return Vehicle(
    id: 'vehicle-1',
    name: 'Test Ride',
    type: VehicleType.motorbike,
    imageUrl: '',
    location: location,
    description: 'Great for city trips.',
    seats: 2,
    transmission: 'Auto',
    energy: 'Electric',
    rating: 4.8,
    availableNow: true,
    inventoryCount: 2,
    rates: const [
      VehicleRate(unit: RentalUnit.hour, price: 4),
      VehicleRate(unit: RentalUnit.day, price: 20),
      VehicleRate(unit: RentalUnit.week, price: 100),
      VehicleRate(unit: RentalUnit.month, price: 320),
    ],
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._stream);

  factory _FakeAuthRepository.signedOut() {
    return _FakeAuthRepository(Stream<AuthUser?>.value(null));
  }

  factory _FakeAuthRepository.signedIn(AuthUser user) {
    return _FakeAuthRepository(Stream<AuthUser?>.value(user));
  }

  final Stream<AuthUser?> _stream;

  @override
  Stream<AuthUser?> authStateChanges() => _stream;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> updateEmail({
    required String newEmail,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {}

  @override
  Future<void> signOut() async {}
}

class _RecordingAuthRepository extends _FakeAuthRepository {
  _RecordingAuthRepository(super.stream);

  factory _RecordingAuthRepository.signedIn(AuthUser user) {
    return _RecordingAuthRepository(Stream<AuthUser?>.value(user));
  }

  String? updatedEmail;

  @override
  Future<void> updateEmail({
    required String newEmail,
  }) async {
    updatedEmail = newEmail;
  }
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.profile});

  final UserProfile? profile;

  @override
  Future<void> saveProfile({
    required AuthUser authUser,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String email,
    String? photoUrl,
  }) async {}

  @override
  Future<String> uploadProfilePhoto({
    required String userId,
    required dynamic image,
  }) async {
    return '';
  }

  @override
  Stream<UserProfile?> watchProfile(String userId) {
    return Stream<UserProfile?>.value(profile);
  }

  @override
  Stream<List<UserProfile>> watchAllProfiles() {
    return Stream<List<UserProfile>>.value(
      profile == null ? const <UserProfile>[] : <UserProfile>[profile!],
    );
  }
}

class _RecordingProfileRepository extends _FakeProfileRepository {
  _RecordingProfileRepository({super.profile});

  String? savedEmail;

  @override
  Future<void> saveProfile({
    required AuthUser authUser,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String email,
    String? photoUrl,
  }) async {
    savedEmail = email;
  }
}

class _FakeVehicleRepository implements VehicleRepository {
  _FakeVehicleRepository({List<Vehicle>? vehicles})
      : _vehicles = vehicles ?? const [];

  final List<Vehicle> _vehicles;

  @override
  Future<void> seedVehiclesIfEmpty() async {}

  @override
  Future<void> syncVehiclesFromSeedData() async {}

  @override
  Future<void> saveVehicle(Vehicle vehicle) async {}

  @override
  Future<UploadedVehicleImage> uploadVehicleImage({
    required String vehicleId,
    required XFile image,
  }) async {
    return const UploadedVehicleImage(
      downloadUrl: '',
      storagePath: '',
    );
  }

  @override
  Future<List<UploadedVehicleImage>> uploadVehicleGalleryImages({
    required String vehicleId,
    required List<XFile> images,
  }) async {
    return images
        .map(
          (_) => const UploadedVehicleImage(
            downloadUrl: '',
            storagePath: '',
          ),
        )
        .toList();
  }

  @override
  Stream<List<Vehicle>> watchVehicles() => Stream<List<Vehicle>>.value(_vehicles);

  @override
  Future<void> deleteVehicle(Vehicle vehicle) async {}
}

class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository({
    List<BookingRecord>? bookings,
  }) : _bookings = bookings ?? const [];

  final List<BookingRecord> _bookings;

  @override
  Future<String> createBooking({
    required AuthUser authUser,
    required UserProfile userProfile,
    required BookingDraft draft,
  }) async => 'booking-test-id';

  @override
  Stream<List<BookingRecord>> watchBookings(String userId) =>
      Stream<List<BookingRecord>>.value(
        _bookings.where((booking) => booking.userId == userId).toList(),
      );

  @override
  Stream<List<BookingRecord>> watchAllBookings() =>
      Stream<List<BookingRecord>>.value(_bookings);

  @override
  Future<BookingRecord?> getBookingById(String bookingId) async {
    for (final booking in _bookings) {
      if (booking.id == bookingId) {
        return booking;
      }
    }
    return null;
  }

  @override
  Future<void> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
    BookingCancellationSource? cancellationSource,
  }) async {}
}

class _FakeNotificationRepository implements NotificationRepository {
  @override
  Future<void> createNotification({
    String? recipientUserId,
    String? recipientRole,
    required String title,
    required String body,
    String? imageUrl,
    String? bookingId,
  }) async {}

  @override
  Stream<List<AppNotification>> watchNotifications({
    required String userId,
    required bool isAdmin,
  }) {
    return const Stream<List<AppNotification>>.empty();
  }
}

class _FakeSupportRepository implements SupportRepository {
  @override
  Future<SupportConversation> getOrCreateBookingConversation({
    required UserProfile customerProfile,
    required BookingRecord booking,
  }) async {
    return SupportConversation(
      id: 'booking_${booking.id}',
      type: 'booking',
      customerUserId: customerProfile.userId,
      customerName: customerProfile.displayName,
      customerEmail: customerProfile.email,
      customerPhoneNumber: customerProfile.phoneNumber,
      subject: 'Support for ${booking.vehicle.name}',
      bookingId: booking.id,
      bookingVehicleName: booking.vehicle.name,
      bookingPickupHub: booking.pickupHub,
      bookingScheduleLabel: '2026-06-01 10:00 • 1 day rental',
      bookingStatusLabel: booking.status.label,
      createdAt: DateTime(2026, 6, 1, 10, 0),
      updatedAt: DateTime(2026, 6, 1, 10, 0),
      lastMessageAt: DateTime(2026, 6, 1, 10, 0),
    );
  }

  @override
  Future<SupportConversation> getOrCreateGeneralConversation({
    required UserProfile customerProfile,
  }) async {
    return SupportConversation(
      id: 'general_${customerProfile.userId}',
      type: 'general',
      customerUserId: customerProfile.userId,
      customerName: customerProfile.displayName,
      customerEmail: customerProfile.email,
      customerPhoneNumber: customerProfile.phoneNumber,
      subject: 'General support',
      createdAt: DateTime(2026, 6, 1, 10, 0),
      updatedAt: DateTime(2026, 6, 1, 10, 0),
      lastMessageAt: DateTime(2026, 6, 1, 10, 0),
    );
  }

  @override
  Future<void> sendMessage({
    required SupportConversation conversation,
    required UserProfile senderProfile,
    required String text,
  }) async {}

  @override
  Stream<List<SupportConversation>> watchConversations({
    required String userId,
    required bool isAdmin,
  }) {
    return const Stream<List<SupportConversation>>.empty();
  }

  @override
  Stream<List<SupportMessage>> watchMessages(String conversationId) {
    return const Stream<List<SupportMessage>>.empty();
  }
}

BookingRecord _bookingRecord(String id, BookingStatus status) {
  final vehicle = _vehicleWithLocation('Wat Phnom');
  return BookingRecord(
    id: id,
    userId: _demoAuthUser.id,
    vehicle: vehicle,
    unit: RentalUnit.day,
    quantity: 1,
    startDate: DateTime(2026, 5, 30, 10, 0),
    endDate: DateTime(2026, 5, 31, 10, 0),
    status: status,
    fulfillmentMethod: 'pickup',
    pickupHub: 'Wat Phnom',
    deliveryFee: 0,
    totalPrice: 20,
    createdAt: DateTime(2026, 5, 29, 9, 0),
    account: const BookingAccountSummary(
      userId: 'user-1',
      displayName: 'Jamie Rider',
      firstName: 'Jamie',
      lastName: 'Rider',
      email: 'jamie@example.com',
      phoneNumber: '012345678',
    ),
  );
}

BookingRecord _bookingRecordWithAccount(
  String id,
  BookingStatus status,
  BookingAccountSummary account,
) {
  final base = _bookingRecord(id, status);
  return BookingRecord(
    id: base.id,
    userId: base.userId,
    vehicle: base.vehicle,
    unit: base.unit,
    quantity: base.quantity,
    startDate: base.startDate,
    endDate: base.endDate,
    status: base.status,
    fulfillmentMethod: base.fulfillmentMethod,
    pickupHub: base.pickupHub,
    deliveryFee: base.deliveryFee,
    totalPrice: base.totalPrice,
    createdAt: base.createdAt,
    account: account,
  );
}
