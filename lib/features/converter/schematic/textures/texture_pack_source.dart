/// Cross-platform facade for finding and reading Minecraft block assets.
///
/// luma ships no Minecraft textures — they belong to Mojang and are not ours
/// to redistribute. The preview reads them from a copy of the game already on
/// the machine instead: the one luma's Minecraft launcher plugin downloaded, a
/// standard `.minecraft` install, or a jar the user points at.
library;

export 'texture_pack_types.dart';
export 'texture_pack_source_stub.dart'
    if (dart.library.io) 'texture_pack_source_io.dart';
