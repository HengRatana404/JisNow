import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_repository.dart';
import '../services/profile_repository.dart';
import '../theme/app_palette.dart';
import '../widgets/rental_widgets.dart';
import 'rental_app.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.authUser,
    required this.initialProfile,
    required this.isInitialSetup,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final AuthUser authUser;
  final UserProfile? initialProfile;
  final bool isInitialSetup;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  XFile? selectedPhoto;
  String? existingPhotoUrl;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    final existingProfile = widget.initialProfile;
    final displayParts = (widget.authUser.displayName ?? '')
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();

    _firstNameController.text =
        existingProfile?.firstName ?? (displayParts.isNotEmpty ? displayParts.first : '');
    _lastNameController.text = existingProfile?.lastName ??
        (displayParts.length > 1 ? displayParts.sublist(1).join(' ') : '');
    _phoneController.text = existingProfile?.phoneNumber ?? '';
    _emailController.text = existingProfile?.email.isNotEmpty == true
        ? existingProfile!.email
        : widget.authUser.email;
    existingPhotoUrl = existingProfile?.photoUrl ?? widget.authUser.photoUrl;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final isLightMode = theme.brightness == Brightness.light;
    final heroGradient = isLightMode
        ? const [Color(0xFF356F59), Color(0xFF87B69D)]
        : [colors.brandDeep, colors.brandSoft];
    final isPasswordUser = widget.authUser.usesPasswordProvider;
    final canEditCredentials = isPasswordUser && !widget.isInitialSetup;
    final profileInputDecorationTheme = theme.inputDecorationTheme.copyWith(
      fillColor: colors.surfaceSoft,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.brand, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.border),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitialSetup ? 'Complete account' : 'Edit profile'),
        actions: [
          IconButton(
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: () => JisNowApp.of(context).toggleThemeMode(),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Theme(
                data: theme.copyWith(
                  inputDecorationTheme: profileInputDecorationTheme,
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: heroGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: isSaving ? null : _pickProfilePhoto,
                                      borderRadius: BorderRadius.circular(999),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.14),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.18),
                                              ),
                                            ),
                                            child: ProfileAvatar(
                                              imageUrl:
                                                  selectedPhoto == null ? existingPhotoUrl : null,
                                              localImagePath: selectedPhoto?.path,
                                              initials: _initialsPreview(),
                                              radius: 34,
                                              backgroundColor:
                                                  Colors.white.withValues(alpha: 0.18),
                                              textColor: Colors.white,
                                            ),
                                          ),
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: Container(
                                              height: 28,
                                              width: 28,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: colors.brandDeep,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.camera_alt_rounded,
                                                size: 14,
                                                color: colors.brandDeep,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        widget.isInitialSetup ? 'Account setup' : 'Profile settings',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      widget.isInitialSetup
                                          ? 'Create your rider profile'
                                          : 'Update your account details',
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.isInitialSetup
                                          ? 'Finish your account setup.'
                                          : 'Edit your profile.',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.88),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text(
                                'Tap photo to change it.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: isSaving ? null : _pickProfilePhoto,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                ),
                                icon: const Icon(Icons.photo_library_outlined, size: 18),
                                label: const Text('Change photo'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppInlineNotice(
                      icon: Icons.verified_user_outlined,
                      title: widget.isInitialSetup ? 'Required to start booking' : 'Keep this profile current',
                      message: widget.isInitialSetup
                          ? 'Your name and phone number help admin confirm bookings and support requests quickly.'
                          : 'Updated contact details make bookings, pickup coordination, and support replies much smoother.',
                      tone: AppBannerTone.info,
                    ),
                    const SizedBox(height: 20),
                    _ProfileSection(
                      title: 'Personal details',
                      subtitle: 'Keep your rider identity clear for bookings and support.',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'First name',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Enter first name.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Last name',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Enter last name.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (value) {
                              final phone = (value ?? '').trim();
                              if (phone.isEmpty) {
                                return 'Enter phone number.';
                              }
                              if (phone.length < 8) {
                                return 'Enter a valid phone number.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppInlineNotice(
                      icon: isPasswordUser
                          ? Icons.lock_outline_rounded
                          : Icons.account_circle_outlined,
                      title: isPasswordUser ? 'Login details' : 'Google sign-in account',
                      message: canEditCredentials
                          ? 'If you change your email, verify the email link before the new login address takes effect.'
                          : isPasswordUser
                              ? 'This email stays linked to your password account.'
                              : 'This email comes from your Google account and cannot be edited here.',
                      tone: AppBannerTone.success,
                    ),
                    const SizedBox(height: 20),
                    _ProfileSection(
                      title: 'Account detail',
                      subtitle: canEditCredentials
                          ? 'Update the email linked to your password account and change your password when needed.'
                          : isPasswordUser
                              ? 'Your current login email is shown here.'
                              : 'Google accounts use the email provided by Google sign-in.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            enabled: isPasswordUser,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (value) {
                              final email = (value ?? '').trim();
                              if (email.isEmpty) {
                                return 'Enter email address.';
                              }
                              if (!email.contains('@')) {
                                return 'Enter a valid email.';
                              }
                              return null;
                            },
                          ),
                          if (canEditCredentials) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Reset link will be sent to ${_emailController.text.trim()}.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: isSaving ? null : _sendPasswordReset,
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.brand,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.send_rounded, size: 18),
                                label: const Text('Change password'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.errorSoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.errorText,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSaving ? null : _saveProfile,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: colors.brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isInitialSetup
                                    ? 'Finish account setup'
                                    : 'Save changes',
                              ),
                      ),
                    ),
                    if (!widget.isInitialSetup) ...[
                      const SizedBox(height: 12),
                      
                    ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 900,
    );
    if (file != null) {
      setState(() => selectedPhoto = file);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      String? photoUrl = existingPhotoUrl;
      if (selectedPhoto != null) {
        photoUrl = await widget.profileRepository.uploadProfilePhoto(
          userId: widget.authUser.id,
          image: selectedPhoto!,
        );
      }

      final desiredEmail = _emailController.text.trim();
      final passwordUser = widget.authUser.usesPasswordProvider;
      final needsEmailUpdate = passwordUser && desiredEmail != widget.authUser.email;
      var profileEmail = desiredEmail;

      if (needsEmailUpdate) {
        await widget.authRepository.updateEmail(
          newEmail: desiredEmail,
        );
        profileEmail = desiredEmail;
      }

      await widget.profileRepository.saveProfile(
        authUser: widget.authUser,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phoneNumber: _phoneController.text,
        email: profileEmail,
        photoUrl: photoUrl,
      );

      if (!mounted) {
        return;
      }

      if (widget.isInitialSetup) {
        showAppBanner(
          context,
          message: 'Account setup complete.',
          tone: AppBannerTone.success,
        );
      } else {
        showAppBanner(
          context,
          message: needsEmailUpdate
              ? 'Profile updated. Verify the email link before the login email changes.'
              : 'Profile updated.',
          tone: AppBannerTone.success,
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (error) {
      setState(() => errorMessage = _firebaseMessage(error));
    } on FirebaseException catch (error) {
      setState(() => errorMessage = error.message ?? 'Failed to save profile.');
    } catch (_) {
      setState(() => errorMessage = 'Failed to save profile.');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.authRepository.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: 'Password reset email sent to ${_emailController.text.trim()}.',
        tone: AppBannerTone.info,
      );
    } on FirebaseAuthException catch (error) {
      setState(() => errorMessage = _firebaseMessage(error));
    } catch (_) {
      setState(() => errorMessage = 'Could not send password reset email.');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  String _initialsPreview() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final value =
        '${first.isNotEmpty ? first.substring(0, 1) : ''}${last.isNotEmpty ? last.substring(0, 1) : ''}';
    if (value.isEmpty) {
      return widget.initialProfile?.initials ??
          widget.authUser.firstName.substring(0, 1).toUpperCase();
    }
    return value.toUpperCase();
  }

  String _firebaseMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'That email is already used by another account.';
      case 'requires-recent-login':
        return 'Please sign in again before changing email.';
      default:
        return error.message ?? 'Profile update failed.';
    }
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
