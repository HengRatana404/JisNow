import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'firebase_options.dart';
import 'services/booking_repository.dart';
import 'services/auth_repository.dart';
import 'services/notification_repository.dart';
import 'services/profile_repository.dart';
import 'services/support_repository.dart';
import 'services/vehicle_repository.dart';
import 'screens/rental_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 300;
  imageCache.maximumSizeBytes = 200 << 20;
  final mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
    await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final authRepository = FirebaseAuthRepository();
  final profileRepository = FirebaseProfileRepository();
  final vehicleRepository = FirebaseVehicleRepository();
  final bookingRepository = FirebaseBookingRepository();
  final notificationRepository = FirebaseNotificationRepository();
  final supportRepository = FirebaseSupportRepository();
  runApp(
    JisNowApp(
      authRepository: authRepository,
      profileRepository: profileRepository,
      vehicleRepository: vehicleRepository,
      bookingRepository: bookingRepository,
      notificationRepository: notificationRepository,
      supportRepository: supportRepository,
    ),
  );
}
