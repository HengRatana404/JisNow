import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.providerIds,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final List<String> providerIds;
  final String? displayName;
  final String? photoUrl;

  bool get usesPasswordProvider => providerIds.contains('password');

  String get firstName {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) {
      return email.split('@').first;
    }
    return name.split(' ').first;
  }
}

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  Future<void> signInWithGoogle();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  });

  Future<void> updateEmail({
    required String newEmail,
  });

  Future<void> sendPasswordResetEmail({
    required String email,
  });

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    String? serverClientId,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _serverClientId =
           serverClientId ?? DefaultFirebaseOptions.androidWebClientId;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final String _serverClientId;
  Future<void>? _initialization;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.idTokenChanges().map(_mapUser);
  }

  @override
  Future<void> signInWithGoogle() async {
    await _ensureInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        'Interactive Google sign-in is not supported on this platform.',
      );
    }

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final String? idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message:
            'Google sign-in returned no ID token. Check your Firebase SHA keys and google-services.json file.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> updateEmail({
    required String newEmail,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in email account was found.',
      );
    }

    final normalizedEmail = newEmail.trim();
    if (normalizedEmail != user.email) {
      await user.verifyBeforeUpdateEmail(normalizedEmail);
    }

    await user.reload();
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> _ensureInitialized() {
    return _initialization ??=
        _googleSignIn.initialize(serverClientId: _serverClientId);
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    return AuthUser(
      id: user.uid,
      email: user.email ?? '',
      providerIds: user.providerData.map((item) => item.providerId).toList(),
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
