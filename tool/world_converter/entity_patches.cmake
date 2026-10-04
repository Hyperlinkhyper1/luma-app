# Teach the engine's Java -> Bedrock entity table about thrown tridents.
# Without an entry the engine writes a generic actor with the Java id
# "minecraft:trident" and no item, which Bedrock cannot load. Bedrock's own id
# is "minecraft:thrown_trident" and it keeps the item under "Trident".
file(READ "${je2be_SOURCE_DIR}/src/java-entity.cpp" java_entity)
set(arrow_entry "    E(arrow, C(EntityBase, Definitions({u8\"+minecraft:arrow\"}), Arrow));")
set(trident_entry "    E(trident, C(EntityBase, Definitions({u8\"+minecraft:thrown_trident\"}), Arrow, LumaThrownTrident));")
set(arrow_behavior "  static void Arrow(CompoundTag &c, CompoundTag const &tag, ConverterContext &ctx) {")
set(trident_behavior "  static void LumaThrownTrident(CompoundTag &c, CompoundTag const &tag, ConverterContext &ctx) {
    c[u8\"identifier\"] = String(u8\"minecraft:thrown_trident\");
    auto item = tag.compoundTag(u8\"item\");
    if (!item) {
      item = tag.compoundTag(u8\"Trident\");
    }
    if (item) {
      if (auto converted = Item::From(item, ctx.fCtx, ctx.fDataVersion); converted) {
        c[u8\"Trident\"] = converted;
      }
    }
    c.erase(u8\"auxValue\");
  }

")
string(FIND "${java_entity}" "LumaThrownTrident" patched)
if(patched EQUAL -1)
  string(FIND "${java_entity}" "${arrow_entry}" entry_offset)
  string(FIND "${java_entity}" "${arrow_behavior}" behavior_offset)
  if(entry_offset EQUAL -1 OR behavior_offset EQUAL -1)
    message(FATAL_ERROR "The pinned engine entity table has changed")
  endif()
  string(REPLACE "${arrow_entry}" "${arrow_entry}\n${trident_entry}" java_entity "${java_entity}")
  string(REPLACE "${arrow_behavior}" "${trident_behavior}${arrow_behavior}" java_entity "${java_entity}")
  file(WRITE "${je2be_SOURCE_DIR}/src/java-entity.cpp" "${java_entity}")
endif()
