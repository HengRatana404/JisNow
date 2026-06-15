import 'package:flutter/material.dart';

import '../services/auth_repository.dart';
import '../services/booking_repository.dart';
import '../services/notification_repository.dart';
import '../services/profile_repository.dart';
import '../services/support_repository.dart';
import '../services/vehicle_repository.dart';
import '../widgets/rental_widgets.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
import 'rental_app.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.vehicleRepository,
    required this.bookingRepository,
    required this.notificationRepository,
    required this.supportRepository,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final VehicleRepository vehicleRepository;
  final BookingRepository bookingRepository;
  final NotificationRepository notificationRepository;
  final SupportRepository supportRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: authRepository.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return LoginScreen(
            authRepository: authRepository,
          );
        }

        return StreamBuilder<UserProfile?>(
          stream: profileRepository.watchProfile(user.id),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }

            final profile = profileSnapshot.data;
            if (profile == null || !profile.profileComplete) {
              return ProfileSetupScreen(
                authRepository: authRepository,
                profileRepository: profileRepository,
                authUser: user,
                initialProfile: profile,
                isInitialSetup: true,
              );
            }

            return RentalHomeScreen(
              authRepository: authRepository,
              profileRepository: profileRepository,
              vehicleRepository: vehicleRepository,
              bookingRepository: bookingRepository,
              notificationRepository: notificationRepository,
              supportRepository: supportRepository,
              currentUser: user,
              currentProfile: profile,
              initialTabIndex: JisNowApp.of(context).homeTabIndex,
            );
          },
        );
      },
    );
  }
}
