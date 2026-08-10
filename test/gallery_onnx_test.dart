
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/plugins/installed/gallery/gallery_smart.dart';
import 'package:luma/features/plugins/installed/gallery/onnx/gallery_model_store.dart';
import 'package:luma/features/plugins/installed/gallery/onnx/gallery_onnx_analyser.dart';
import 'package:luma/features/plugins/installed/gallery/onnx/imagenet_buckets.dart';

/// One anchor's worth of UltraFace output.
void _addFace(
  List<double> scores,
  List<double> boxes, {
  required double confidence,
  required double left,
  required double top,
  required double right,
  required double bottom,
}) {
  scores..add(1 - confidence)..add(confidence);
  boxes..add(left)..add(top)..add(right)..add(bottom);
}

/// Logits that make [index] the model's answer.
List<double> _logitsFavouring(int index, {double strength = 12}) {
  final logits = List<double>.filled(1000, 0);
  logits[index] = strength;
  return logits;
}

void main() {
  group('ImageNet buckets', () {
    test('the big WordNet runs land in the right album', () {
      // Dogs occupy 151–268 in ImageNet's ordering, cats 281–285.
      expect(bucketForImagenetClass(151), 'Pets'); // Chihuahua
      expect(bucketForImagenetClass(207), 'Pets'); // golden retriever
      expect(bucketForImagenetClass(268), 'Pets'); // Mexican hairless
      expect(bucketForImagenetClass(281), 'Pets'); // tabby
      expect(bucketForImagenetClass(285), 'Pets'); // Egyptian cat

      expect(bucketForImagenetClass(291), 'Animals'); // lion
      expect(bucketForImagenetClass(21), 'Animals'); // kite (a bird)

      expect(bucketForImagenetClass(933), 'Food'); // cheeseburger
      expect(bucketForImagenetClass(963), 'Food'); // pizza
      expect(bucketForImagenetClass(950), 'Food'); // orange

      expect(bucketForImagenetClass(970), 'Nature'); // alp
      expect(bucketForImagenetClass(978), 'Nature'); // seashore
      expect(bucketForImagenetClass(985), 'Nature'); // daisy
    });

    test('scattered object classes are picked out individually', () {
      expect(bucketForImagenetClass(817), 'Vehicles'); // sports car
      expect(bucketForImagenetClass(404), 'Vehicles'); // airliner
      expect(bucketForImagenetClass(497), 'City'); // church
      expect(bucketForImagenetClass(922), 'Documents'); // menu
    });

    test('classes nobody browses by map to nothing', () {
      expect(bucketForImagenetClass(700), isNull); // paper towel
      expect(bucketForImagenetClass(999), isNull); // toilet tissue
      expect(bucketForImagenetClass(-1), isNull);
      expect(bucketForImagenetClass(1000), isNull);
    });

    test('every bucket produced also exists on the ML Kit path', () {
      // Both platforms have to build the same albums, or a Windows user and
      // a phone user would see different tabs for the same photos.
      for (final bucket in imagenetBuckets) {
        expect(
          bucketForLabel(_mlKitExampleFor(bucket)),
          bucket,
          reason: '$bucket has no counterpart in the ML Kit label buckets',
        );
      }
    });
  });

  group('classifier post-processing', () {
    test('softmax turns logits into probabilities that sum to one', () {
      final probabilities = softmax([1, 2, 3, 4]);
      expect(probabilities.reduce((a, b) => a + b), closeTo(1, 1e-9));
      // Order is preserved and the largest logit wins.
      expect(probabilities.last, greaterThan(probabilities.first));
    });

    test('softmax survives the big logits a confident model emits', () {
      final probabilities = softmax([1000, 999, 1]);
      expect(probabilities.every((p) => p.isFinite), isTrue);
      expect(probabilities.reduce((a, b) => a + b), closeTo(1, 1e-9));
    });

    test('a confident class puts the photo in its album', () {
      expect(bucketsFromScores(_logitsFavouring(963)), contains('Food'));
      expect(bucketsFromScores(_logitsFavouring(207)), contains('Pets'));
    });

    test('a model that is unsure puts the photo nowhere', () {
      // A flat distribution over 1000 classes is 0.001 each — far below the
      // threshold, so nothing is claimed.
      expect(bucketsFromScores(List<double>.filled(1000, 1)), isEmpty);
    });

    test('an unmapped class wins without creating an album', () {
      expect(bucketsFromScores(_logitsFavouring(999)), isEmpty);
    });

    test('empty output is handled rather than thrown on', () {
      expect(bucketsFromScores(const []), isEmpty);
    });
  });

  group('face detector post-processing', () {
    test('a single face is reported once', () {
      final scores = <double>[];
      final boxes = <double>[];
      _addFace(scores, boxes,
          confidence: 0.95, left: 0.4, top: 0.3, right: 0.6, bottom: 0.7);
      expect(facesFromOutputs(scores, boxes), hasLength(1));
    });

    test('the same face found by several anchors is merged', () {
      // Every real face lights up a cluster of overlapping anchors; without
      // suppression a portrait would look like a crowd.
      final scores = <double>[];
      final boxes = <double>[];
      for (var i = 0; i < 8; i++) {
        _addFace(
          scores,
          boxes,
          confidence: 0.9,
          left: 0.40 + i * 0.002,
          top: 0.30 + i * 0.002,
          right: 0.60 + i * 0.002,
          bottom: 0.70 + i * 0.002,
        );
      }
      expect(facesFromOutputs(scores, boxes), hasLength(1));
    });

    test('faces far apart stay separate', () {
      final scores = <double>[];
      final boxes = <double>[];
      _addFace(scores, boxes,
          confidence: 0.9, left: 0.05, top: 0.3, right: 0.20, bottom: 0.6);
      _addFace(scores, boxes,
          confidence: 0.9, left: 0.45, top: 0.3, right: 0.60, bottom: 0.6);
      _addFace(scores, boxes,
          confidence: 0.9, left: 0.80, top: 0.3, right: 0.95, bottom: 0.6);
      expect(facesFromOutputs(scores, boxes), hasLength(3));
    });

    test('weak detections are dropped', () {
      final scores = <double>[];
      final boxes = <double>[];
      _addFace(scores, boxes,
          confidence: 0.2, left: 0.4, top: 0.3, right: 0.6, bottom: 0.7);
      expect(facesFromOutputs(scores, boxes), isEmpty);
    });

    test('a degenerate box is not a face', () {
      final scores = <double>[];
      final boxes = <double>[];
      _addFace(scores, boxes,
          confidence: 0.99, left: 0.5, top: 0.5, right: 0.5, bottom: 0.5);
      expect(facesFromOutputs(scores, boxes), isEmpty);
    });

    test('mismatched tensor lengths are tolerated', () {
      expect(facesFromOutputs(const [0.1, 0.9], const []), isEmpty);
      expect(facesFromOutputs(const [], const [0, 0, 1, 1]), isEmpty);
    });

    test('one big face is a selfie, two are not', () {
      expect(isSelfieShaped(const [0.45]), isTrue);
      expect(isSelfieShaped(const [0.10]), isFalse, reason: 'too far away');
      expect(isSelfieShaped(const [0.45, 0.40]), isFalse);
      expect(isSelfieShaped(const []), isFalse);
    });
  });

  group('pre-processing', () {
    test('the classifier gets a normalised 224 square, channel-first', () {
      final image = img.Image(width: 640, height: 480);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));

      final tensor = preprocessClassifier(image);
      expect(tensor.length, 3 * classifierSize * classifierSize);

      // Pure red, ImageNet-normalised: R is (1 - 0.485) / 0.229, G and B are
      // (0 - mean) / std. Channel-first means the three planes are contiguous.
      const plane = classifierSize * classifierSize;
      expect(tensor[0], closeTo((1 - 0.485) / 0.229, 0.01));
      expect(tensor[plane], closeTo((0 - 0.456) / 0.224, 0.01));
      expect(tensor[2 * plane], closeTo((0 - 0.406) / 0.225, 0.01));
    });

    test('a wide photo is centre-cropped, not squashed', () {
      // A 2:1 frame with a red left half and a blue right half: cropping to
      // the middle square keeps the seam in the centre of the tensor.
      final image = img.Image(width: 400, height: 200);
      img.fillRect(image,
          x1: 0, y1: 0, x2: 199, y2: 199, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(image,
          x1: 200, y1: 0, x2: 399, y2: 199, color: img.ColorRgb8(0, 0, 255));

      final tensor = preprocessClassifier(image);
      const plane = classifierSize * classifierSize;
      final row = (classifierSize ~/ 2) * classifierSize;
      // Left of centre is still red, right of centre is blue.
      expect(tensor[row + 10], greaterThan(0));
      expect(tensor[2 * plane + row + classifierSize - 10], greaterThan(0));
    });

    test('the face detector gets a 320x240 frame centred on 127', () {
      final image = img.Image(width: 800, height: 600);
      img.fill(image, color: img.ColorRgb8(127, 127, 127));

      final tensor = preprocessFaceDetector(image);
      expect(tensor.length, 3 * faceDetectorHeight * faceDetectorWidth);
      // Mid-grey is exactly the mean, so every value should be ~0.
      expect(tensor.every((v) => v.abs() < 0.01), isTrue);
    });

    test('a zero-sized image does not crash the preprocessor', () {
      final tensor = preprocessClassifier(img.Image(width: 1, height: 1));
      expect(tensor.length, 3 * classifierSize * classifierSize);
      expect(tensor.every((v) => v.isFinite), isTrue);
    });
  });

  group('model store', () {
    test('both models are named, sized and sourced', () {
      for (final model in GalleryModelStore.models) {
        expect(model.fileName, endsWith('.onnx'));
        expect(model.url, startsWith('https://'));
        expect(model.approximateBytes, greaterThan(0));
      }
      expect(GalleryModelStore.totalBytes, greaterThan(10 * 1024 * 1024));
      expect(GalleryModelStore.totalBytes, lessThan(30 * 1024 * 1024));
    });

    test('each platform gets exactly one analyser', () {
      // Two analysers claiming the same platform would look at every photo
      // twice; none claiming it would leave a platform with no smart albums
      // and no explanation.
      const phones = [TargetPlatform.android, TargetPlatform.iOS];
      const desktops = [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ];

      for (final platform in [...phones, ...desktops]) {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final mlKit = GallerySmartAnalyser.isSupported;
        final onnx = GalleryOnnxAnalyser.isSupported;
        expect(mlKit && onnx, isFalse, reason: '$platform claimed twice');
        expect(mlKit || onnx, isTrue, reason: '$platform claimed by neither');
        expect(GalleryAnalyser.isSupported, isTrue, reason: '$platform');
        // Only the desktops fetch their models; ML Kit's ship in the app.
        expect(
          GalleryAnalyser.needsDownload,
          desktops.contains(platform),
          reason: '$platform',
        );
      }
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

/// A label the ML Kit vocabulary would produce for each bucket, so the two
/// mappings can be checked against each other.
String _mlKitExampleFor(String bucket) => switch (bucket) {
      'Pets' => 'dog',
      'Animals' => 'bird',
      'Food' => 'pizza',
      'Nature' => 'flower',
      'City' => 'building',
      'Vehicles' => 'car',
      'Documents' => 'document',
      'Celebrations' => 'fireworks',
      'Art' => 'painting',
      _ => throw StateError('no ML Kit example for $bucket'),
    };

