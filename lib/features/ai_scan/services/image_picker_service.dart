import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Picks food images at a size suitable for AI analysis.
///
/// Keeping the image around 1280px on its longest side substantially reduces
/// upload size and memory pressure while retaining enough detail for food
/// recognition. The original camera/gallery file is not modified on disk.
class ImagePickerService {
  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const int _maxImageDimension = 1280;
  static const int _imageQuality = 78;

  Future<File?> pickFromCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: _imageQuality,
      maxWidth: _maxImageDimension.toDouble(),
      maxHeight: _maxImageDimension.toDouble(),
      preferredCameraDevice: CameraDevice.rear,
    );

    if (image == null) return null;
    return File(image.path);
  }

  Future<File?> pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: _imageQuality,
      maxWidth: _maxImageDimension.toDouble(),
      maxHeight: _maxImageDimension.toDouble(),
    );

    if (image == null) return null;
    return File(image.path);
  }
}
