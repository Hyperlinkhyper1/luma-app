// SPDX-License-Identifier: GPL-3.0-only
#include <je2be.hpp>
#include <leveldb/db.h>
#include <leveldb/write_batch.h>
#include <nlohmann/json.hpp>
#include <fstream>
#include <iostream>
#include <thread>
#include "entity_types.hpp"

namespace fs = std::filesystem;
using mcfile::nbt::CompoundTag;
using mcfile::nbt::Tag;
using json = nlohmann::json;
using Bytes = std::vector<uint8_t>;

static void require(bool ok, std::string const &message) {
  if (!ok) throw std::runtime_error(message);
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
static auto javaLevel(fs::path const &p) {
  auto raw = readFile(p / "level.dat");
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
static void saveJavaLevel(fs::path const &p, CompoundTag const &tag) {
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
  writeFile(p / "level.dat", compressed);
}

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
static void regions(fs::path const &dir, int dim, json &entities, bool strip) {
  if (!fs::exists(dir)) return;
  for (auto const &entry : fs::directory_iterator(dir)) {
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
      if (!strip) continue;
      (container ? container : root)->erase(u8"Entities");
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
    if (strip) writeFile(entry.path(), rewritten);
  }
}
static int playerDimension(CompoundTag const &p) {
  auto d = p.string(u8"Dimension", u8"minecraft:overworld");
  if (d == u8"minecraft:the_nether") return 1;
  if (d == u8"minecraft:the_end") return 2;
  return p.int32(u8"Dimension", 0) == -1 ? 1 : p.int32(u8"Dimension", 0);
}
static json scanJava(fs::path const &p, bool stripEntities = false, bool stripPlayers = false) {
  auto level = javaLevel(p); auto data = level->compoundTag(u8"Data");
  require(bool(data), "Missing Java world Data");
  int version = data->int32(u8"DataVersion", 0);
  require(version >= 1519 && version <= 4556, "Supported Java source versions: 1.13 through 1.21.10");
  require(!fs::exists(p / "dimensions"), "Custom dimensions are not supported; refusing to omit them");
  json result = {{"edition", "java"}, {"version", version}, {"entities", json::array()}, {"remotePlayers", 0}, {"localPlayer", false}};
  auto &entities = result["entities"];
  for (auto const &[dir, dim] : std::vector<std::pair<fs::path, int>>{{p,0},{p/"DIM-1",1},{p/"DIM1",2}}) {
    regions(dir/"region", dim, entities, stripEntities);
    regions(dir/"entities", dim, entities, stripEntities);
  }
  auto player = data->compoundTag(u8"Player");
  std::string localUuid;
  if (player) {
    result["localPlayer"] = true;
    if (auto uuid = player->intArrayTag(u8"UUID")) {
      if (auto u = je2be::Uuid::FromIntArray(*uuid)) localUuid = utf8(u->toString());
    }
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
  if (fs::exists(p/"playerdata")) {
    for (auto const &f : fs::directory_iterator(p/"playerdata")) {
      if (f.path().extension() == ".dat" && f.path().stem().string() != localUuid) result["remotePlayers"] = result["remotePlayers"].get<int>() + 1;
    }
    if (stripPlayers) fs::remove_all(p/"playerdata");
  }
  if (stripPlayers) data->erase(u8"Player");
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
  require(numbers[0] == 1 && (numbers[1].get<int>() < 21 || (numbers[1] == 21 && numbers[2].get<int>() <= 120)), "Bedrock sources newer than 1.21.120 are not supported");
  leveldb::Options options; options.create_if_missing = false;
  leveldb::DB *ptr = nullptr;
  auto status = leveldb::DB::Open(options, p/"db", &ptr);
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
static int run(std::vector<std::string> const &args) {
  require(args.size() >= 3, "Expected scan or convert command");
  auto input = fs::u8path(args[2]);
  if (args[1] == "scan") { std::cout << scan(input).dump() << std::endl; return 0; }
  require(args[1] == "convert" && args.size() == 7, "Invalid conversion arguments");
  auto output = fs::u8path(args[3]); bool entities = args[5] == "1", players = args[6] == "1";
  require(!fs::exists(output), "Output folder must not already exist");
  auto census = scan(input);
  if (entities) {
    for (auto const &e : census["entities"]) {
      auto type = e["type"].get<std::string>();
      require(type.starts_with("minecraft:") && type.find(':',10) == std::string::npos,
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
  require(status.ok(), "World engine failed to convert the save");
  if (!entities || !players) scan(output,!entities,!players);
  auto saved = scan(output);
  if (entities) {
    auto const &registered = args[4] == "java" ? kJavaEntityTypes : kBedrockEntityTypes;
    for (auto const &e : saved["entities"]) {
      auto type = e["type"].get<std::string>();
      if (type.ends_with("@hive")) type.resize(type.size()-5);
      require(registered.contains(type), "Entity has no supported target-edition schema: " + type);
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
