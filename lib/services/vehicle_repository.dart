import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../data/demo_data.dart';
import '../models/rental_models.dart';

class UploadedVehicleImage {
  const UploadedVehicleImage({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}

abstract class VehicleRepository {
  Stream<List<Vehicle>> watchVehicles();

  Future<void> seedVehiclesIfEmpty();

  Future<void> syncVehiclesFromSeedData();

  Future<UploadedVehicleImage> uploadVehicleImage({
    required String vehicleId,
    required XFile image,
  });

  Future<List<UploadedVehicleImage>> uploadVehicleGalleryImages({
    required String vehicleId,
    required List<XFile> images,
  });

  Future<void> saveVehicle(Vehicle vehicle);

  Future<void> deleteVehicle(Vehicle vehicle);
}

class FirebaseVehicleRepository implements VehicleRepository {
  static const int _maxUploadDimension = 1600;
  static const int _uploadQuality = 82;

  FirebaseVehicleRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _vehiclesCollection =>
      _firestore.collection('vehicles');

  @override
  Stream<List<Vehicle>> watchVehicles() {
    return _vehiclesCollection
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          final vehicles = snapshot.docs.map((doc) {
            final data = doc.data();
            return Vehicle.fromMap({
              ...data,
              'id': data['id'] ?? doc.id,
            });
          }).toList();
          if (vehicles.isEmpty) {
            return demoVehicles;
          }
          return vehicles;
        });
  }

  @override
  Future<void> seedVehiclesIfEmpty() async {
    final snapshot = await _vehiclesCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final vehicle in demoVehicles) {
      batch.set(_vehiclesCollection.doc(vehicle.id), vehicle.toMap());
    }
    await batch.commit();
  }

  @override
  Future<void> syncVehiclesFromSeedData() async {
    final batch = _firestore.batch();
    for (final vehicle in demoVehicles) {
      final imageUrl = await _ensureVehicleImageUrl(vehicle.imageUrl);
      final syncedVehicle = Vehicle(
        id: vehicle.id,
        name: vehicle.name,
        type: vehicle.type,
        imageUrl: imageUrl,
        location: vehicle.location,
        description: vehicle.description,
        seats: vehicle.seats,
        transmission: vehicle.transmission,
        energy: vehicle.energy,
        rating: vehicle.rating,
        availableNow: vehicle.availableNow,
        inventoryCount: vehicle.inventoryCount,
        rates: vehicle.rates,
        imageStoragePath: 'vehicles/${vehicle.imageUrl.split('/').last}',
      );
      batch.set(
        _vehiclesCollection.doc(vehicle.id),
        syncedVehicle.toMap(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    debugPrint('Vehicle sync complete: Firestore vehicles updated with Storage image URLs.');
  }

  @override
  Future<UploadedVehicleImage> uploadVehicleImage({
    required String vehicleId,
    required XFile image,
  }) async {
    final originalExtension = image.name.contains('.') ? image.name.split('.').last : 'jpg';
    final normalizedExtension = _normalizedUploadExtension(originalExtension);
    final uploadBytes = await _optimizedUploadBytes(image, normalizedExtension);
    final storagePath = 'vehicles/$vehicleId.$normalizedExtension';
    final ref = _storage.ref().child(storagePath);
    final metadata = SettableMetadata(
      contentType: _contentTypeForExtension(normalizedExtension),
    );

    await ref.putData(uploadBytes, metadata);

    return UploadedVehicleImage(
      downloadUrl: await ref.getDownloadURL(),
      storagePath: storagePath,
    );
  }

  @override
  Future<List<UploadedVehicleImage>> uploadVehicleGalleryImages({
    required String vehicleId,
    required List<XFile> images,
  }) async {
    final uploads = <UploadedVehicleImage>[];
    for (var index = 0; index < images.length; index++) {
      uploads.add(
        await uploadVehicleImage(
          vehicleId: '${vehicleId}_gallery_${index + 1}',
          image: images[index],
        ),
      );
    }
    return uploads;
  }

  Future<Uint8List> _optimizedUploadBytes(XFile image, String extension) async {
    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return bytes;
    }

    final resized = _resizeForUpload(decoded);
    return switch (extension) {
      'png' => Uint8List.fromList(
          img.encodePng(
            resized,
            level: 6,
          ),
        ),
      _ => Uint8List.fromList(
          img.encodeJpg(
            resized,
            quality: _uploadQuality,
          ),
        ),
    };
  }

  img.Image _resizeForUpload(img.Image source) {
    final width = source.width;
    final height = source.height;
    final longestEdge = width > height ? width : height;

    if (longestEdge <= _maxUploadDimension) {
      return source;
    }

    if (width >= height) {
      return img.copyResize(
        source,
        width: _maxUploadDimension,
        interpolation: img.Interpolation.average,
      );
    }

    return img.copyResize(
      source,
      height: _maxUploadDimension,
      interpolation: img.Interpolation.average,
    );
  }

  @override
  Future<void> saveVehicle(Vehicle vehicle) async {
    await _vehiclesCollection.doc(vehicle.id).set(vehicle.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteVehicle(Vehicle vehicle) async {
    await _vehiclesCollection.doc(vehicle.id).delete();
    final storagePath = vehicle.imageStoragePath?.trim() ?? '';
    if (storagePath.isEmpty) {
      return;
    }

    try {
      await _storage.ref().child(storagePath).delete();
    } catch (_) {
      debugPrint('Vehicle deleted, but image cleanup failed for $storagePath.');
    }
  }

  Future<String> _ensureVehicleImageUrl(String assetPath) async {
    if (!assetPath.startsWith('assets/')) {
      return assetPath;
    }

    final fileName = assetPath.split('/').last;
    final ref = _storage.ref().child('vehicles/$fileName');
    try {
      final url = await ref.getDownloadURL();
      debugPrint('Vehicle image already in Storage: $fileName');
      return url;
    } catch (_) {
      final bytes = await rootBundle.load(assetPath);
      await ref.putData(
        bytes.buffer.asUint8List(),
        SettableMetadata(contentType: _contentTypeFor(fileName)),
      );
      final url = await ref.getDownloadURL();
      debugPrint('Vehicle image uploaded to Storage: $fileName');
      return url;
    }
  }

  String _contentTypeFor(String fileName) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.png')) {
      return 'image/png';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  String _normalizedUploadExtension(String extension) {
    final normalized = extension.toLowerCase();
    if (normalized == 'png') {
      return normalized;
    }
    return 'jpg';
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
