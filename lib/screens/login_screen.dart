import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_repository.dart';
import '../theme/app_palette.dart';
import '../widgets/rental_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authRepository,
  });

  final AuthRepository authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool isLoading = false;
  String? errorMessage;
  bool isCreateAccount = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 900;
            return SingleChildScrollView(
              physics: keyboardOpen
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: keyboardOpen
                          ? MainAxisAlignment.start
                          : (isCompact ? MainAxisAlignment.start : MainAxisAlignment.center),
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      SizedBox(height: isCompact ? 4 : 0),
                      Center(
                        child: SizedBox(
                          width: isCompact ? 172 : 250,
                          child: const AppLogo(),
                        ),
                      ),
                      SizedBox(height: isCompact ? 10 : 28),
                      if (isCompact)
                        Column(
                          children: [
                            Text(
                              isCreateAccount ? 'Create account' : 'Sign in',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isCreateAccount
                                  ? 'Create your account to continue.'
                                  : 'Use email or Google to continue.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: colors.borderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCreateAccount ? 'Create account' : 'Sign in',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isCreateAccount
                                    ? 'Start with your email, then finish your rider profile after the account is created.'
                                    : 'Use email and password or keep going with Google.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: colors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    _InfoBullet(
                                      icon: Icons.bolt_rounded,
                                      text: 'Fast sign-in',
                                    ),
                                    const SizedBox(width: 10),
                                    _InfoBullet(
                                      icon: Icons.verified_user_rounded,
                                      text: 'Secure account',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: isCompact ? 28 : 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<bool>(
                                  showSelectedIcon: false,
                                  style: ButtonStyle(
                                    visualDensity: isCompact
                                        ? const VisualDensity(vertical: -2)
                                        : VisualDensity.standard,
                                    padding: WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: isCompact ? 14 : 16,
                                      ),
                                    ),
                                    textStyle: WidgetStatePropertyAll(
                                      theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  segments: const [
                                    ButtonSegment<bool>(value: false, label: Text('Sign in')),
                                    ButtonSegment<bool>(value: true, label: Text('Create account')),
                                  ],
                                  selected: {isCreateAccount},
                                  onSelectionChanged: (selection) {
                                    setState(() {
                                      isCreateAccount = selection.first;
                                      errorMessage = null;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(height: isCompact ? 12 : 18),
                              TextFormField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).requestFocus(_passwordFocusNode);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return 'Enter your email.';
                                  }
                                  if (!email.contains('@')) {
                                    return 'Enter a valid email.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: obscurePassword,
                                textInputAction:
                                    isCreateAccount ? TextInputAction.next : TextInputAction.done,
                                autofillHints: isCreateAccount
                                    ? const [AutofillHints.newPassword]
                                    : const [AutofillHints.password],
                                onFieldSubmitted: (_) {
                                  if (isCreateAccount) {
                                    FocusScope.of(context).requestFocus(
                                      _confirmPasswordFocusNode,
                                    );
                                    return;
                                  }
                                  _submitEmailPassword();
                                },
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() => obscurePassword = !obscurePassword);
                                    },
                                    icon: Icon(
                                      obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  final password = value ?? '';
                                  if (password.isEmpty) {
                                    return 'Enter your password.';
                                  }
                                  if (password.length < 6) {
                                    return 'Password must be at least 6 characters.';
                                  }
                                  return null;
                                },
                              ),
                              if (isCreateAccount) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  focusNode: _confirmPasswordFocusNode,
                                  obscureText: obscureConfirmPassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.newPassword],
                                  onFieldSubmitted: (_) => _submitEmailPassword(),
                                  decoration: InputDecoration(
                                    labelText: 'Confirm password',
                                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(
                                          () => obscureConfirmPassword =
                                              !obscureConfirmPassword,
                                        );
                                      },
                                      icon: Icon(
                                        obscureConfirmPassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (!isCreateAccount) {
                                      return null;
                                    }
                                    final confirmPassword = value ?? '';
                                    if (confirmPassword.isEmpty) {
                                      return 'Confirm your password.';
                                    }
                                    if (confirmPassword != _passwordController.text) {
                                      return 'Passwords do not match.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              SizedBox(height: isCompact ? 14 : 18),
                              if (!isCreateAccount)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: isLoading ? null : _sendPasswordReset,
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                              if (!isCreateAccount) const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: isLoading ? null : _submitEmailPassword,
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
                                    backgroundColor: colors.brand,
                                  ),
                                  child: Text(
                                    isLoading
                                        ? 'Please wait...'
                                        : isCreateAccount
                                            ? 'Create account'
                                            : 'Sign in with email',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 8 : 20),
                      Row(
                        children: [
                          Expanded(child: Divider(color: colors.divider)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12),
                            child: Text('or', style: theme.textTheme.bodyMedium),
                          ),
                          Expanded(child: Divider(color: colors.divider)),
                        ],
                      ),
                      SizedBox(height: isCompact ? 8 : 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isLoading ? null : _signInWithGoogle,
                          icon: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const _GoogleMark(),
                          label: Text(isLoading ? 'Signing in...' : 'Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
                          ),
                        ),
                      ),
                      if (errorMessage != null) ...[
                        SizedBox(height: isCompact ? 12 : 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(14),
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
                        ),
                      ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    await _runAuthAction(widget.authRepository.signInWithGoogle);
  }

  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await _runAuthAction(() async {
      if (isCreateAccount) {
        await widget.authRepository.createAccountWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.authRepository.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    });
  }

  Future<void> _sendPasswordReset() async {
    final email = await _showForgotPasswordDialog();
    if (email == null) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await widget.authRepository.sendPasswordResetEmail(email: email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email. Check inbox or spam.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      setState(() => errorMessage = _firebaseEmailErrorMessage(error));
    } catch (_) {
      setState(() => errorMessage = 'Could not send password reset email.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await action();
    } on FirebaseAuthException catch (error) {
      setState(() => errorMessage = _firebaseEmailErrorMessage(error));
    } on GoogleSignInException catch (error) {
      setState(() => errorMessage = _googleSignInErrorMessage(error));
    } on UnsupportedError catch (error) {
      setState(() => errorMessage = error.message ?? 'This sign-in method is not available here.');
    } catch (_) {
      setState(() => errorMessage = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _googleSignInErrorMessage(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Sign-in was canceled.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Google sign-in is not configured correctly yet. Re-download google-services.json after adding SHA keys.';
      default:
        return error.description ?? 'Google sign-in failed.';
    }
  }

  String _firebaseEmailErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your internet and try again.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }

  Future<String?> _showForgotPasswordDialog() async {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final controller = TextEditingController(text: _emailController.text.trim());
    String? localError;

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Forgot password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your email and we will send you a password reset link.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                      errorText: localError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty || !value.contains('@')) {
                      setDialogState(() {
                        localError = 'Enter a valid email.';
                      });
                      return;
                    }
                    _emailController.text = value;
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: const Text('Send link'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return email;
  }
}

class _InfoBullet extends StatelessWidget {
  const _InfoBullet({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final background = Theme.of(context).brightness == Brightness.light
        ? colors.surfaceSoft
        : colors.brandTintStrong;
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colors.brand, size: 18),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/branding/google_g.svg',
      width: 20,
      height: 20,
    );
  }
}
