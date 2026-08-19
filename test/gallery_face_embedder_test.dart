import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/plugins/installed/gallery/onnx/gallery_face_embedder.dart';
import 'package:luma/features/plugins/installed/gallery/onnx/gallery_onnx_analyser.dart';

void main() {
  group('cropFace', () {
    test('a centred box crops to the model input size', () {
      final image = img.Image(width: 200, height: 200);
      const box = GalleryFace(left: 0.3, top: 0.3, right: 0.7, bottom: 0.7);
      final crop = cropFace(image, box);
      expect(crop, isNotNull);
      expect(crop!.width, faceEmbedInputSize);
      expect(crop.height, faceEmbedInputSize);
    });

    test('the crop is wider than the raw box, not a tight cut', () {
      // A face crop with no margin cuts off the chin and forehead — real
      // recognition pipelines always pad around the box.
      final image = img.Image(width: 1000, height: 1000);
      img.fill(image, color: img.ColorRgb8(10, 10, 10));
      img.fillRect(
        image,
        x1: 400, y1: 400, x2: 599, y2: 599,
        color: img.ColorRgb8(250, 250, 250),
      );
      const box = GalleryFace(left: 0.4, top: 0.4, right: 0.6, bottom: 0.6);
      final crop = cropFace(image, box)!;
      // The face fills the middle third of the box's own width; well inside
      // a padded crop but outside a crop with no margin at all.
      final corner = crop.getPixel(2, 2);
      expect(corner.r, lessThan(50), reason: 'padding should still be dark');
    });

    test('a box collapsed to a single point produces no crop', () {
      // Width and height both zero — the square-from-max-dimension logic
      // that lets a merely thin box still crop something has nothing to
      // work with here.
      final image = img.Image(width: 100, height: 100);
      const point = GalleryFace(left: 0.5, top: 0.5, right: 0.5, bottom: 0.5);
      expect(cropFace(image, point), isNull);
    });

    test('a box thin in only one dimension still crops a square', () {
      // The crop side comes from whichever of width/height is larger, so a
      // wide-but-flat detection (a common false-positive shape) still
      // produces something to embed rather than nothing.
      final image = img.Image(width: 100, height: 100);
      const thin = GalleryFace(left: 0.3, top: 0.5, right: 0.7, bottom: 0.5);
      expect(cropFace(image, thin), isNotNull);
    });

    test('a box at the very corner is clamped, not thrown on', () {
      final image = img.Image(width: 100, height: 100);
      const corner = GalleryFace(left: -0.1, top: -0.1, right: 0.1, bottom: 0.1);
      final crop = cropFace(image, corner);
      expect(crop, isNotNull);
      expect(crop!.width, faceEmbedInputSize);
    });

    test('a box past the far edge is clamped to the frame', () {
      final image = img.Image(width: 100, height: 100);
      const edge = GalleryFace(left: 0.9, top: 0.9, right: 1.4, bottom: 1.4);
      final crop = cropFace(image, edge);
      expect(crop, isNotNull);
    });
  });

  group('preprocessFaceEmbedding', () {
    test('produces one plane per channel, matching the classifier layout',
        () {
      final face = img.Image(width: faceEmbedInputSize, height: faceEmbedInputSize);
      img.fill(face, color: img.ColorRgb8(200, 100, 50));
      final tensor = preprocessFaceEmbedding(face);

      expect(tensor.length, 3 * faceEmbedInputSize * faceEmbedInputSize);
      const plane = faceEmbedInputSize * faceEmbedInputSize;
      // SFace's own preprocessing is raw 0..255 values, no division and no
      // mean subtraction — unusual, but that's what its C++ reference does.
      expect(tensor[0], 200);
      expect(tensor[plane], 100);
      expect(tensor[2 * plane], 50);
    });

    test('values stay in the raw 0..255 range, never normalised to 0..1', () {
      final face = img.Image(width: faceEmbedInputSize, height: faceEmbedInputSize);
      img.fill(face, color: img.ColorRgb8(255, 0, 128));
      final tensor = preprocessFaceEmbedding(face);
      expect(tensor.reduce((a, b) => a > b ? a : b), 255);
      expect(tensor.every((v) => v >= 0 && v <= 255), isTrue);
    });
  });
}
