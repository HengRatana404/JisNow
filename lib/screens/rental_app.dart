import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_repository.dart';
import '../services/booking_repository.dart';
import '../services/notification_repository.dart';
import '../services/profile_repository.dart';
import '../services/support_repository.dart';
import '../services/vehicle_repository.dart';
import '../theme/app_palette.dart';
import 'auth_gate.dart';

class JisNowApp extends StatefulWidget {
  const JisNowApp({
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

  static JisNowAppState of(BuildContext context) {
    final state = context.findAncestorStateOfType<JisNowAppState>();
    assert(state != null, 'JisNowApp state not found in context');
    return state!;
  }

  @override
  State<JisNowApp> createState() => JisNowAppState();
}

class JisNowAppState extends State<JisNowApp> {
  ThemeMode _themeMode = ThemeMode.system;
  int _homeTabIndex = 0;

  int get homeTabIndex => _homeTabIndex;

  void toggleThemeMode() {
    setState(() {
      final isCurrentlyDark = _themeMode == ThemeMode.dark ||
          (_themeMode == ThemeMode.system &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark);
      _themeMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void rememberHomeTabIndex(int index) {
    _homeTabIndex = index;
  }

  @override
  Widget build(BuildContext context) {
    final lightPalette = AppPalette.light;
    final darkPalette = AppPalette.dark;
    final lightTextTheme = ThemeData(brightness: Brightness.light, useMaterial3: true)
        .textTheme
        .apply(
          bodyColor: lightPalette.textPrimary,
          displayColor: lightPalette.textPrimary,
        );
    final darkTextTheme = ThemeData(brightness: Brightness.dark, useMaterial3: true)
        .textTheme
        .apply(
          bodyColor: darkPalette.textPrimary,
          displayColor: darkPalette.textPrimary,
        );

    return MaterialApp(
      title: 'JisNow',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: lightPalette.brand,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: lightPalette.background,
        useMaterial3: true,
        textTheme: lightTextTheme,
        primaryTextTheme: lightTextTheme,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightPalette.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: lightPalette.textPrimary,
            side: BorderSide(color: lightPalette.border),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: lightPalette.brand,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: lightPalette.brandDeep,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        extensions: const [AppPalette.light],
        dividerColor: lightPalette.divider,
        appBarTheme: AppBarTheme(
          backgroundColor: lightPalette.background,
          foregroundColor: lightPalette.textPrimary,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 1.5,
          color: lightPalette.surface,
          shadowColor: const Color(0x16000000),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: lightPalette.borderSoft),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkPalette.brand,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: darkPalette.background,
        useMaterial3: true,
        textTheme: darkTextTheme,
        primaryTextTheme: darkTextTheme,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkPalette.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: darkPalette.textPrimary,
            side: BorderSide(color: darkPalette.borderSoft),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: darkPalette.brand,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: darkPalette.brand,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        extensions: const [AppPalette.dark],
        dividerColor: darkPalette.divider,
        appBarTheme: AppBarTheme(
          backgroundColor: darkPalette.background,
          foregroundColor: darkPalette.textPrimary,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: darkPalette.surface,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
        ),
      ),
      home: _StartupShell(
        child: AuthGate(
          authRepository: widget.authRepository,
          profileRepository: widget.profileRepository,
          vehicleRepository: widget.vehicleRepository,
          bookingRepository: widget.bookingRepository,
          notificationRepository: widget.notificationRepository,
          supportRepository: widget.supportRepository,
        ),
      ),
    );
  }
}

class _StartupShell extends StatefulWidget {
  const _StartupShell({
    required this.child,
  });

  final Widget child;

  @override
  State<_StartupShell> createState() => _StartupShellState();
}

class _StartupShellState extends State<_StartupShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _wheelRotation;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;
  bool _showApp = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1320),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.34, curve: Curves.easeOut),
      ),
    );
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.84, end: 1.04).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 72,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 28,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.62),
      ),
    );
    _wheelRotation = Tween<double>(begin: 0, end: 1.1).animate(
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0, end: 1.18).chain(
            CurveTween(curve: Curves.easeOutQuart),
          ),
          weight: 82,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.18, end: 1.1).chain(
            CurveTween(curve: Curves.easeOutBack),
          ),
          weight: 18,
        ),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.03, 0.84),
        ),
      ),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.04, 0.48, curve: Curves.easeOutCubic),
      ),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.68, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.26, 0.72, curve: Curves.easeOutCubic),
      ),
    );
    _pulseScale = Tween<double>(begin: 0.88, end: 1.18).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.62, curve: Curves.easeOutCubic),
      ),
    );
    _pulseOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.42, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 1650), () {
      if (!mounted) {
        return;
      }
      setState(() => _showApp = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 560),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final scale = Tween<double>(begin: 0.985, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
          ),
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.018),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: _showApp
          ? widget.child
          : Scaffold(
              key: const ValueKey('startup-splash'),
              backgroundColor: colors.background,
              body: Stack(
                children: [
                  Positioned(
                    top: -120,
                    right: -80,
                    child: _SplashGlow(
                      size: 260,
                      color: colors.brandTintStrong,
                    ),
                  ),
                  Positioned(
                    bottom: -90,
                    left: -70,
                    child: _SplashGlow(
                      size: 220,
                      color: colors.brandTint,
                    ),
                  ),
                  Center(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FadeTransition(
                              opacity: _logoOpacity,
                              child: SlideTransition(
                                position: _logoSlide,
                                child: ScaleTransition(
                                  scale: _logoScale,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      FadeTransition(
                                        opacity: _pulseOpacity,
                                        child: ScaleTransition(
                                          scale: _pulseScale,
                                          child: Container(
                                            width: 250,
                                            height: 250,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  colors.brand.withValues(
                                                    alpha: 0.18,
                                                  ),
                                                  colors.brand.withValues(
                                                    alpha: 0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 30,
                                          vertical: 22,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.surface,
                                          borderRadius: BorderRadius.circular(32),
                                          border: Border.all(
                                            color: colors.borderSoft,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.shadow,
                                              blurRadius: 28,
                                              offset: const Offset(0, 16),
                                            ),
                                          ],
                                        ),
                                        child: _SplashAnimatedLogo(
                                          wheelTurns: _wheelRotation,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            FadeTransition(
                              opacity: _textOpacity,
                              child: SlideTransition(
                                position: _textSlide,
                                child: Column(
                                  children: [
                                    Text(
                                      'JisNow',
                                      style:
                                          theme.textTheme.headlineSmall?.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Electric rides, ready when you are.',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: colors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Smart booking for cleaner city travel.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colors.textSecondary
                                                .withValues(alpha: 0.82),
                                            letterSpacing: 0.2,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SplashGlow extends StatelessWidget {
  const _SplashGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.9),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashAnimatedLogo extends StatelessWidget {
  const _SplashAnimatedLogo({
    required this.wheelTurns,
  });

  final Animation<double> wheelTurns;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final assetPath = isDarkMode
        ? 'assets/branding/jisnow_logo_dark.png'
        : 'assets/branding/jisnow_logo.png';

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 104,
            top: 49,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            left: 100,
            top: 45,
            child: RotationTransition(
              turns: wheelTurns,
              child: const SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _SplashWheelPainter(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashWheelPainter extends CustomPainter {
  const _SplashWheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rimColor = const Color(0xFF22313B);
    final green = const Color(0xFF15986B);

    final outerRing = Paint()
      ..color = rimColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09;

    final innerRing = Paint()
      ..color = rimColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;

    final spokePaint = Paint()
      ..color = rimColor
      ..style = PaintingStyle.fill;

    final whiteRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final hubPaint = Paint()
      ..color = green
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, size.width * 0.44, outerRing);
    canvas.drawCircle(center, size.width * 0.31, innerRing);

    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((2 * math.pi / 5) * i - 0.32);
      final spoke = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.15, 0),
          width: size.width * 0.34,
          height: size.width * 0.085,
        ),
        Radius.circular(size.width * 0.03),
      );
      canvas.drawRRect(spoke, spokePaint);
      canvas.restore();
    }

    canvas.drawCircle(center, size.width * 0.115, whiteRingPaint);
    canvas.drawCircle(center, size.width * 0.082, hubPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
