import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exif/exif.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../models/photo_post.dart';

class PhotoService {
  PhotoService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    Uuid? uuid,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _httpClient = httpClient ?? http.Client(),
        _uuid = uuid ?? const Uuid();

  static const _cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const _uploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');
  static const _deleteEndpoint =
      String.fromEnvironment('CLOUDINARY_DELETE_ENDPOINT');

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final http.Client _httpClient;
  final Uuid _uuid;

  Stream<List<PhotoPost>> watchGroupPosts(String groupId) {
    return _firestore
        .collection('posts')
        .where('groupId', isEqualTo: groupId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(PhotoPost.fromSnapshot).toList(growable: false),
        );
  }

  Future<int> pickCompressAndUpload(
    BuildContext context,
    String groupId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be signed in.');
    }

    final permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: true,
        ),
      ),
    );
    if (!permission.hasAccess) {
      throw StateError('Allow photo access to upload images.');
    }
    if (!context.mounted) return 0;

    final List<AssetEntity>? picked;
    try {
      picked = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 50,
          requestType: RequestType.image,
        ),
      );
    } on StateError catch (error) {
      throw StateError('Could not open gallery permissions: ${error.message}');
    }
    if (picked == null || picked.isEmpty) return 0;

    var uploadedCount = 0;
    for (final asset in picked) {
      await _uploadAsset(asset: asset, groupId: groupId, user: user);
      uploadedCount += 1;
    }

    return uploadedCount;
  }

  Future<void> _uploadAsset({
    required AssetEntity asset,
    required String groupId,
    required User user,
  }) async {
    final file = await asset.file;
    if (file == null) {
      throw StateError('Could not open the selected image.');
    }

    final filename = _safeFilename(
      asset.title ?? p.basename(file.path),
      file.path,
    );
    final sourceFile = file;
    final originalBytes = await sourceFile.readAsBytes();
    final takenOn = await _readOriginalTakenDate(
      bytes: originalBytes,
      fallbackFile: sourceFile,
      mediaStoreDate: asset.createDateTime,
    );
    final compressed = await _compressImage(sourceFile);
    final dimensions = await _readImageDimensions(compressed);
    final postId = _uuid.v4();
    final upload = await _uploadToCloudinary(
      bytes: compressed,
      filename: filename,
    );

    await _firestore.collection('posts').doc(postId).set({
      'imageUrl': upload.secureUrl,
      'uploadedAt': FieldValue.serverTimestamp(),
      'uploadedBy': user.uid,
      'uploaderName':
          user.displayName ?? user.email?.split('@').first ?? 'Friend',
      'groupId': groupId,
      'cloudinaryPublicId': upload.publicId,
      if (upload.deleteToken != null)
        'cloudinaryDeleteToken': upload.deleteToken,
      'originalFileName': filename,
      'fileSizeBytes': compressed.length,
      'width': dimensions.width,
      'height': dimensions.height,
      'takenOn': Timestamp.fromDate(takenOn),
    });
  }

  bool canCurrentUserDelete(PhotoPost post) {
    return _auth.currentUser?.uid == post.uploadedBy;
  }

  Future<DeletePhotoResult> deletePhoto(PhotoPost post) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be signed in.');
    }
    if (user.uid != post.uploadedBy) {
      throw StateError('Only the uploader can delete this photo.');
    }

    if (_deleteEndpoint.isNotEmpty) {
      return _deleteWithBackend(user: user, post: post);
    }

    var cloudinaryDeleted = false;
    final token = post.cloudinaryDeleteToken;
    if (token != null && token.isNotEmpty) {
      cloudinaryDeleted = await _deleteFromCloudinary(token);
    }

    await _firestore.collection('posts').doc(post.id).delete();
    return DeletePhotoResult(cloudinaryDeleted: cloudinaryDeleted);
  }

  Future<DeletePhotoResult> _deleteWithBackend({
    required User user,
    required PhotoPost post,
  }) async {
    final token = await user.getIdToken();
    final response = await _httpClient.post(
      Uri.parse(_deleteEndpoint),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'postId': post.id,
        'cloudinaryPublicId': post.cloudinaryPublicId,
      }),
    );

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['error'] ?? 'Could not delete this photo.'
          : 'Could not delete this photo.';
      throw StateError(message.toString());
    }

    final cloudinaryDeleted =
        decoded is Map<String, dynamic> && decoded['cloudinaryDeleted'] == true;
    return DeletePhotoResult(cloudinaryDeleted: cloudinaryDeleted);
  }

  Future<void> downloadToGallery(PhotoPost post) async {
    final response = await _httpClient.get(Uri.parse(post.imageUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Could not download this photo.');
    }

    final name = post.originalFileName == null
        ? 'barkada_${post.id}'
        : p.basenameWithoutExtension(post.originalFileName!);

    await ImageGallerySaverPlus.saveImage(
      response.bodyBytes,
      quality: 100,
      name: name,
    );
  }

  Future<bool> _deleteFromCloudinary(String deleteToken) async {
    final uri =
        Uri.https('api.cloudinary.com', '/v1_1/$_cloudName/delete_by_token');
    final response = await _httpClient.post(uri, body: {'token': deleteToken});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return false;
    return decoded['result'] == 'ok';
  }

  Future<_CloudinaryUpload> _uploadToCloudinary({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw StateError(
        'Cloudinary is not configured. Run with '
        '--dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name and '
        '--dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset.',
      );
    }

    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$_cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'error': 'Cloudinary upload failed.'};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['error'] is Map<String, dynamic>
          ? data['error']['message']
          : 'Cloudinary upload failed.';
      throw StateError(message.toString());
    }

    return _CloudinaryUpload(
      secureUrl: data['secure_url'] as String,
      publicId: data['public_id'] as String,
      deleteToken: data['delete_token'] as String?,
    );
  }

  Future<Uint8List> _compressImage(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    final format =
        extension == '.png' ? CompressFormat.png : CompressFormat.jpeg;
    final quality = format == CompressFormat.png ? 85 : 78;

    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 1600,
      minHeight: 1600,
      quality: quality,
      format: format,
      keepExif: false,
    );

    if (result == null || result.isEmpty) {
      throw StateError('Could not compress the selected image.');
    }

    return result;
  }

  Future<_ImageDimensions> _readImageDimensions(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final dimensions =
        _ImageDimensions(width: image.width, height: image.height);
    image.dispose();
    codec.dispose();
    return dimensions;
  }

  Future<DateTime> _readOriginalTakenDate({
    required Uint8List bytes,
    required File fallbackFile,
    required DateTime mediaStoreDate,
  }) async {
    final normalizedMediaDate = _normalizeDate(mediaStoreDate);
    if (normalizedMediaDate != null) return normalizedMediaDate;

    try {
      final exif = await readExifFromBytes(bytes);
      final rawDate = exif['EXIF DateTimeOriginal']?.printable ??
          exif['EXIF DateTimeDigitized']?.printable ??
          exif['Image DateTime']?.printable;
      final parsed = _parseExifDate(rawDate);
      if (parsed != null) return parsed;
    } catch (_) {
      // Some edited/downloaded images do not contain readable EXIF metadata.
    }

    return _safeLastModified(fallbackFile);
  }

  DateTime? _normalizeDate(DateTime date) {
    if (date.millisecondsSinceEpoch <= 0) return null;
    if (date.year < 1971) return null;
    return date;
  }

  DateTime? _parseExifDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final match = RegExp(
      r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(value.trim());
    if (match == null) return null;

    final parts = List.generate(
      6,
      (index) => int.tryParse(match.group(index + 1) ?? ''),
    );
    if (parts.any((part) => part == null)) return null;

    return DateTime(
      parts[0]!,
      parts[1]!,
      parts[2]!,
      parts[3]!,
      parts[4]!,
      parts[5]!,
    );
  }

  Future<DateTime> _safeLastModified(File file) async {
    try {
      return await file.lastModified();
    } catch (_) {
      return DateTime.now();
    }
  }

  String _safeFilename(String pickedName, String path) {
    final fallback = p.basename(path);
    final name = pickedName.trim().isEmpty ? fallback : pickedName.trim();
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}

class _CloudinaryUpload {
  const _CloudinaryUpload({
    required this.secureUrl,
    required this.publicId,
    required this.deleteToken,
  });

  final String secureUrl;
  final String publicId;
  final String? deleteToken;
}

class DeletePhotoResult {
  const DeletePhotoResult({required this.cloudinaryDeleted});

  final bool cloudinaryDeleted;
}

class _ImageDimensions {
  const _ImageDimensions({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}
