// SPDX-License-Identifier: GPL-3.0-only
#include <je2be.hpp>
#include <leveldb/db.h>
#include <leveldb/write_batch.h>
#include <nlohmann/json.hpp>
#include <fstream>
#include <iostream>
#include <thread>
#include "entity_types.hpp"
#include "_data-version.hpp"

namespace fs = std::filesystem;
using mcfile::nbt::CompoundTag;
using mcfile::nbt::Tag;
using json = nlohmann::json;
using Bytes = std::vector<uint8_t>;

static void require(bool ok, std::string const &message) {
  if (!ok) throw std::runtime_error(message);
}
static leveldb::Status openDatabase(leveldb::Options const &options, fs::path const &path, leveldb::DB **out) {
  for (int attempt = 0;; ++attempt) {
    auto status = leveldb::DB::Open(options,path,out);
#ifdef _WIN32
    if (status.IsIOError() && attempt < 4) {
      std::this_thread::sleep_for(std::chrono::milliseconds(100 << attempt));
      continue;
    }
#endif
    return status;
  }
}
static std::string utf8(std::u8string const &s) {
  return std::string(reinterpret_cast<char const *>(s.data()), s.size());
}
static Bytes readFile(fs::path const &p) {
  std::ifstream f(p, std::ios::binary);
  require(f.good(), "Cannot read " + p.filename().string());
  return Bytes(std::istreambuf_iterator<char>(f), {});
}
static void writeFile(fs::path const &p, Bytes const &b) {
  std::ofstream f(p, std::ios::binary | std::ios::trunc);
  f.write(reinterpret_cast<char const *>(b.data()), b.size());
  require(f.good(), "Cannot write " + p.filename().string());
}
static uint32_t be32(Bytes const &b, size_t i) {
  require(i + 4 <= b.size(), "Truncated region header");
  return uint32_t(b[i]) << 24 | uint32_t(b[i+1]) << 16 | uint32_t(b[i+2]) << 8 | b[i+3];
}
static void put32(Bytes &b, size_t i, uint32_t n) {
  for (int j = 0; j < 4; ++j) b[i+j] = n >> (24-j*8);
}
static auto javaNbtFile(fs::path const &p) {
  auto raw = readFile(p);
  z_stream z{};
  require(inflateInit2(&z, 47) == Z_OK, "Cannot initialize gzip");
  z.next_in = raw.data(); z.avail_in = static_cast<uInt>(raw.size());
  Bytes plain; uint8_t block[65536]; int status;
  do {
    z.next_out = block; z.avail_out = sizeof(block);
    status = inflate(&z, Z_NO_FLUSH);
    plain.insert(plain.end(), block, block + sizeof(block) - z.avail_out);
  } while (status == Z_OK);
  inflateEnd(&z);
  require(status == Z_STREAM_END, "Invalid Java level.dat gzip");
  auto tag = CompoundTag::Read(plain, mcfile::Encoding::Java);
  require(bool(tag), "Invalid Java level.dat NBT");
  return tag;
}
static auto javaLevel(fs::path const &p) { return javaNbtFile(p/"level.dat"); }
static void saveJavaNbtFile(fs::path const &p, CompoundTag const &tag) {
  auto plain = CompoundTag::Write(tag, mcfile::Encoding::Java);
  require(bool(plain), "Cannot encode level.dat");
  z_stream z{};
  require(deflateInit2(&z, 6, Z_DEFLATED, 31, 8, Z_DEFAULT_STRATEGY) == Z_OK, "Cannot initialize gzip");
  Bytes compressed(deflateBound(&z, static_cast<uLong>(plain->size())));
  z.next_in = reinterpret_cast<Bytef *>(plain->data()); z.avail_in = static_cast<uInt>(plain->size());
  z.next_out = compressed.data(); z.avail_out = static_cast<uInt>(compressed.size());
  int status = deflate(&z, Z_FINISH);
  compressed.resize(z.total_out); deflateEnd(&z);
  require(status == Z_STREAM_END, "Cannot compress level.dat");
  writeFile(p, compressed);
}
static void saveJavaLevel(fs::path const &p, CompoundTag const &tag) { saveJavaNbtFile(p/"level.dat",tag); }

static void entity(json &out, CompoundTag const &e, int dim, bool bedrock) {
  auto id = e.string(bedrock ? u8"identifier" : u8"id", u8"");
  require(!id.empty(), "Entity has no type identifier");
  auto pos = e.listTag(u8"Pos");
  require(pos && pos->size() == 3, "Entity has no valid position: " + utf8(id));
  json xyz = json::array();
  for (auto const &v : pos->fValue) {
    if (auto d = v->asDouble()) xyz.push_back(d->fValue);
    else if (auto f = v->asFloat()) xyz.push_back(f->fValue);
    else throw std::runtime_error("Entity position is not numeric");
  }
  out.push_back({{"type", utf8(id)}, {"dimension", dim}, {"position", xyz}});
  if (auto children = e.listTag(u8"Passengers")) {
    for (auto const &child : children->fValue) {
      auto c = child->asCompound(); require(c != nullptr, "Invalid passenger NBT");
      entity(out, *c, dim, bedrock);
    }
  }
  if (auto vehicle = e.compoundTag(u8"Riding")) entity(out,*vehicle,dim,bedrock);
}
static void entityList(json &out, CompoundTag const &root, int dim) {
  auto container = root.compoundTag(u8"Level");
  auto list = (container ? container.get() : &root)->listTag(u8"Entities");
  if (!list) return;
  for (auto const &e : list->fValue) {
    auto c = e->asCompound(); require(c != nullptr, "Invalid entity NBT");
    entity(out, *c, dim, false);
  }
}
static void hive(json &out, CompoundTag &block, int dim, bool bedrock, bool strip) {
  auto bees = block.listTag(bedrock ? u8"Occupants" : u8"bees");
  if (!bedrock && !bees) bees = block.listTag(u8"Bees");
  if (!bees) return;
  for (auto const &entry : bees->fValue) {
    auto occupant = entry->asCompound(); require(occupant != nullptr, "Invalid hive occupant");
    auto data = occupant->compoundTag(bedrock ? u8"SaveData" : u8"entity_data");
    if (!bedrock && !data) data = occupant->compoundTag(u8"EntityData");
    auto e = data ? data.get() : occupant;
    auto id = e->string(bedrock ? u8"identifier" : u8"id",u8"");
    require(!id.empty(), "Hive occupant has no entity identifier");
    out.push_back({{"type",utf8(id)+"@hive"},{"dimension",dim},
      {"position",{block.int32(u8"x",0)+0.5,block.int32(u8"y",0)+0.5,block.int32(u8"z",0)+0.5}}});
  }
  if (strip) { block.erase(u8"Occupants"); block.erase(u8"bees"); block.erase(u8"Bees"); }
}
using RegionEdit = std::function<void(CompoundTag &, size_t, fs::path const &)>;
static void regions(fs::path const &dir, int dim, json &entities, bool strip, RegionEdit const &edit = {}, bool writeEdits = true) {
  if (!fs::exists(dir)) return;
  for (auto const &entry : fs::directory_iterator(dir)) {
    require(entry.path().extension() != ".mcr", "Pre-Anvil .mcr regions are not supported. Upgrade a copy of this world in Minecraft first.");
    if (entry.path().extension() != ".mca") continue;
    auto bytes = readFile(entry.path());
    require(bytes.size() >= 8192, "Truncated region file");
    Bytes rewritten(bytes.begin(), bytes.begin() + 8192);
    auto input = std::make_shared<mcfile::stream::ByteInputStream>(reinterpret_cast<char const *>(bytes.data()), bytes.size());
    mcfile::stream::InputStreamReader reader(input, mcfile::Encoding::Java);
    for (size_t i = 0; i < 1024; ++i) {
      uint32_t location = be32(bytes, i*4);
      if (!location) continue;
      size_t offset = (location >> 8) * size_t(4096);
      require(offset >= 8192 && offset + 5 <= bytes.size(), "Invalid region sector");
      auto length = be32(bytes, offset);
      require(length > 1 && offset + 4 + length <= bytes.size() && length + 4 <= (location & 255) * 4096, "Truncated region chunk");
      require((bytes[offset+4] & 128) == 0, "External .mcc chunks are not supported yet");
      mcfile::je::McaChunkLocator locator(0, 0, 0, offset, length);
      auto root = locator.load(reader); require(bool(root), "Cannot decode region chunk");
      entityList(entities, *root, dim);
      auto container = root->compoundTag(u8"Level");
      auto tiles = (container ? container : root)->listTag(container ? u8"TileEntities" : u8"block_entities");
      if (tiles) {
        for (auto const &entry : tiles->fValue) {
          auto block = std::dynamic_pointer_cast<CompoundTag>(entry); require(bool(block), "Invalid block entity");
          hive(entities,*block,dim,false,strip);
        }
      }
      if (!strip && !edit) continue;
      if (strip) (container ? container : root)->erase(u8"Entities");
      if (edit) edit(*root,i,entry.path());
      if (!strip && !writeEdits) continue;
      auto raw = CompoundTag::Write(*root, mcfile::Encoding::Java);
      require(bool(raw), "Cannot encode region chunk");
      Bytes compressed(raw->begin(), raw->end());
      require(mcfile::Compression::CompressZlib(compressed), "Cannot compress region chunk");
      size_t sectors = (compressed.size() + 5 + 4095) / 4096;
      require(sectors <= 255, "Region chunk too large");
      size_t start = rewritten.size();
      rewritten.resize(start + sectors * 4096);
      put32(rewritten, i*4, uint32_t(start / 4096) << 8 | uint32_t(sectors));
      put32(rewritten, start, static_cast<uint32_t>(compressed.size()+1));
      rewritten[start+4] = 2;
      std::copy(compressed.begin(), compressed.end(), rewritten.begin()+start+5);
    }
    if (strip || (edit && writeEdits)) writeFile(entry.path(), rewritten);
  }
}
static int playerDimension(CompoundTag const &p) {
  auto d = p.string(u8"Dimension", u8"minecraft:overworld");
  if (d == u8"minecraft:the_nether") return 1;
  if (d == u8"minecraft:the_end") return 2;
  return p.int32(u8"Dimension", 0) == -1 ? 1 : p.int32(u8"Dimension", 0);
}
static std::optional<je2be::Uuid> javaUuid(CompoundTag const &p) {
  if (auto uuid = p.intArrayTag(u8"UUID")) return je2be::Uuid::FromIntArray(*uuid);
  auto most = p.int64(u8"UUIDMost"), least = p.int64(u8"UUIDLeast");
  if (!most || !least) return std::nullopt;
  return je2be::Uuid::FromInt32(static_cast<int32_t>(*most >> 32), static_cast<int32_t>(*most),
    static_cast<int32_t>(*least >> 32),static_cast<int32_t>(*least));
}
static void adaptJavaTag(CompoundTag &tag, int version) {
  if (version < 2566 && tag.listTag(u8"Pos") && tag.string(u8"id",u8"") == u8"minecraft:zombified_piglin")
    tag[u8"id"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:zombie_pigman");
  if (version < 4080 && tag.listTag(u8"Pos")) {
    auto id = utf8(tag.string(u8"id",u8""));
    bool chest = id.ends_with("_chest_boat") || id == "minecraft:bamboo_chest_raft";
    bool boat = chest || id.ends_with("_boat") || id == "minecraft:bamboo_raft";
    if (boat && id != "minecraft:boat" && id != "minecraft:chest_boat") {
      auto wood = id.substr(10);
      if (wood.starts_with("bamboo")) wood = "bamboo";
      else wood.resize(wood.size() - (chest ? 11 : 5));
      require((wood != "pale_oak") &&
        (version >= 3463 || (wood != "cherry" && wood != "bamboo")) &&
        (version >= 3105 || wood != "mangrove"),"The selected Java version cannot represent this boat: " + id);
      require(!chest || version >= 3105,"The selected Java version has no chest boats");
      tag[u8"id"] = std::make_shared<mcfile::nbt::StringTag>(chest ? u8"minecraft:chest_boat" : u8"minecraft:boat");
      tag[u8"Type"] = std::make_shared<mcfile::nbt::StringTag>(std::u8string(wood.begin(),wood.end()));
    }
  }
  if (version < 4325 && tag.listTag(u8"Pos")) {
    auto id = tag.string(u8"id",u8"");
    if (id == u8"minecraft:splash_potion" || id == u8"minecraft:lingering_potion")
      tag[u8"id"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:potion");
  }
  if (auto uuid = tag.intArrayTag(u8"UUID"); version < 2566 && uuid) {
    require(uuid->fValue.size() == 4,"Invalid entity UUID");
    auto const &v = uuid->fValue;
    auto most = (uint64_t(uint32_t(v[0])) << 32) | uint32_t(v[1]);
    auto least = (uint64_t(uint32_t(v[2])) << 32) | uint32_t(v[3]);
    tag[u8"UUIDMost"] = std::make_shared<mcfile::nbt::LongTag>(static_cast<int64_t>(most));
    tag[u8"UUIDLeast"] = std::make_shared<mcfile::nbt::LongTag>(static_cast<int64_t>(least));
    tag.erase(u8"UUID");
  }
  if (auto owner = tag.intArrayTag(u8"Owner"); version < 2566 && owner) {
    auto uuid = je2be::Uuid::FromIntArray(*owner); require(bool(uuid),"Invalid owner UUID");
    auto id = utf8(tag.string(u8"id",u8""));
    static std::set<std::string> const pets = {"minecraft:wolf","minecraft:cat","minecraft:horse","minecraft:donkey","minecraft:mule","minecraft:llama","minecraft:trader_llama","minecraft:parrot","minecraft:skeleton_horse","minecraft:zombie_horse"};
    require(pets.contains(id),"Ownership schema cannot be safely downgraded for " + id);
    tag[u8"OwnerUUID"] = std::make_shared<mcfile::nbt::StringTag>(uuid->toString()); tag.erase(u8"Owner");
  }
  require(version >= 2566 || !tag.listTag(u8"Trusted"),"Trusted-player records cannot be safely downgraded to this Java version");
  for (auto const &[key,value] : tag.fValue) {
    if (auto child = std::dynamic_pointer_cast<CompoundTag>(value)) adaptJavaTag(*child,version);
    else if (auto list = std::dynamic_pointer_cast<mcfile::nbt::ListTag>(value)) {
      for (auto const &entry : list->fValue) if (auto child = std::dynamic_pointer_cast<CompoundTag>(entry)) adaptJavaTag(*child,version);
    }
  }
}
static auto javaDimensions(fs::path const &p,int version) {
  std::vector<std::pair<fs::path,int>> result;
  if (version >= 4786) result = {{p/"dimensions/minecraft/overworld",0},{p/"dimensions/minecraft/the_nether",1},{p/"dimensions/minecraft/the_end",2}};
  else result = {{p,0},{p/"DIM-1",1},{p/"DIM1",2}};
  if (fs::exists(p/"dimensions")) {
    for (auto const &ns : fs::directory_iterator(p/"dimensions")) {
      require(ns.path().filename() == "minecraft","Custom dimensions are not supported; refusing to omit them");
      for (auto const &dim : fs::directory_iterator(ns.path())) {
        auto name = dim.path().filename().string();
        require(name == "overworld" || name == "the_nether" || name == "the_end", "Custom dimensions are not supported; refusing to omit them");
      }
    }
  }
  return result;
}
static json scanJava(fs::path const &p, bool stripEntities = false, bool stripPlayers = false) {
  auto level = javaLevel(p); auto data = level->compoundTag(u8"Data");
  require(bool(data), "Missing Java world Data");
  int version = data->int32(u8"DataVersion", 0);
  require(version >= 0 && version <= 5017, "This engine supports Java release formats through 26.3. Update Luma for a newer format.");
  json result = {{"edition", "java"}, {"version", version}, {"entities", json::array()}, {"remotePlayers", 0}, {"localPlayer", false}};
  auto &entities = result["entities"];
  for (auto const &[dir, dim] : javaDimensions(p,version)) {
    regions(dir/"region", dim, entities, stripEntities);
    regions(dir/"entities", dim, entities, stripEntities);
  }
  auto player = data->compoundTag(u8"Player");
  std::string localUuid;
  if (version >= 4786) {
    if (auto uuid = data->intArrayTag(u8"singleplayer_uuid")) {
      auto id = je2be::Uuid::FromIntArray(*uuid); require(bool(id),"Invalid single-player UUID");
      localUuid = utf8(id->toString());
      auto file = p/"players/data"/(localUuid+".dat");
      if (fs::exists(file)) player = javaNbtFile(file);
    }
  }
  if (player) {
    result["localPlayer"] = true;
    if (auto uuid = javaUuid(*player)) localUuid = utf8(uuid->toString());
    auto vehicle = player->compoundTag(u8"RootVehicle");
    if (vehicle) {
      if (auto e = vehicle->compoundTag(u8"Entity")) entity(entities, *e, playerDimension(*player), false);
    }
    for (auto key : {u8"ShoulderEntityLeft", u8"ShoulderEntityRight"}) {
      if (auto e = player->compoundTag(key); e && !e->empty()) entity(entities, *e, playerDimension(*player), false);
    }
    if (stripEntities) {
      player->erase(u8"RootVehicle"); player->erase(u8"ShoulderEntityLeft"); player->erase(u8"ShoulderEntityRight");
    }
  }
  auto playerDirectory = version >= 4786 ? p/"players/data" : p/"playerdata";
  if (fs::exists(playerDirectory)) {
    for (auto const &f : fs::directory_iterator(playerDirectory)) {
      if (f.path().extension() == ".dat" && f.path().stem().string() != localUuid) result["remotePlayers"] = result["remotePlayers"].get<int>() + 1;
    }
    if (stripPlayers) fs::remove_all(playerDirectory);
  }
  if (stripPlayers) { data->erase(u8"Player"); data->erase(u8"singleplayer_uuid"); }
  if (stripEntities && player && version >= 4786 && !stripPlayers) {
    saveJavaNbtFile(playerDirectory/(localUuid+".dat"),*player);
  }
  if (stripEntities || stripPlayers) saveJavaLevel(p, *level);
  return result;
}
static int le32(std::string const &s, size_t offset) {
  require(offset+4 <= s.size(), "Truncated database key");
  uint32_t v = 0; for (size_t i=0; i<4; ++i) v |= uint32_t(uint8_t(s[offset+i])) << (8*i);
  return static_cast<int32_t>(v);
}
static json scanBedrock(fs::path const &p, bool stripEntities = false, bool stripPlayers = false) {
  auto raw = readFile(p/"level.dat"); require(raw.size() > 8, "Truncated Bedrock level.dat");
  auto level = CompoundTag::Read(Bytes(raw.begin()+8,raw.end()), mcfile::Encoding::LittleEndian);
  require(bool(level), "Invalid Bedrock level.dat NBT");
  auto version = level->listTag(u8"lastOpenedWithVersion");
  require(version && version->size() >= 3, "Missing Bedrock source version");
  json numbers = json::array();
  for (int i=0;i<3;++i) { auto n = version->at(i)->asInt(); require(n != nullptr, "Invalid Bedrock version"); numbers.push_back(n->fValue); }
  require(numbers[0] == 1 && numbers[1].get<int>() >= 12 &&
    (numbers[1].get<int>() < 26 || (numbers[1] == 26 && numbers[2].get<int>() <= 60)),
    "This engine supports Bedrock release formats 1.12 through 1.26.60. Update Luma for a newer format.");
  leveldb::Options options; options.create_if_missing = false;
  leveldb::DB *ptr = nullptr;
  auto status = openDatabase(options, p/"db", &ptr);
  require(status.ok(), "Cannot open Bedrock database: " + status.ToString());
  std::unique_ptr<leveldb::DB> db(ptr);
  std::unique_ptr<leveldb::Iterator> it(db->NewIterator({}));
  json result = {{"edition","bedrock"},{"version",numbers},{"entities",json::array()},{"remotePlayers",0},{"localPlayer",false}};
  leveldb::WriteBatch removals;
  std::set<std::string> actors;
  for (it->SeekToFirst(); it->Valid(); it->Next()) {
    auto key = it->key().ToString(); auto value = it->value().ToString();
    if (key == "~local_player") { result["localPlayer"] = true; if (stripPlayers) removals.Delete(key); }
    if (key.starts_with("player_") || key.starts_with("player_server_")) { result["remotePlayers"] = result["remotePlayers"].get<int>()+1; if (stripPlayers) removals.Delete(key); }
    if (key.starts_with("digp")) {
      require(key.size() == 12 || key.size() == 16, "Invalid actor index key");
      int dim = key.size() == 16 ? le32(key,12) : 0;
      require(dim >= 0 && dim <= 2, "Unsupported entity dimension");
      require(value.size()%8 == 0, "Truncated actor index");
      for (size_t i=0;i<value.size();i+=8) {
        auto actorKey = "actorprefix" + value.substr(i,8);
        require(actors.insert(actorKey).second, "Duplicate actor index reference");
        std::string actor;
        require(db->Get({}, actorKey, &actor).ok(), "Actor index references a missing entity");
        auto e = CompoundTag::Read(actor, mcfile::Encoding::LittleEndian);
        require(bool(e), "Corrupt actor NBT"); entity(result["entities"], *e, dim, true);
      }
      if (stripEntities) removals.Delete(key);
    }
    auto parsed = mcfile::be::DbKey::Parse(key);
    if (parsed.fIsTagged && parsed.fTagged.fTag == static_cast<uint8_t>(mcfile::be::DbKey::Tag::Entity)) {
      auto stream = std::make_shared<mcfile::stream::ByteInputStream>(value.data(),value.size());
      mcfile::stream::InputStreamReader r(stream, mcfile::Encoding::LittleEndian);
      while (stream->pos() < value.size()) {
        auto e = CompoundTag::Read(r); require(bool(e), "Corrupt legacy entity NBT");
        entity(result["entities"], *e, static_cast<int>(parsed.fTagged.fDimension), true);
      }
      if (stripEntities) removals.Delete(key);
    }
    if (parsed.fIsTagged && parsed.fTagged.fTag == static_cast<uint8_t>(mcfile::be::DbKey::Tag::BlockEntity)) {
      auto stream = std::make_shared<mcfile::stream::ByteInputStream>(value.data(),value.size());
      mcfile::stream::InputStreamReader r(stream, mcfile::Encoding::LittleEndian);
      std::string retained;
      while (stream->pos() < value.size()) {
        auto block = CompoundTag::Read(r); require(bool(block), "Corrupt block entity NBT");
        hive(result["entities"],*block,static_cast<int>(parsed.fTagged.fDimension),true,stripEntities);
        auto id = block->string(u8"id",u8"");
        bool frame = id == u8"ItemFrame" || id == u8"GlowItemFrame";
        if (frame) {
          result["entities"].push_back({{"type",id == u8"ItemFrame" ? "minecraft:item_frame" : "minecraft:glow_item_frame"},
            {"dimension",static_cast<int>(parsed.fTagged.fDimension)},
            {"position",{block->int32(u8"x",0)+0.5,block->int32(u8"y",0)+0.5,block->int32(u8"z",0)+0.5}}});
        }
        if (!stripEntities || !frame) {
          auto encoded = CompoundTag::Write(*block,mcfile::Encoding::LittleEndian);
          require(bool(encoded), "Cannot encode block entity"); retained += *encoded;
        }
      }
      if (stripEntities) removals.Put(key,retained);
    }
    if (key.starts_with("actorprefix") && stripEntities) removals.Delete(key);
    if (key == "AutonomousEntities") {
      auto root = CompoundTag::Read(value, mcfile::Encoding::LittleEndian); require(bool(root), "Corrupt autonomous entities");
      if (auto list = root->listTag(u8"AutonomousEntityList")) {
        for (auto const &e : list->fValue) { auto c = e->asCompound(); require(c != nullptr, "Invalid autonomous entity"); entity(result["entities"],*c,2,true); }
      }
      if (stripEntities) removals.Delete(key);
    }
  }
  require(it->status().ok(), "Could not read the complete entity database");
  it.reset();
  if (stripEntities || stripPlayers) require(db->Write({}, &removals).ok(), "Cannot remove excluded records");
  return result;
}
static json scan(fs::path const &p, bool stripEntities = false, bool stripPlayers = false) {
  return fs::is_directory(p/"db") ? scanBedrock(p,stripEntities,stripPlayers) : scanJava(p,stripEntities,stripPlayers);
}

// Only merge selected records; the version engine's terrain remains authoritative.
static void overlayJava(fs::path const &records, fs::path const &terrain, bool entities, bool players) {
  auto source = javaLevel(records), target = javaLevel(terrain);
  auto sd = source->compoundTag(u8"Data"), td = target->compoundTag(u8"Data");
  require(sd && td, "Missing Java level data");
  if (players) {
    if (auto player = sd->compoundTag(u8"Player")) (*td)[u8"Player"] = player;
    if (fs::exists(records/"playerdata")) fs::copy(records/"playerdata",terrain/"playerdata",fs::copy_options::recursive | fs::copy_options::overwrite_existing);
    if (auto uuid = sd->intArrayTag(u8"singleplayer_uuid")) (*td)[u8"singleplayer_uuid"] = uuid;
    if (fs::exists(records/"players/data")) { fs::create_directories(terrain/"players"); fs::copy(records/"players/data",terrain/"players/data",fs::copy_options::recursive | fs::copy_options::overwrite_existing); }
  }
  saveJavaLevel(terrain,*target);
  if (!entities) return;
  json ignored = json::array();
  auto sourceDimensions = javaDimensions(records,sd->int32(u8"DataVersion",0));
  auto targetDimensions = javaDimensions(terrain,td->int32(u8"DataVersion",0));
  for (size_t dimension = 0; dimension < sourceDimensions.size(); ++dimension) {
    auto from = sourceDimensions[dimension].first, to = targetDimensions[dimension].first;
    if (fs::exists(from/"entities")) {
      fs::create_directories(to/"entities");
      fs::copy(from/"entities",to/"entities",fs::copy_options::recursive | fs::copy_options::overwrite_existing);
      // These entity schemas originate in the native engine. Keep their real
      // version so Minecraft can upgrade them independently of newer terrain.
      if (td->int32(u8"DataVersion",0) > 4556) {
        regions(to/"entities",sourceDimensions[dimension].second,ignored,false,
          [](CompoundTag &root,size_t,fs::path const &) {
            root[u8"DataVersion"] = std::make_shared<mcfile::nbt::IntTag>(4556);
          });
      }
    }
    std::map<std::pair<std::string,size_t>,std::shared_ptr<CompoundTag>> chunks;
    regions(from/"region",0,ignored,false,[&](CompoundTag &root,size_t slot,fs::path const &file) {
      auto level = root.compoundTag(u8"Level"); auto src = level ? level.get() : &root;
      auto selected = std::make_shared<CompoundTag>();
      if (auto list = src->listTag(u8"Entities"); list && !list->empty()) (*selected)[u8"Entities"] = list;
      auto hives = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Compound);
      if (auto tiles = src->listTag(level ? u8"TileEntities" : u8"block_entities")) {
        for (auto const &tile : tiles->fValue) {
          auto block = tile->asCompound(); require(block,"Invalid block entity");
          if (block->listTag(u8"bees") || block->listTag(u8"Bees")) hives->push_back(tile);
        }
      }
      if (!hives->empty()) (*selected)[u8"block_entities"] = hives;
      if (!selected->empty()) chunks[{file.filename().string(),slot}] = selected;
    },false);
    regions(to/"region",0,ignored,false,[&](CompoundTag &root,size_t slot,fs::path const &file) {
      auto found = chunks.find({file.filename().string(),slot});
      if (found == chunks.end()) return;
      auto srcLevel = found->second->compoundTag(u8"Level");
      auto dstLevel = root.compoundTag(u8"Level");
      auto src = srcLevel ? srcLevel : found->second;
      auto dst = dstLevel ? dstLevel.get() : &root;
      if (auto list = src->listTag(u8"Entities")) (*dst)[u8"Entities"] = list;
      auto sourceTiles = src->listTag(srcLevel ? u8"TileEntities" : u8"block_entities");
      auto tiles = dst->listTag(dstLevel ? u8"TileEntities" : u8"block_entities");
      if (!sourceTiles || !tiles) return;
      for (auto const &entry : sourceTiles->fValue) {
        auto bee = entry->asCompound(); require(bee, "Invalid block entity overlay");
        auto occupants = bee->listTag(u8"bees"); auto key = u8"bees";
        if (!occupants) { occupants = bee->listTag(u8"Bees"); key = u8"Bees"; }
        if (!occupants) continue;
        bool matched = false;
        for (auto const &tile : tiles->fValue) {
          auto dstTile = std::dynamic_pointer_cast<CompoundTag>(tile); require(bool(dstTile), "Invalid terrain block entity");
          if (dstTile->int32(u8"x") == bee->int32(u8"x") && dstTile->int32(u8"y") == bee->int32(u8"y") && dstTile->int32(u8"z") == bee->int32(u8"z")) {
            require(dstTile->string(u8"id") == bee->string(u8"id"), "Hive block was not retained by the selected target version");
            (*dstTile)[key] = occupants; matched = true; break;
          }
        }
        require(matched || occupants->empty(), "Hive occupants have no target hive block");
      }
    });
  }
}
static void overlayBedrock(fs::path const &records, fs::path const &terrain, bool entities, bool players) {
  leveldb::Options options; options.create_if_missing = false;
  leveldb::DB *sp = nullptr, *tp = nullptr;
  auto sourceStatus = openDatabase(options,records/"db",&sp);
  require(sourceStatus.ok(), "Cannot open entity records: " + sourceStatus.ToString());
  std::unique_ptr<leveldb::DB> source(sp);
  auto targetStatus = openDatabase(options,terrain/"db",&tp);
  require(targetStatus.ok(), "Cannot open converted terrain: " + targetStatus.ToString());
  std::unique_ptr<leveldb::DB> target(tp);
  std::unique_ptr<leveldb::Iterator> it(source->NewIterator({}));
  leveldb::WriteBatch writes;
  for (it->SeekToFirst();it->Valid();it->Next()) {
    auto key = it->key().ToString(), value = it->value().ToString();
    auto parsed = mcfile::be::DbKey::Parse(key);
    if ((players && (key == "~local_player" || key.starts_with("player_"))) ||
        (entities && (key.starts_with("digp") || key.starts_with("actorprefix") || key == "AutonomousEntities" ||
          (parsed.fIsTagged && parsed.fTagged.fTag == static_cast<uint8_t>(mcfile::be::DbKey::Tag::Entity))))) writes.Put(key,value);
    if (!entities || !parsed.fIsTagged || parsed.fTagged.fTag != static_cast<uint8_t>(mcfile::be::DbKey::Tag::BlockEntity)) continue;
    auto decode = [](std::string const &bytes) {
      std::vector<std::shared_ptr<CompoundTag>> list;
      auto stream = std::make_shared<mcfile::stream::ByteInputStream>(bytes.data(),bytes.size());
      mcfile::stream::InputStreamReader r(stream,mcfile::Encoding::LittleEndian);
      while (stream->pos() < bytes.size()) { auto tag = CompoundTag::Read(r); require(bool(tag), "Invalid block entity overlay"); list.push_back(tag); }
      return list;
    };
    std::string existing; auto status = target->Get({},key,&existing);
    require(status.ok() || status.IsNotFound(), "Cannot read target block entities");
    auto tiles = decode(existing);
    for (auto const &tile : decode(value)) {
      auto id = tile->string(u8"id",u8"");
      bool frame = id == u8"ItemFrame" || id == u8"GlowItemFrame";
      auto occupants = tile->listTag(u8"Occupants");
      if (!frame && !occupants) continue;
      bool matched = false;
      for (auto &dst : tiles) {
        if (dst->int32(u8"x") == tile->int32(u8"x") && dst->int32(u8"y") == tile->int32(u8"y") && dst->int32(u8"z") == tile->int32(u8"z")) {
          if (frame) dst = tile;
          else { require(dst->string(u8"id") == tile->string(u8"id"), "Hive block was lost"); (*dst)[u8"Occupants"] = occupants; }
          matched = true; break;
        }
      }
      if (!matched && frame) tiles.push_back(tile);
      else require(matched || !occupants || occupants->empty(), "Hive occupants have no target hive block");
    }
    std::string encoded;
    for (auto const &tile : tiles) { auto bytes = CompoundTag::Write(*tile,mcfile::Encoding::LittleEndian); require(bool(bytes), "Cannot encode merged block entities"); encoded += *bytes; }
    writes.Put(key,encoded);
  }
  require(it->status().ok(), "Incomplete record overlay"); it.reset();
  require(target->Write({},&writes).ok(), "Cannot save transferred records");
}
static int run(std::vector<std::string> const &args) {
  require(args.size() >= 3, "Expected scan or convert command");
  auto input = fs::u8path(args[2]);
  if (args[1] == "scan") { std::cout << scan(input).dump() << std::endl; return 0; }
  if (args[1] == "identity") {
    auto root = javaLevel(input); auto data = root->compoundTag(u8"Data");
    auto player = data ? data->compoundTag(u8"Player") : nullptr;
    if (auto uuid = player ? player->intArrayTag(u8"UUID") : nullptr) (*data)[u8"singleplayer_uuid"] = uuid;
    if (args.size() == 4) {
      auto version = data->compoundTag(u8"Version");
      require(bool(version),"Missing Java version metadata");
      (*version)[u8"Name"] = std::make_shared<mcfile::nbt::StringTag>(std::u8string(args[3].begin(),args[3].end()));
    }
    saveJavaLevel(input,*root);
    std::cout << scan(input).dump() << std::endl; return 0;
  }
  if (args[1] == "restore-player") {
    require(args.size() == 4,"Invalid player adaptation arguments");
    auto output = fs::u8path(args[3]);
    auto source = javaLevel(input), target = javaLevel(output);
    auto sd = source->compoundTag(u8"Data"), td = target->compoundTag(u8"Data");
    require(sd && td,"Missing Java level data");
    auto player = sd->compoundTag(u8"Player");
    if (auto id = sd->intArrayTag(u8"singleplayer_uuid"); sd->int32(u8"DataVersion",0) >= 4786 && id) {
      auto uuid = je2be::Uuid::FromIntArray(*id); require(bool(uuid),"Invalid player UUID");
      auto file = input/"players/data"/(utf8(uuid->toString())+".dat");
      if (fs::exists(file)) player = javaNbtFile(file);
    }
    if (player) {
      auto converted = td->compoundTag(u8"Player");
      require(bool(converted),"Version engine did not adapt the local player's inventory and position");
      for (auto const &[key,value] : player->fValue) {
        if (!converted->fValue.contains(key)) (*converted)[key] = value;
      }
      if (auto uuid = javaUuid(*player)) (*converted)[u8"UUID"] = uuid->toIntArrayTag();
    }
    saveJavaLevel(output,*target);
    std::cout << scan(output).dump() << std::endl; return 0;
  }
  if (args[1] == "strip") {
    require(args.size() == 5,"Invalid strip arguments");
    scan(input,args[3] == "1",args[4] == "1");
    std::cout << scan(input).dump() << std::endl; return 0;
  }
  if (args[1] == "overlay") {
    require(args.size() == 6,"Invalid overlay arguments");
    auto terrain = fs::u8path(args[3]); bool entities = args[4] == "1", players = args[5] == "1";
    require(fs::is_directory(input/"db") == fs::is_directory(terrain/"db"),"Overlay editions differ");
    scan(terrain,true,true);
    if (fs::is_directory(input/"db")) overlayBedrock(input,terrain,entities,players);
    else overlayJava(input,terrain,entities,players);
    if (players && fs::exists(input/"luma-java-player-uuid.txt")) fs::copy_file(input/"luma-java-player-uuid.txt",terrain/"luma-java-player-uuid.txt",fs::copy_options::overwrite_existing);
    std::cout << scan(terrain).dump() << std::endl; return 0;
  }
  require(args[1] == "convert" && (args.size() == 7 || args.size() == 8), "Invalid conversion arguments");
  if (args.size() == 8) {
    int version = std::stoi(args[7]);
    require(args[4] == "java" && version >= 1519 && version <= 4556,"Invalid Java entity schema version");
    je2be::kJavaDataVersion = version;
  }
  auto output = fs::u8path(args[3]); bool entities = args[5] == "1", players = args[6] == "1";
  require(!fs::exists(output), "Output folder must not already exist");
  auto census = scan(input);
  if (entities) {
    for (auto const &e : census["entities"]) {
      auto type = e["type"].get<std::string>();
      require(type.find(':') == std::string::npos ||
        (type.starts_with("minecraft:") && type.find(':',10) == std::string::npos),
        "Unsupported entity cannot be transferred: " + type);
    }
  }
  require(!players || census["remotePlayers"] == 0, "Additional players require Java UUID / Bedrock XUID mappings. Disable players or use a single-player save.");
  if (!entities || !players) scan(input,!entities,!players);
  auto threads = std::max(1u,std::min(8u,std::thread::hardware_concurrency()));
  je2be::Status status;
  if (args[4] == "bedrock" && census["edition"] == "java") {
    je2be::java::Options options; options.fTempDirectory = input.parent_path(); options.fDbTempDirectory = input.parent_path();
    status = je2be::java::Converter::Run(input,output,options,threads);
    if (status.ok() && players) {
      auto level = javaLevel(input); auto data = level->compoundTag(u8"Data");
      auto player = data ? data->compoundTag(u8"Player") : nullptr;
      auto uuid = player ? player->intArrayTag(u8"UUID") : nullptr;
      if (uuid) {
        if (auto u = je2be::Uuid::FromIntArray(*uuid)) {
          auto text = utf8(u->toString()); writeFile(output/"luma-java-player-uuid.txt",Bytes(text.begin(),text.end()));
        }
      }
    }
  } else if (args[4] == "java" && census["edition"] == "bedrock") {
    je2be::bedrock::Options options; options.fTempDirectory = input.parent_path();
    if (players && fs::exists(input/"luma-java-player-uuid.txt")) {
      auto bytes = readFile(input/"luma-java-player-uuid.txt");
      auto uuid = je2be::Uuid::FromString(std::u8string(bytes.begin(),bytes.end()));
      require(bool(uuid), "Invalid archived Java player UUID");
      options.fLocalPlayer = std::make_shared<je2be::Uuid>(*uuid);
    }
    status = je2be::bedrock::Converter::Run(input,output,options,threads);
  } else throw std::runtime_error("Choose the other edition as the conversion target");
  if (!status.ok()) {
    auto error = status.error();
    std::string details = error->fWhat;
    if (details.empty() && !error->fTrace.empty()) {
      auto const &where = error->fTrace.front();
      details = where.fFile + ":" + std::to_string(where.fLine);
    }
    throw std::runtime_error("World engine failed to convert the save: " + details);
  }
  if (args[4] == "java" && je2be::kJavaDataVersion < 4556) {
    auto level = javaLevel(output); adaptJavaTag(*level,je2be::kJavaDataVersion); saveJavaLevel(output,*level);
    json ignored = json::array();
    for (auto const &[directory,dim] : javaDimensions(output,je2be::kJavaDataVersion)) {
      for (auto const &name : {"region","entities"}) regions(directory/name,dim,ignored,false,
        [](CompoundTag &tag,size_t,fs::path const &) { adaptJavaTag(tag,je2be::kJavaDataVersion); });
    }
    if (fs::exists(output/"playerdata")) {
      for (auto const &entry : fs::directory_iterator(output/"playerdata")) {
        if (entry.path().extension() != ".dat") continue;
        auto player = javaNbtFile(entry.path()); adaptJavaTag(*player,je2be::kJavaDataVersion); saveJavaNbtFile(entry.path(),*player);
      }
    }
  }
  if (!entities || !players) scan(output,!entities,!players);
  auto saved = scan(output);
  if (entities) {
    auto const &registered = args[4] == "java" ? kJavaEntityTypes : kBedrockEntityTypes;
    for (auto const &e : saved["entities"]) {
      auto type = e["type"].get<std::string>();
      if (type.ends_with("@hive")) type.resize(type.size()-5);
      bool legacyPigman = args[4] == "java" && je2be::kJavaDataVersion < 2566 && type == "minecraft:zombie_pigman";
      require(registered.contains(type) || legacyPigman, "Entity has no supported target-edition schema: " + type);
    }
  }
  std::cout << saved.dump() << std::endl; return 0;
}
#ifdef _WIN32
int wmain(int argc, wchar_t **argv) {
  std::vector<std::string> args;
  for (int i=0;i<argc;++i) { auto s = fs::path(argv[i]).u8string(); args.push_back(utf8(s)); }
#else
int main(int argc, char **argv) {
  std::vector<std::string> args(argv,argv+argc);
#endif
  try { return run(args); }
  catch (std::exception const &e) { std::cerr << e.what() << std::endl; return 1; }
}
