// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include "bedrock/_context.hpp"
#include "bedrock/_entity.hpp"
#include "bedrock/_item.hpp"

static std::shared_ptr<CompoundTag> bedrockProjectile(CompoundTag const &source, je2be::bedrock::Context &context, int version) {
  auto type = source.string(u8"identifier",u8"");
  require(type == u8"minecraft:arrow" || type == u8"minecraft:thrown_trident","Unsupported projectile schema");
  require(version >= 3837,"Selected projectile records require Java 1.20.5 or newer");
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
    (*result)[u8"item"] = javaItem;
    (*result)[u8"DealtDamage"] = std::make_shared<mcfile::nbt::ByteTag>(je2be::bedrock::Entity::HasDefinition(source,u8"+minecraft:returning") ? 1 : 0);
  }
  return result;
}

static void appendEntityChunks(fs::path const &directory, std::map<std::pair<std::string,size_t>,std::shared_ptr<CompoundTag>> const &additions) {
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
      } else root = found->second;
      if (location && found != additions.end()) {
        auto entities = root->listTag(u8"Entities"); require(bool(entities),"Entity chunk has no entity list");
        for (auto const &entry : found->second->listTag(u8"Entities")->fValue) entities->push_back(entry);
      }
      auto raw = CompoundTag::Write(*root,mcfile::Encoding::Java); require(bool(raw),"Cannot encode projectile chunk");
      Bytes compressed(raw->begin(),raw->end()); require(mcfile::Compression::CompressZlib(compressed),"Cannot compress projectile chunk");
      size_t sectors = (compressed.size()+5+4095)/4096, offset = rewritten.size();
      require(sectors <= 255,"Projectile chunk is too large");
      rewritten.resize(offset+sectors*4096);
      put32(rewritten,slot*4,uint32_t(offset/4096)<<8|uint32_t(sectors));
      put32(rewritten,offset,static_cast<uint32_t>(compressed.size()+1));
      rewritten[offset+4] = 2;
      std::copy(compressed.begin(),compressed.end(),rewritten.begin()+offset+5);
    }
    writeFile(file,rewritten);
  }
}

static void recoverBedrockProjectiles(fs::path const &source, fs::path const &output) {
  auto level = javaLevel(output); auto data = level->compoundTag(u8"Data");
  require(bool(data),"Missing target Java level data");
  int version = data->int32(u8"DataVersion",0);
  if (version < 3837) return;
  auto dimensions = javaDimensions(output,version);
  std::set<std::string> saved;
  json ignored = json::array();
  for (auto const &[dir,dimension] : dimensions) {
    regions(dir/"entities",dimension,ignored,false,[&](CompoundTag &root,size_t,fs::path const &) {
      if (auto list = root.listTag(u8"Entities")) for (auto const &entry : list->fValue) {
        auto entity = entry->asCompound(); require(entity,"Invalid saved entity");
        if (auto uuid = javaUuid(*entity)) saved.insert(utf8(uuid->toString()));
      }
    },false);
  }
  leveldb::Options dbOptions; leveldb::DB *raw = nullptr;
  auto status = openDatabase(dbOptions,source/"db",&raw); require(status.ok(),"Cannot read source projectiles: "+status.ToString());
  std::unique_ptr<leveldb::DB> db(raw);
  std::unique_ptr<leveldb::Iterator> it(db->NewIterator({}));
  std::vector<std::pair<std::shared_ptr<CompoundTag>,int>> pending;
  std::set<std::string> seen;
  std::set<std::string> identities;
  for (it->SeekToFirst();it->Valid();it->Next()) {
    auto key = it->key().ToString(), value = it->value().ToString();
    if (!key.starts_with("digp")) continue;
    require((key.size() == 12 || key.size() == 16) && value.size()%8 == 0,"Invalid projectile actor index");
    int dim = key.size() == 16 ? le32(key,12) : 0;
    require(dim >= 0 && dim <= 2,"Invalid projectile dimension");
    for (size_t i=0;i<value.size();i+=8) {
      auto id = value.substr(i,8); if (!seen.insert(id).second) continue;
      std::string bytes; require(db->Get({},"actorprefix"+id,&bytes).ok(),"Normalized index references a missing actor");
      auto actor = CompoundTag::Read(bytes,mcfile::Encoding::LittleEndian); require(bool(actor),"Corrupt projectile actor");
      auto type = actor->string(u8"identifier",u8"");
      if (type != u8"minecraft:arrow" && type != u8"minecraft:thrown_trident") continue;
      auto uid = actor->int64(u8"UniqueID"); require(bool(uid),"Projectile has no saved identity");
      auto identity = utf8(je2be::Uuid::GenWithI64Seed(*uid).toString());
      require(identities.insert(identity).second,"Different projectile records share one identity; refusing to discard either");
      if (saved.contains(identity)) continue;
      pending.emplace_back(actor,dim);
    }
  }
  require(it->status().ok(),"Incomplete projectile index scan"); it.reset(); db.reset();
  if (pending.empty()) return;
  je2be::bedrock::Options options; options.fTempDirectory = source.parent_path();
  std::map<mcfile::Dimension,std::vector<std::pair<je2be::Pos2i,je2be::bedrock::Context::ChunksInRegion>>> chunkMap;
  uint64_t total = 0; std::unique_ptr<je2be::bedrock::Context> context;
  auto initialized = je2be::bedrock::Context::Init(source/"db",options,mcfile::Encoding::LittleEndian,chunkMap,total,0,je2be::GameMode::Survival,1,context);
  require(initialized.ok() && context,"Cannot initialize projectile item conversion");
  if (auto player = data->compoundTag(u8"Player")) {
    auto rawPlayerDb = static_cast<leveldb::DB *>(nullptr);
    require(openDatabase(dbOptions,source/"db",&rawPlayerDb).ok(),"Cannot map projectile owner");
    std::unique_ptr<leveldb::DB> playerDb(rawPlayerDb); std::string bytes;
    if (playerDb->Get({},"~local_player",&bytes).ok()) {
      auto bedrockPlayer = CompoundTag::Read(bytes,mcfile::Encoding::LittleEndian);
      if (bedrockPlayer) if (auto id = bedrockPlayer->int64(u8"UniqueID")) if (auto uuid = javaUuid(*player)) context->setLocalPlayerIds(*id,*uuid);
    }
  }
  std::array<std::map<std::pair<std::string,size_t>,std::shared_ptr<CompoundTag>>,3> additions;
  for (auto const &[actor,dim] : pending) {
    auto entity = bedrockProjectile(*actor,*context,version);
    auto pos = entity->listTag(u8"Pos"); require(pos && pos->size() == 3,"Converted projectile lost its position");
    auto x = pos->at(0)->asDouble(), z = pos->at(2)->asDouble();
    require(x && z && std::isfinite(x->fValue) && std::isfinite(z->fValue),"Invalid converted projectile position");
    double chunkX = std::floor(x->fValue/16), chunkZ = std::floor(z->fValue/16);
    require(chunkX >= INT32_MIN && chunkX <= INT32_MAX && chunkZ >= INT32_MIN && chunkZ <= INT32_MAX,"Projectile position is outside the valid chunk range");
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
  for (int dim=0;dim<3;dim++) if (!additions[dim].empty()) appendEntityChunks(dimensions[dim].first/"entities",additions[dim]);
}
