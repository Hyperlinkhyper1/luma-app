/// Cross-platform facade for fetching Minecraft's block assets from Mojang.
///
/// luma bundles none of them. When the machine has no copy of the game to
/// borrow from, the user can ask for the vanilla client jar to be pulled from
/// Mojang's public CDN — the same unauthenticated endpoint every launcher
/// uses — and it is cached on their own disk from then on.
library;

export 'texture_downloader_stub.dart'
    if (dart.library.io) 'texture_downloader_io.dart';
