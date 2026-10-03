import 'world_conversion.dart';

class WorldConverterService {
  bool get supported => false;

  Future<WorldCensus> inspect(String path) => Future.error(
    UnsupportedError('World conversion requires Windows or Linux.'),
  );

  Future<WorldConversionResult> convert({
    required String source,
    required String destination,
    required WorldConversionOptions options,
    void Function(String)? onProgress,
  }) => Future.error(
    UnsupportedError('World conversion requires Windows or Linux.'),
  );
}
