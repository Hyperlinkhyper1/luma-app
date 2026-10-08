import '../../../../l10n/current_l.dart';
import 'texture_pack_types.dart';

/// Web stub: there is nowhere to put a downloaded jar, so the preview stays on
/// its flat block colours.

Future<String> downloadVanillaTextures({
  void Function(TextureDownloadProgress)? onProgress,
}) async =>
    throw TextureDownloadException(currentL.textureDownloadUnsupported);

const int kApproximateClientJarBytes = 0;
