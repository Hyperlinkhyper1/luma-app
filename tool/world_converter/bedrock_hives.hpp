// SPDX-License-Identifier: GPL-3.0-only
#pragma once

// Bedrock saves bees in naturally generated nests as an ActorIdentifier with
// an empty SaveData. The engine converts occupants from SaveData alone, so
// those bees vanish; it also omits the stay timers Java requires per bee.
// Rebuild each Java hive's list in the Bedrock order: converted bees keep
// their engine record, the rest get a minimal record of their own kind.
struct BedrockOccupant { std::string type; bool converted; int ticksLeft; };

static void completeBedrockHives(fs::path const &source, fs::path const &output) {
  using Key = std::tuple<int,int,int>;
  std::array<std::map<Key,std::vector<BedrockOccupant>>,3> hives;
  {
    leveldb::Options options; leveldb::DB *raw = nullptr;
    auto status = openDatabase(options,source/"db",&raw); require(status.ok(),"Cannot read source hives: "+status.ToString());
    std::unique_ptr<leveldb::DB> db(raw);
    std::unique_ptr<leveldb::Iterator> it(db->NewIterator({}));
    for (it->SeekToFirst(); it->Valid(); it->Next()) {
      auto parsed = mcfile::be::DbKey::Parse(it->key().ToString());
      if (!parsed.fIsTagged || parsed.fTagged.fTag != static_cast<uint8_t>(mcfile::be::DbKey::Tag::BlockEntity)) continue;
      int dim = static_cast<int>(parsed.fTagged.fDimension);
      if (dim < 0 || dim > 2) continue;
      auto value = it->value().ToString();
      auto stream = std::make_shared<mcfile::stream::ByteInputStream>(value.data(),value.size());
      mcfile::stream::InputStreamReader r(stream,mcfile::Encoding::LittleEndian);
      while (stream->pos() < value.size()) {
        auto block = CompoundTag::Read(r); require(bool(block),"Corrupt block entity NBT");
        auto occupants = block->listTag(u8"Occupants");
        if (!occupants || occupants->empty()) continue;
        auto &list = hives[dim][{block->int32(u8"x",0),block->int32(u8"y",0),block->int32(u8"z",0)}];
        for (auto const &entry : occupants->fValue) {
          auto occupant = entry->asCompound(); require(occupant != nullptr,"Invalid hive occupant");
          auto data = occupant->compoundTag(u8"SaveData");
          bool converted = !(data ? data.get() : occupant)->string(u8"identifier",u8"").empty();
          auto type = hiveOccupantType(*occupant);
          require(!type.empty(),"Hive occupant has no entity identifier");
          list.push_back({type,converted,std::max(0,occupant->int32(u8"TicksLeftToStay",0))});
        }
      }
    }
    require(it->status().ok(),"Incomplete hive scan");
  }
  if (hives[0].empty() && hives[1].empty() && hives[2].empty()) return;
  int version = javaLevel(output)->compoundTag(u8"Data")->int32(u8"DataVersion",0);
  bool modern = version >= 3837;
  auto listKey = modern ? u8"bees" : u8"Bees", dataKey = modern ? u8"entity_data" : u8"EntityData";
  auto ticksKey = modern ? u8"ticks_in_hive" : u8"TicksInHive", minKey = modern ? u8"min_ticks_in_hive" : u8"MinOccupationTicks";
  auto dimensions = javaDimensions(output,version);
  json ignored = json::array();
  for (int dim = 0; dim < 3; ++dim) {
    if (hives[dim].empty()) continue;
    regions(dimensions[dim].first/"region",dim,ignored,false,[&](CompoundTag &root,size_t,fs::path const &) {
      auto level = root.compoundTag(u8"Level");
      auto tiles = (level ? level.get() : &root)->listTag(level ? u8"TileEntities" : u8"block_entities");
      if (!tiles) return;
      for (auto const &entry : tiles->fValue) {
        auto tile = std::dynamic_pointer_cast<CompoundTag>(entry); require(bool(tile),"Invalid block entity");
        auto found = hives[dim].find({tile->int32(u8"x",0),tile->int32(u8"y",0),tile->int32(u8"z",0)});
        if (found == hives[dim].end()) continue;
        auto existing = tile->listTag(listKey);
        auto rebuilt = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Compound);
        size_t next = 0;
        for (auto const &occupant : found->second) {
          std::shared_ptr<CompoundTag> bee;
          if (occupant.converted && existing && next < existing->size()) {
            bee = std::dynamic_pointer_cast<CompoundTag>(existing->at(next++));
            require(bool(bee),"Invalid converted hive occupant");
          } else {
            bee = std::make_shared<CompoundTag>();
            auto data = std::make_shared<CompoundTag>();
            (*data)[u8"id"] = std::make_shared<mcfile::nbt::StringTag>(std::u8string(occupant.type.begin(),occupant.type.end()));
            (*bee)[dataKey] = data;
          }
          if (!bee->int32(ticksKey)) (*bee)[ticksKey] = std::make_shared<mcfile::nbt::IntTag>(0);
          if (!bee->int32(minKey)) (*bee)[minKey] = std::make_shared<mcfile::nbt::IntTag>(occupant.ticksLeft);
          rebuilt->push_back(bee);
        }
        while (existing && next < existing->size()) rebuilt->push_back(existing->at(next++));
        (*tile)[listKey] = rebuilt;
      }
    });
  }
}
