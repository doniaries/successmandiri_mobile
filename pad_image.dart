import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/images/logo.png');
  final originalImage = img.decodeImage(file.readAsBytesSync());
  
  if (originalImage == null) return;

  // Make the new image size 2.5x the original so the logo is much smaller inside
  int newSize = (originalImage.width > originalImage.height ? originalImage.width : originalImage.height) * 2;
  
  // Create a blank image with transparent background
  final newImage = img.Image(width: newSize, height: newSize, numChannels: 4);
  img.fill(newImage, color: img.ColorRgba8(255, 255, 255, 0));

  // Calculate position to center the original image
  int offsetX = (newSize - originalImage.width) ~/ 2;
  int offsetY = (newSize - originalImage.height) ~/ 2;

  // Paste original image onto the center of the new image
  img.compositeImage(newImage, originalImage, dstX: offsetX, dstY: offsetY);

  // Save the result
  File('assets/images/logo_splash.png').writeAsBytesSync(img.encodePng(newImage));
  print('Success! Padding added.');
}
