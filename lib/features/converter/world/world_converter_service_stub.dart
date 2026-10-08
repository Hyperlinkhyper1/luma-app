import '../../../l10n/current_l.dart';
import 'world_conversion.dart';

class WorldConverterService {
  bool get supported => false;

  Future<WorldCensus> inspect(String path) => Future.error(
    UnsupportedError(currentL.worldConvUnsupportedPlatform),
  );

  Future<String> availableDestination(String parent, String name) async =>
      '$parent/${worldFolderName(name)}';

  Future<WorldConversionResult> convert({
    required String source,
    required String destination,
    required WorldConversionOptions options,
    void Function(String)? onProgress,
  }) => Future.error(
    UnsupportedError(currentL.worldConvUnsupportedPlatform),
  );
}
