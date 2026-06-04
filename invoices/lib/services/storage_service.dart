import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadLogo(String userId, dynamic file) async {
    final ref = _storage.ref().child('users/$userId/logo.jpg');

    UploadTask task;
    if (kIsWeb) {
      final bytes = file as Uint8List;
      task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      task = ref.putFile(file as File);
    }

    await task;
    return await ref.getDownloadURL();
  }

  Future<void> deleteLogo(String userId) async {
    try {
      await _storage.ref().child('users/$userId/logo.jpg').delete();
    } catch (_) {}
  }
}
