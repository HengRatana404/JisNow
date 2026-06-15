import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'auth_repository.dart';

@immutable
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.email,
    required this.profileComplete,
    required this.isAdmin,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String email;
  final String? photoUrl;
  final bool profileComplete;
  final bool isAdmin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.isNotEmpty ? firstName.substring(0, 1) : '';
    final last = lastName.isNotEmpty ? lastName.substring(0, 1) : '';
    final value = '$first$last'.trim();
    if (value.isEmpty) {
      return 'U';
    }
    return value.toUpperCase();
  }

  factory UserProfile.fromMap(String userId, Map<String, dynamic> data) {
    return UserProfile(
      userId: userId,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      profileComplete: data['profileComplete'] as bool? ?? false,
      isAdmin: data['isAdmin'] as bool? ?? false,
      createdAt: _dateTimeFromFirestoreValue(data['createdAt']),
      updatedAt: _dateTimeFromFirestoreValue(data['updatedAt']),
    );
  }
}

DateTime? _dateTimeFromFirestoreValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

abstract class ProfileRepository {
  Stream<UserProfile?> watchProfile(String userId);

  Stream<List<UserProfile>> watchAllProfiles();

  Future<String> uploadProfilePhoto({
    required String userId,
    required XFile image,
  });

  Future<void> saveProfile({
    required AuthUser authUser,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String email,
    String? photoUrl,
  });
}

class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  @override
  Stream<UserProfile?> watchProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return UserProfile.fromMap(userId, doc.data()!);
    });
  }

  @override
  Stream<List<UserProfile>> watchAllProfiles() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final profiles = snapshot.docs
          .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
          .toList();
      profiles.sort((a, b) {
        if (a.isAdmin != b.isAdmin) {
          return a.isAdmin ? -1 : 1;
        }
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
      return profiles;
    });
  }

  @override
  Future<String> uploadProfilePhoto({
    required String userId,
    required XFile image,
  }) async {
    final ref = _storage.ref().child('users/$userId/profile.jpg');
    final metadata = SettableMetadata(contentType: image.mimeType);

    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      await ref.putData(bytes, metadata);
    } else {
      await ref.putFile(File(image.path), metadata);
    }

    return ref.getDownloadURL();
  }

  @override
  Future<void> saveProfile({
    required AuthUser authUser,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String email,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user was found.',
      );
    }

    final normalizedFirstName = firstName.trim();
    final normalizedLastName = lastName.trim();
    final normalizedPhoneNumber = phoneNumber.trim();
    final normalizedEmail = email.trim();
    final normalizedPhotoUrl = photoUrl?.trim();
    final displayName = '$normalizedFirstName $normalizedLastName'.trim();

    final profileRef = _firestore.collection('users').doc(authUser.id);
    final snapshot = await profileRef.get();
    final profileData = <String, dynamic>{
      'firstName': normalizedFirstName,
      'lastName': normalizedLastName,
      'phoneNumber': normalizedPhoneNumber,
      'email': normalizedEmail,
      'photoUrl': normalizedPhotoUrl,
      'profileComplete': true,
      'providerIds': authUser.providerIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!snapshot.exists) {
      profileData['createdAt'] = FieldValue.serverTimestamp();
    }

    await profileRef.set(profileData, SetOptions(merge: true));

    await user.updateDisplayName(displayName);
    await user.updatePhotoURL(normalizedPhotoUrl);
    await user.reload();
  }
}
