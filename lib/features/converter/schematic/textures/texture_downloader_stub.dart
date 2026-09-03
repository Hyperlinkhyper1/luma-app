import 'texture_pack_types.dart';

/// Web stub: there is nowhere to put a downloaded jar, so the preview stays on
/// its flat block colours.

Future<String> downloadVanillaTextures({
  void Function(TextureDownloadProgress)? onProgress,
}) async =>
    throw TextureDownloadException(
      'Block textures can only be downloaded on desktop and Android.',
    );

const int kApproximateClientJarBytes = 0;
