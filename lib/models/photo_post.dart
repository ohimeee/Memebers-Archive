import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoPost {
  const PhotoPost({
    required this.id,
    required this.imageUrl,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.uploaderName,
    required this.groupId,
    required this.originalFileName,
    required this.fileSizeBytes,
    required this.width,
    required this.height,
    required this.takenOn,
    required this.cloudinaryDeleteToken,
  });

  final String id;
  final String imageUrl;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String uploaderName;
  final String groupId;
  final String? originalFileName;
  final int? fileSizeBytes;
  final int? width;
  final int? height;
  final DateTime? takenOn;
  final String? cloudinaryDeleteToken;

  factory PhotoPost.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final timestamp = data['uploadedAt'] as Timestamp?;
    final takenOn = data['takenOn'] as Timestamp?;

    return PhotoPost(
      id: snapshot.id,
      imageUrl: data['imageUrl'] as String? ?? '',
      uploadedAt: timestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      uploadedBy: data['uploadedBy'] as String? ?? '',
      uploaderName: data['uploaderName'] as String? ?? 'Friend',
      groupId: data['groupId'] as String? ?? '',
      originalFileName: data['originalFileName'] as String?,
      fileSizeBytes: data['fileSizeBytes'] as int?,
      width: data['width'] as int?,
      height: data['height'] as int?,
      takenOn: takenOn?.toDate(),
      cloudinaryDeleteToken: data['cloudinaryDeleteToken'] as String?,
    );
  }
}
