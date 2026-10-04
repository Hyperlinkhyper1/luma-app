// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include "bedrock/_context.hpp"
#include "bedrock/_entity.hpp"
#include "bedrock/_item.hpp"

// The engine only writes entities for chunks that have terrain. Bedrock keeps
// actors indexed in chunks it never saved terrain for (a mob that wandered to
// the edge of the loaded area, an arrow that flew past it), and the engine has
// no schema for thrown tridents at all. Both are recovered here from the
// normalized actor index, keyed by the same UUID the engine derives, so an
// entity it did write is never written twice.

static std::shared_ptr<CompoundTag> bedrockProjectile(CompoundTag const &source, je2be::bedrock::Context &context, int version) {
  auto type = source.string(u8"identifier",u8"");
  require(type == u8"minecraft:arrow" || type == u8"minecraft:thrown_trident","Unsupported projectile schema");
  require(version >= 1519,"Selected projectile records require Java 1.13 or newer");
  auto arrow = std::make_shared<CompoundTag>(); arrow->fValue = source.fValue;
  (*arrow)[u8"identifier"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:arrow");
  auto converted = je2be::bedrock::Entity::From(*arrow,context,version);
  require(bool(converted),"Cannot transfer projectile identity and physics");
  auto result = converted->fEntity;
  bool grounded = source.boolean(u8"OnGround",false) ||
    je2be::bedrock::Entity::HasDefinition(source,u8"+in_ground") ||
    je2be::bedrock::Entity::HasDefinition(source,u8"+minecraft:in_ground");
  (*result)[u8"inGround"] = std::make_shared<mcfile::nbt::ByteTag>(grounded ? 1 : 0);
  (*result)[u8"pickup"] = std::make_shared<mcfile::nbt::ByteTag>(source.boolean(u8"isCreative",false) ? 2 : source.boolean(u8"player",false) ? 1 : 0);
  if (type == u8"minecraft:thrown_trident") {
    auto item = source.compoundTag(u8"Trident");
    require(bool(item),"Thrown trident is missing its saved item");
    auto javaItem = je2be::bedrock::Item::From(*item,context,version,{});
    require(javaItem && javaItem->string(u8"id",u8"") == u8"minecraft:trident","Cannot transfer the thrown trident's item");
    (*result)[u8"id"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:trident");
    // Before 1.20.5 the thrown item is "Trident" in the Count/tag item format,
    // which the engine's item writer already produces for those versions.
    if (version >= 3837) (*result)[u8"item"] = javaItem;
    else {
      result->erase(u8"item");
      (*result)[u8"Trident"] = javaItem;
    }
    (*result)[u8"DealtDamage"] = std::make_shared<mcfile::nbt::ByteTag>(je2be::bedrock::Entity::HasDefinition(source,u8"+minecraft:returning") ? 1 : 0);
  }
  return result;
}

// Java 1.17+ keeps entities in entities/ regions; older versions keep them in
// the terrain chunk itself, so there a recovered entity needs that chunk.
static void appendEntityChunks(fs::path const &directory, std::map<std::pair<std::string,size_t>,std::shared_ptr<CompoundTag>> const &additions, bool terrainChunks) {
  std::set<std::string> files;
  for (auto const &[key,value] : additions) files.insert(key.first);
  fs::create_directories(directory);
  for (auto const &name : files) {
    auto file = directory/name;
    Bytes original = fs::exists(file) ? readFile(file) : Bytes(8192,0);
    require(original.size() >= 8192,"Truncated entity region");
    Bytes rewritten(original.begin(),original.begin()+8192);
    auto input = std::make_shared<mcfile::stream::ByteInputStream>(reinterpret_cast<char const *>(original.data()),original.size());
    mcfile::stream::InputStreamReader reader(input,mcfile::Encoding::Java);
    for (size_t slot = 0; slot < 1024; ++slot) {
      auto found = additions.find({name,slot});
      uint32_t location = be32(original,slot*4);
      if (!location && found == additions.end()) continue;
      std::shared_ptr<CompoundTag> root;
      if (location) {
        size_t offset = (location >> 8)*size_t(4096);
        require(offset >= 8192 && offset+5 <= original.size(),"Invalid entity region sector");
        auto length = be32(original,offset);
        require(length > 1 && offset+4+length <= original.size() && length+4 <= (location&255)*4096,"Truncated entity chunk");
        require((original[offset+4]&128) == 0,"External entity chunks are unsupported");
        mcfile::je::McaChunkLocator locator(0,0,0,offset,length);
        root = locator.load(reader); require(bool(root),"Cannot read saved entity chunk");
      } else {
        if (terrainChunks) {
          auto first = found->second->listTag(u8"Entities")->at(0)->asCompound();
          throw std::runtime_error("Java versions before 1.17 store entities inside terrain chunks, and this " +
            utf8(first->string(u8"id",u8"entity")) + " is in a chunk Bedrock saved without terrain. "
            "Choose Java 1.17 or newer, or turn off Convert entities.");
        }
        root = found->second;
      }
      if (location && found != additions.end()) {
        auto level = root->compoundTag(u8"Level");
        auto container = terrainChunks && level ? level.get() : root.get();
        auto entities = container->listTag(u8"Entities");
        if (!entities) {
          entities = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Compound);
          (*container)[u8"Entities"] = entities;
        }
        for (auto const &entry : found->second->listTag(u8"Entities")->fValue) entities->push_back(entry);
      }
      auto raw = CompoundTag::Write(*root,mcfile::Encoding::Java); require(bool(raw),"Cannot encode recovered entity chunk");
      Bytes compressed(raw->begin(),raw->end()); require(mcfile::Compression::CompressZlib(compressed),"Cannot compress recovered entity chunk");
      size_t sectors = (compressed.size()+5+4095)/4096, offset = rewritten.size();
      require(sectors <= 255,"Recovered entity chunk is too large");
      rewritten.resize(offset+sectors*4096);
      put32(rewritten,slot*4,uint32_t(offset/4096)<<8|uint32_t(sectors));
      put32(rewritten,offset,static_cast<uint32_t>(compressed.size()+1));
      rewritten[offset+4] = 2;
      std::copy(compressed.begin(),compressed.end(),rewritten.begin()+offset+5);
    }
    writeFile(file,rewritten);
  }
}

static void savedEntityUuids(CompoundTag const &entity, std::set<std::string> &saved) {
  if (auto uuid = javaUuid(entity)) saved.insert(utf8(uuid->toString()));
  if (auto passengers = entity.listTag(u8"Passengers")) {
    for (auto const &entry : passengers->fValue) if (auto child = entry->asCompound()) savedEntityUuids(*child,saved);
  }
}
static void savedPlayerEntityUuids(CompoundTag const &player, std::set<std::string> &saved) {
  if (auto vehicle = player.compoundTag(u8"RootVehicle")) if (auto e = vehicle->compoundTag(u8"Entity")) savedEntityUuids(*e,saved);
  for (auto key : {u8"ShoulderEntityLeft",u8"ShoulderEntityRight"}) if (auto e = player.compoundTag(key)) savedEntityUuids(*e,saved);
}

static void recoverBedrockActors(fs::path const &source, fs::path const &output) {
  auto level = javaLevel(output); auto data = level->compoundTag(u8"Data");
  require(bool(data),"Missing target Java level data");
  int version = data->int32(u8"DataVersion",0);
  if (version < 1519) return;
  bool terrainChunks = version < kJavaEntityStorageSplit;
  auto dimensions = javaDimensions(output,version);
  std::set<std::string> saved;
  json ignored = json::array();
  for (auto const &[dir,dimension] : dimensions) {
    for (auto name : {"region","entities"}) {
      regions(dir/name,dimension,ignored,false,[&](CompoundTag &root,size_t,fs::path const &) {
        auto container = root.compoundTag(u8"Level");
        if (!javaChunkHoldsEntities(root)) return;
        if (auto list = (container ? container.get() : &root)->listTag(u8"Entities")) {
          for (auto const &entry : list->fValue) {
            auto entity = entry->asCompound(); require(entity,"Invalid saved entity");
            savedEntityUuids(*entity,saved);
          }
        }
      },false);
    }
  }
  if (auto player = data->compoundTag(u8"Player")) savedPlayerEntityUuids(*player,saved);
  for (auto directory : {output/"playerdata",output/"players/data"}) {
    if (!fs::exists(directory)) continue;
    for (auto const &file : fs::directory_iterator(directory)) {
      if (file.path().extension() == ".dat") savedPlayerEntityUuids(*javaNbtFile(file.path()),saved);
    }
  }
  leveldb::Options dbOptions; leveldb::DB *raw = nullptr;
  auto status = openDatabase(dbOptions,source/"db",&raw); require(status.ok(),"Cannot read source entities: "+status.ToString());
  std::unique_ptr<leveldb::DB> db(raw);
  std::unique_ptr<leveldb::Iterator> it(db->NewIterator({}));
  std::vector<std::pair<std::shared_ptr<CompoundTag>,int>> pending;
  std::map<int64_t,std::array<int,3>> knots;
  std::set<std::string> seen, identities;
  auto consider = [&](std::shared_ptr<CompoundTag> const &actor, int dim) {
    auto type = utf8(actor->string(u8"identifier",u8""));
    auto uid = actor->int64(u8"UniqueID");
    if (type == "minecraft:leash_knot") {
      auto pos = actor->listTag(u8"Pos");
      if (uid && pos && pos->size() == 3) {
        auto at = [&](size_t axis) { auto f = pos->at(axis)->asFloat(); return f ? f->fValue : 0.f; };
        knots[*uid] = {int(std::round(at(0)-0.5f)),int(std::round(at(1)-0.25f)),int(std::round(at(2)-0.5f))};
      }
      return;
    }
    if (transientEntityType(type) || !uid) return;
    auto identity = utf8(je2be::Uuid::GenWithI64Seed(*uid).toString());
    // Duplicated records share one UniqueID; the scan counts them once.
    if (!identities.insert(identity).second || saved.contains(identity)) return;
    pending.emplace_back(actor,dim);
  };
  for (it->SeekToFirst();it->Valid();it->Next()) {
    auto key = it->key().ToString(), value = it->value().ToString();
    if (key.starts_with("digp")) {
      require((key.size() == 12 || key.size() == 16) && value.size()%8 == 0,"Invalid actor index");
      int dim = key.size() == 16 ? le32(key,12) : 0;
      require(dim >= 0 && dim <= 2,"Invalid actor dimension");
      for (size_t i=0;i<value.size();i+=8) {
        auto id = value.substr(i,8); if (!seen.insert(id).second) continue;
        std::string bytes; require(db->Get({},"actorprefix"+id,&bytes).ok(),"Normalized index references a missing actor");
        auto actor = CompoundTag::Read(bytes,mcfile::Encoding::LittleEndian); require(bool(actor),"Corrupt actor NBT");
        consider(actor,dim);
      }
      continue;
    }
    // Before 1.18.30 entities were saved inside their chunk. The engine skips
    // a chunk with no version record, and the entities stored in it.
    auto parsed = mcfile::be::DbKey::Parse(key);
    if (!parsed.fIsTagged || parsed.fTagged.fTag != static_cast<uint8_t>(mcfile::be::DbKey::Tag::Entity)) continue;
    int dim = static_cast<int>(parsed.fTagged.fDimension);
    if (dim < 0 || dim > 2) continue;
    auto stream = std::make_shared<mcfile::stream::ByteInputStream>(value.data(),value.size());
    mcfile::stream::InputStreamReader reader(stream,mcfile::Encoding::LittleEndian);
    while (stream->pos() < value.size()) {
      auto actor = CompoundTag::Read(reader); require(bool(actor),"Corrupt legacy entity NBT");
      consider(actor,dim);
    }
  }
  require(it->status().ok(),"Incomplete actor index scan"); it.reset(); db.reset();
  if (pending.empty()) return;
  je2be::bedrock::Options options; options.fTempDirectory = source.parent_path();
  std::map<mcfile::Dimension,std::vector<std::pair<je2be::Pos2i,je2be::bedrock::Context::ChunksInRegion>>> chunkMap;
  uint64_t total = 0; std::unique_ptr<je2be::bedrock::Context> context;
  auto initialized = je2be::bedrock::Context::Init(source/"db",options,mcfile::Encoding::LittleEndian,chunkMap,total,0,je2be::GameMode::Survival,1,context);
  require(initialized.ok() && context,"Cannot initialize entity conversion");
  if (auto player = data->compoundTag(u8"Player")) {
    auto rawPlayerDb = static_cast<leveldb::DB *>(nullptr);
    require(openDatabase(dbOptions,source/"db",&rawPlayerDb).ok(),"Cannot map entity owners");
    std::unique_ptr<leveldb::DB> playerDb(rawPlayerDb); std::string bytes;
    if (playerDb->Get({},"~local_player",&bytes).ok()) {
      auto bedrockPlayer = CompoundTag::Read(bytes,mcfile::Encoding::LittleEndian);
      if (bedrockPlayer) if (auto id = bedrockPlayer->int64(u8"UniqueID")) if (auto uuid = javaUuid(*player)) context->setLocalPlayerIds(*id,*uuid);
    }
  }
  std::array<std::map<std::pair<std::string,size_t>,std::shared_ptr<CompoundTag>>,3> additions;
  for (auto const &[actor,dim] : pending) {
    auto type = actor->string(u8"identifier",u8"");
    std::shared_ptr<CompoundTag> entity;
    if (type == u8"minecraft:arrow" || type == u8"minecraft:thrown_trident") entity = bedrockProjectile(*actor,*context,version);
    else {
      // No schema, or a parrot that belongs on the player's shoulder: the
      // verification that follows reports any counted entity left behind.
      auto converted = je2be::bedrock::Entity::From(*actor,*context,version);
      if (!converted || !converted->fEntity) continue;
      entity = converted->fEntity;
      if (auto knot = knots.find(actor->int64(u8"LeasherID",-1)); knot != knots.end()) {
        auto const &[x,y,z] = knot->second;
        entity->erase(u8"leash");
        if (version >= je2be::kJavaDataVersionComponentIntroduced) {
          std::vector<int32_t> block{x,y,z};
          (*entity)[u8"leash"] = std::make_shared<mcfile::nbt::IntArrayTag>(block);
        } else {
          auto leash = std::make_shared<CompoundTag>();
          (*leash)[u8"X"] = std::make_shared<mcfile::nbt::IntTag>(x);
          (*leash)[u8"Y"] = std::make_shared<mcfile::nbt::IntTag>(y);
          (*leash)[u8"Z"] = std::make_shared<mcfile::nbt::IntTag>(z);
          (*entity)[u8"Leash"] = leash;
        }
      }
    }
    auto pos = entity->listTag(u8"Pos"); require(pos && pos->size() == 3,"Recovered entity lost its position");
    auto x = pos->at(0)->asDouble(), z = pos->at(2)->asDouble();
    require(x && z && std::isfinite(x->fValue) && std::isfinite(z->fValue),"Invalid recovered entity position");
    double chunkX = std::floor(x->fValue/16), chunkZ = std::floor(z->fValue/16);
    require(chunkX >= INT32_MIN && chunkX <= INT32_MAX && chunkZ >= INT32_MIN && chunkZ <= INT32_MAX,"Entity position is outside the valid chunk range");
    int cx = static_cast<int>(chunkX), cz = static_cast<int>(chunkZ);
    int rx = mcfile::Coordinate::RegionFromChunk(cx), rz = mcfile::Coordinate::RegionFromChunk(cz);
    auto name = "r."+std::to_string(rx)+"."+std::to_string(rz)+".mca";
    size_t slot = (cz-rz*32)*32+(cx-rx*32);
    auto &chunk = additions[dim][{name,slot}];
    if (!chunk) {
      chunk = std::make_shared<CompoundTag>();
      (*chunk)[u8"DataVersion"] = std::make_shared<mcfile::nbt::IntTag>(version);
      std::vector<int32_t> position{cx,cz};
      (*chunk)[u8"Position"] = std::make_shared<mcfile::nbt::IntArrayTag>(position);
      (*chunk)[u8"Entities"] = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Compound);
    }
    chunk->listTag(u8"Entities")->push_back(entity);
  }
  for (int dim=0;dim<3;dim++) {
    if (additions[dim].empty()) continue;
    appendEntityChunks(dimensions[dim].first/(terrainChunks ? "region" : "entities"),additions[dim],terrainChunks);
  }
}
