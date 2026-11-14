import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  late final CloudinaryPublic _cloudinary;
  // Credentials come from --dart-define-from-file=dart_defines.json at build
  // time (see dart_defines.example.json); they are never stored in the repo.
  static const String _cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const String _uploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: 'dino_tracker');
  static const String _apiKey = String.fromEnvironment('CLOUDINARY_API_KEY');
  static const String _apiSecret = String.fromEnvironment('CLOUDINARY_API_SECRET');

  factory CloudinaryService() {
    return _instance;
  }

  CloudinaryService._internal() {
    _cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
  }

  /// Uploads an image to Cloudinary with proper organization
  ///
  /// Parameters:
  /// - imageFile: The file to upload
  /// - baseFolder: Base folder path (e.g., 'recycling_records', 'challenge_checkins')
  /// - metadata: Optional map of metadata for better organization
  Future<String> uploadImage(File imageFile, String baseFolder, {Map<String, dynamic>? metadata}) async {
    try {
      // Generate a structured folder path based on challenge type and date
      String folderPath = baseFolder;
      bool isDefaultChallenge = metadata?['isDefaultChallenge'] == true;
      bool isReported = metadata?['isReported'] == true;
      String userId = metadata?['userId'] ?? 'unknown_user';
      String challengeId = metadata?['challengeId'] ?? '';

      // Create nested folder structure for better organization
      if (baseFolder == 'challenge_checkins') {
        // Format: challenge_checkins/[default|user]/[challengeId]/[userId]
        String challengeType = isDefaultChallenge ? 'default' : 'user';
        folderPath = '$baseFolder/$challengeType';

        // Add challengeId if available
        if (challengeId.isNotEmpty) {
          folderPath = '$folderPath/$challengeId';
        }

        // Add userId for final level of nesting
        folderPath = '$folderPath/$userId';
      } else if (baseFolder == 'recycling_records') {
        // For recycling records, just organize by user
        folderPath = '$baseFolder/$userId';
      }

      // Prepare tags for easy filtering in Cloudinary dashboard
      List<String> tags = [baseFolder];

      if (metadata != null) {
        if (baseFolder == 'challenge_checkins') {
          tags.add(isDefaultChallenge ? 'default_challenge' : 'user_challenge');
          if (isReported) tags.add('reported');
          if (challengeId.isNotEmpty) tags.add('challenge_$challengeId');
        }
        tags.add('user_$userId');
      }

      // Prepare context metadata for Cloudinary
      Map<String, String> context = {};
      metadata?.forEach((key, value) {
        if (value != null) {
          context[key] = value.toString();
        }
      });

      // Add timestamp to allow sorting by upload date
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      context['timestamp'] = timestamp;

      // Upload with the structured organization
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folderPath,
          resourceType: CloudinaryResourceType.Image,
          tags: tags,
          context: context,
          // Set public_id to include timestamp for uniqueness
          publicId: 'img_${timestamp}_${userId.substring(0, min(6, userId.length))}',
        ),
      );

      return response.secureUrl;
    } catch (e) {
      print("Error uploading to Cloudinary: $e");
      rethrow;
    }
  }

  Future<void> markImageAsReported(String imageUrl, {String reason = ''}) async {
    try {
      final publicId = _extractPublicId(imageUrl);
      await _updateTag('add', publicId, 'reported');
    } catch (e) {
      print("Error marking image as reported in Cloudinary: $e");
      // Non-fatal — report status is tracked in Firestore.
    }
  }

  Future<void> approveReportedImage(String imageUrl) async {
    try {
      final publicId = _extractPublicId(imageUrl);
      await _updateTag('remove', publicId, 'reported');
    } catch (e) {
      print("Error approving image tag in Cloudinary: $e");
    }
  }

  Future<void> rejectReportedImage(String imageUrl) async {
    try {
      final publicId = _extractPublicId(imageUrl);
      await _updateTag('add', publicId, 'rejected');
    } catch (e) {
      print("Error rejecting image tag in Cloudinary: $e");
    }
  }

  Future<void> _updateTag(String command, String publicId, String tag) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final params = <String, String>{
      'command': command,
      'public_ids': publicId,
      'tag': tag,
      'timestamp': timestamp.toString(),
    };

    final keys = params.keys.toList()..sort();
    final signString =
        keys.map((k) => '$k=${params[k]}').join('&') + _apiSecret;
    final signature =
        sha1.convert(utf8.encode(signString)).toString();

    params['api_key'] = _apiKey;
    params['signature'] = signature;

    final response = await http.post(
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/tags'),
      body: params,
    );

    if (response.statusCode != 200) {
      throw Exception('Cloudinary tag update failed: ${response.body}');
    }
  }

  /// Deletes an image from Cloudinary
  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extract public ID
      final publicId = _extractPublicId(imageUrl);

      // Generate timestamp for authentication
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();

      // For deletion, we need to use the destroy API
      var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/destroy')
      );

      // Required parameters
      request.fields['api_key'] = _apiKey;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['public_id'] = publicId;

      // Generate signature
      String signString = "public_id=$publicId&timestamp=$timestamp$_apiSecret";
      final bytes = utf8.encode(signString);
      final digest = sha1.convert(bytes);
      request.fields['signature'] = digest.toString();

      print("Debug - String to sign: $signString"); // Debug log
      print("Debug - Generated signature: ${digest.toString()}"); // Debug log

      var response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        print("Cloudinary API Error: $respStr");
        throw Exception('Failed to delete image: $respStr');
      }

      print("Image deleted: $publicId");
    } catch (e) {
      print("Error deleting image from Cloudinary: $e");
      rethrow;
    }
  }

  /// Extracts the public ID from a Cloudinary URL
  String _extractPublicId(String imageUrl) {
    try {
      print("Debug - Extracting public ID from URL: $imageUrl"); // Debug log
      
      // Extract public ID from the URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      print("Debug - Path segments: $pathSegments"); // Debug log

      // Find the index of 'upload' in the path
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex >= pathSegments.length - 1) {
        throw Exception('Invalid Cloudinary URL format');
      }

      // Get the segments after 'upload', usually version number followed by path
      final segments = pathSegments.sublist(uploadIndex + 1);
      print("Debug - Segments after upload: $segments"); // Debug log

      // If the first segment is a version number (v1234567890), remove it
      String publicId;
      if (segments.isNotEmpty && segments.first.startsWith('v') && RegExp(r'^v\d+$').hasMatch(segments.first)) {
        publicId = segments.sublist(1).join('/');
      } else {
        publicId = segments.join('/');
      }

      // Remove file extension if present
      publicId = publicId.replaceAll(RegExp(r'\.[^/.]+$'), '');
      print("Debug - Extracted public ID: $publicId"); // Debug log

      return publicId;
    } catch (e) {
      print("Error extracting public ID from URL: $e");
      print("Problematic URL: $imageUrl");
      rethrow;
    }
  }

  /// Helper function to get min of two integers
  int min(int a, int b) {
    return a < b ? a : b;
  }
}