import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> generateThumbnail(String videoUrl) async {
  try {
    // Get the temporary directory of the device
    final tempDir = await getTemporaryDirectory();

    // Generate the thumbnail and save it as a file
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: videoUrl,
      thumbnailPath: tempDir.path, // Path where the thumbnail will be saved
      imageFormat: ImageFormat.PNG, // Can be PNG, JPEG, or WEBP
      maxHeight: 200, // Optional, specify the thumbnail height
      maxWidth: 200, // Optional, specify the thumbnail width
      quality: 75, // Optional, specify the quality (0-100)
    );

    return thumbnailPath; // Return the path of the saved thumbnail
  } catch (e) {
    return null; // Return null if an error occurs
  }
}
