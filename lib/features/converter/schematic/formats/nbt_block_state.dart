import '../nbt.dart';
import '../schematic_model.dart';

/// Litematica, vanilla structures and Bedrock structures all store a palette
/// entry the same way — a name plus a compound of properties — so the two
/// conversions live here rather than three times over.

/// Reads a `{Name: "...", Properties: {...}}` compound into a [BlockState].
///
/// [nameKey] and [propertiesKey] differ per format: Java uses `Name`/
/// `Properties`, Bedrock uses `name`/`states`.
BlockState blockStateFromNbt(
  NbtCompound tag, {
  String nameKey = 'Name',
  String propertiesKey = 'Properties',
}) {
  final name = tag.stringValue(nameKey) ?? 'minecraft:air';
  final props = <String, String>{};
  final propsTag = tag.compound(propertiesKey);
  if (propsTag != null) {
    propsTag.values.forEach((key, value) {
      final text = switch (value) {
        NbtString(value: final v) => v,
        NbtByte(value: final v) => '$v',
        NbtShort(value: final v) => '$v',
        NbtInt(value: final v) => '$v',
        NbtLong(value: final v) => '$v',
        _ => null,
      };
      if (text != null) props[key] = text;
    });
  }
  return BlockState(name, props);
}

/// Writes a [BlockState] back out as a `{Name, Properties}` compound.
///
/// Java keeps every property as a string. Bedrock is strict about types —
/// a `*_bit` flag has to be a byte and a direction has to be an int, or the
/// game rejects the structure — so [typedValues] re-types them on the way out.
NbtCompound blockStateToNbt(
  BlockState state, {
  String nameKey = 'Name',
  String propertiesKey = 'Properties',
  bool typedValues = false,
  bool omitEmptyProperties = true,
}) {
  final out = NbtCompound.empty();
  out[nameKey] = NbtString(state.name);
  if (state.properties.isEmpty && omitEmptyProperties) return out;

  final props = NbtCompound.empty();
  final keys = state.properties.keys.toList()..sort();
  for (final key in keys) {
    final value = state.properties[key]!;
    if (!typedValues) {
      props[key] = NbtString(value);
      continue;
    }
    if (key.endsWith('_bit')) {
      props[key] = NbtByte(value == '1' || value == 'true' ? 1 : 0);
    } else if (value == 'true' || value == 'false') {
      props[key] = NbtByte(value == 'true' ? 1 : 0);
    } else {
      final asInt = int.tryParse(value);
      props[key] = asInt != null ? NbtInt(asInt) : NbtString(value);
    }
  }
  out[propertiesKey] = props;
  return out;
}
