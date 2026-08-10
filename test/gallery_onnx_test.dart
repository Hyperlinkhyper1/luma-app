
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
      expect(bucketForImagenetClass(985), 'Nature'); // daisy
    });

    test('the landscape run splits between land and water', () {
      expect(bucketForImagenetClass(978), 'Ocean'); // seashore
      expect(bucketForImagenetClass(975), 'Ocean'); // lakeside
      expect(bucketForImagenetClass(970), 'Nature'); // alp
      expect(bucketForImagenetClass(980), 'Nature'); // volcano
    });

    test('scattered object classes are picked out individually', () {
      expect(bucketForImagenetClass(817), 'Transport'); // sports car
      expect(bucketForImagenetClass(404), 'Transport'); // airliner
      expect(bucketForImagenetClass(497), 'Architecture'); // church
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

    test('a photo can join more than one album from one pass', () {
      // A dog on a beach splits its confidence between the breed and the
      // scene; both are albums a person would look for it in, so the ranking
      // is walked rather than only its top entry.
      final logits = List<double>.filled(1000, 0);
      logits[207] = 6; // golden retriever
      logits[978] = 5.6; // seashore
      final buckets = bucketsFromScores(logits);
      expect(buckets, containsAll(<String>['Pets', 'Ocean']));
    });

    test('the ranking stops at the first class below the floor', () {
      // Only the leader is credible here; the runners-up must not drag their
      // albums in behind it.
      final logits = List<double>.filled(1000, 0);
      logits[963] = 20; // pizza, overwhelming
      logits[207] = 1; // a distant second
      expect(bucketsFromScores(logits), <String>{'Food'});
    });

    test('only the top few are considered, however many map', () {
      // Every class equally likely except a slight ordering: nothing clears
      // the floor, so no album gets everything in the library.
      final logits = [for (var i = 0; i < 1000; i++) 1 - i * 0.0001];
      expect(bucketsFromScores(logits), isEmpty);
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

    test('a long thin box is pattern, not a face', () {
      // UltraFace is a 1 MB model and will find a "face" in a plate of food.
      // A real face is roughly as tall as it is wide; slivers are rejected.
      final scores = <double>[];
      final boxes = <double>[];
      _addFace(scores, boxes,
          confidence: 0.99, left: 0.1, top: 0.4, right: 0.9, bottom: 0.5);
      expect(facesFromOutputs(scores, boxes), isEmpty,
          reason: 'a wide letterbox is not a face');

      scores.clear();
      boxes.clear();
      _addFace(scores, boxes,
          confidence: 0.99, left: 0.45, top: 0.05, right: 0.52, bottom: 0.95);
      expect(facesFromOutputs(scores, boxes), isEmpty,
          reason: 'a tall sliver is not a face');
    });

    test('a speck of background texture is not a face', () {
      final scores = <double>[];
      final boxes = <double>[];
      _addFace(scores, boxes,
          confidence: 0.99, left: 0.50, top: 0.50, right: 0.51, bottom: 0.51);
      expect(facesFromOutputs(scores, boxes), isEmpty);
    });

    test('a merely probable detection is not enough', () {
      // The reference threshold of 0.7 is what put a plate of eggs in the
      // Selfies album; the bar is higher now.
      final scores = <double>[];
      final boxes = <double>[];
      _addFace(scores, boxes,
          confidence: 0.75, left: 0.4, top: 0.3, right: 0.6, bottom: 0.6);
      expect(facesFromOutputs(scores, boxes), isEmpty);
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
          confidence: 0.95, left: 0.05, top: 0.3, right: 0.20, bottom: 0.5);
      _addFace(scores, boxes,
          confidence: 0.95, left: 0.45, top: 0.3, right: 0.60, bottom: 0.5);
      _addFace(scores, boxes,
          confidence: 0.95, left: 0.80, top: 0.3, right: 0.95, bottom: 0.5);
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

    test('one big centred face is a selfie; anything else is not', () {
      final centred = _faceAt(width: 0.45, centreX: 0.5, centreY: 0.45);
      expect(isSelfieShaped([centred]), isTrue);

      expect(
        isSelfieShaped([_faceAt(width: 0.10, centreX: 0.5, centreY: 0.5)]),
        isFalse,
        reason: 'too far away',
      );
      expect(
        isSelfieShaped([_faceAt(width: 0.45, centreX: 0.05, centreY: 0.5)]),
        isFalse,
        reason: 'a face wedged in the corner is a bystander, not the subject',
      );
      expect(
        isSelfieShaped([
          centred,
          _faceAt(width: 0.40, centreX: 0.7, centreY: 0.5),
        ]),
        isFalse,
      );
      expect(isSelfieShaped(const []), isFalse);
    });
  });

  group('sky and night, read from pixels', () {
    // Neither is an ImageNet object class — a clear sky isn't a "thing" the
    // classifier has a slot for — so these are read directly off the
    // thumbnail rather than asked of the model. Cheap, and it works the same
    // on both platforms.
    test('a blue upper third is sky', () {
      final image = img.Image(width: 100, height: 90);
      img.fillRect(image,
          x1: 0, y1: 0, x2: 99, y2: 29, color: img.ColorRgb8(120, 170, 230));
      img.fillRect(image,
          x1: 0, y1: 30, x2: 99, y2: 89, color: img.ColorRgb8(60, 140, 60));
      expect(hasSky(image), isTrue);
    });

    test('a green field with a strip of blue at the top is not', () {
      final image = img.Image(width: 100, height: 90);
      img.fill(image, color: img.ColorRgb8(60, 140, 60));
      // A blue lake occupying only a corner of the top third.
      img.fillRect(image,
          x1: 0, y1: 0, x2: 20, y2: 20, color: img.ColorRgb8(120, 170, 230));
      expect(hasSky(image), isFalse);
    });

    test('an indoor photo with no blue anywhere is not sky', () {
      final image = img.Image(width: 60, height: 60);
      img.fill(image, color: img.ColorRgb8(200, 190, 170));
      expect(hasSky(image), isFalse);
    });

    test('a mostly-dark frame with a light in it is a night shot', () {
      final image = img.Image(width: 80, height: 80);
      img.fill(image, color: img.ColorRgb8(8, 8, 10));
      img.fillRect(image,
          x1: 30, y1: 30, x2: 45, y2: 45, color: img.ColorRgb8(255, 230, 180));
      expect(isNightShot(image), isTrue);
    });

    test('a dark frame with nothing bright in it is underexposed, not night',
        () {
      // A lens cap or a failed exposure is not a "night" photo, even though
      // it is dark — nothing in it is a light source.
      final image = img.Image(width: 40, height: 40);
      img.fill(image, color: img.ColorRgb8(5, 5, 5));
      expect(isNightShot(image), isFalse);
    });

    test('a normally lit daytime photo is not night', () {
      final image = img.Image(width: 40, height: 40);
      img.fill(image, color: img.ColorRgb8(180, 180, 180));
      expect(isNightShot(image), isFalse);
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
    test('every model is named, sized and sourced', () {
      for (final model in GalleryModelStore.allModels) {
        expect(model.fileName, endsWith('.onnx'));
        expect(model.url, startsWith('https://'));
        expect(model.approximateBytes, greaterThan(0));
      }
      final total = GalleryModelStore.bytesFor(GalleryModelStore.allModels);
      expect(total, greaterThan(20 * 1024 * 1024));
      expect(total, lessThan(40 * 1024 * 1024));
    });

    test('the label models are desktop-only; the embedder is everywhere',
        () {
      expect(
        GalleryModelStore.labelModels,
        containsAll(<GalleryModel>[
          GalleryModelStore.classifier,
          GalleryModelStore.faceDetector,
        ]),
      );
      expect(GalleryModelStore.labelModels, isNot(contains(GalleryModelStore.embedder)));
      expect(GalleryModelStore.allModels, contains(GalleryModelStore.embedder));
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
/// A square-ish [GalleryFace] of the given size and centre, for tests that
/// only care about the selfie-shape heuristic and not the exact box.
GalleryFace _faceAt({
  required double width,
  required double centreX,
  required double centreY,
}) =>
    GalleryFace(
      left: centreX - width / 2,
      right: centreX + width / 2,
      top: centreY - width / 2,
      bottom: centreY + width / 2,
    );

String _mlKitExampleFor(String bucket) => switch (bucket) {
      'Pets' => 'dog',
      'Animals' => 'bird',
      'Food' => 'pizza',
      'Nature' => 'flower',
      'Ocean' => 'beach',
      'Sky' => 'sky',
      'Night' => 'night',
      'Architecture' => 'building',
      'Transport' => 'car',
      'Documents' => 'document',
      'Celebrations' => 'fireworks',
      'Art' => 'painting',
      _ => throw StateError('no ML Kit example for $bucket'),
    };

