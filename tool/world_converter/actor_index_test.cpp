// SPDX-License-Identifier: GPL-3.0-only
#define LUMA_WORLD_CONVERTER_NO_ENTRYPOINT
#include "main.cpp"

int main() {
  auto root = fs::temp_directory_path()/("luma-actor-index-test-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
  fs::create_directories(root);
  try {
    CompoundTag level;
    auto version = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Int);
    for (int n : {1,21,120}) version->push_back(std::make_shared<mcfile::nbt::IntTag>(n));
    level[u8"lastOpenedWithVersion"] = version;
    auto encoded = CompoundTag::Write(level,mcfile::Encoding::LittleEndian); require(bool(encoded),"Cannot encode fixture");
    Bytes bytes(8,0); bytes.insert(bytes.end(),encoded->begin(),encoded->end()); writeFile(root/"level.dat",bytes);
    leveldb::Options options; options.create_if_missing = true; leveldb::DB *raw = nullptr;
    require(openDatabase(options,root/"db",&raw).ok(),"Cannot create fixture database");
    std::unique_ptr<leveldb::DB> db(raw);
    CompoundTag actor; actor[u8"identifier"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:cow");
    auto pos = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Float);
    for (float n : {2.f,64.f,2.f}) pos->push_back(std::make_shared<mcfile::nbt::FloatTag>(n));
    actor[u8"Pos"] = pos;
    auto actorBytes = CompoundTag::Write(actor,mcfile::Encoding::LittleEndian);
    std::string id(8,'\1'), index = "digp"+std::string(8,'\0');
    require(db->Put({},"actorprefix"+id,*actorBytes).ok(),"Cannot save actor");
    require(db->Put({},index,id+id).ok(),"Cannot save repeated index"); db.reset();
    auto census = scanBedrock(root);
    require(census["entities"].size() == 1,"A repeated actor must be counted exactly once");
    auto reopen = [&]() {
      leveldb::DB *pointer = nullptr;
      require(openDatabase(options,root/"db",&pointer).ok(),"Cannot reopen fixture database");
      return std::unique_ptr<leveldb::DB>(pointer);
    };
    db = reopen(); std::string value;
    require(db->Get({},index,&value).ok() && value == id+id,"Read-only scan modified indexes");
    auto other = mcfile::be::DbKey::Digp(1,0,mcfile::Dimension::Overworld);
    require(db->Put({},other,id+std::string(8,'\2')).ok(),"Cannot save stale and cross-chunk references");
    auto orphan = "actorprefix"+std::string(8,'\3');
    require(db->Put({},orphan,*actorBytes).ok(),"Cannot save historical unindexed actor");
    pos->fValue[0] = std::make_shared<mcfile::nbt::FloatTag>(18.f);
    actorBytes = CompoundTag::Write(actor,mcfile::Encoding::LittleEndian);
    require(db->Put({},"actorprefix"+id,*actorBytes).ok(),"Cannot move actor"); db.reset();
    census = scanBedrock(root,false,false,true);
    require(census["entities"].size() == 1,"Normalization lost or resurrected an actor");
    require(census["warnings"].size() == 2,"Repeated and stale references need visible warnings");
    db = reopen();
    require(db->Get({},index,&value).IsNotFound(),"Outdated chunk index survived normalization");
    require(db->Get({},other,&value).ok() && value == id,"Live actor was not indexed once in its current chunk");
    require(db->Get({},orphan,&value).ok(),"Historical unindexed NBT was modified");
    auto nether = mcfile::be::DbKey::Digp(1,0,mcfile::Dimension::Nether);
    require(db->Put({},nether,id).ok(),"Cannot create dimension conflict"); db.reset();
    bool rejected = false;
    try { scanBedrock(root,false,false,true); }
    catch (std::exception const &e) { rejected = std::string(e.what()).find("dimension") != std::string::npos; }
    require(rejected,"Ambiguous cross-dimension indexes must fail");
    actor[u8"DimensionId"] = std::make_shared<mcfile::nbt::IntTag>(1);
    actorBytes = CompoundTag::Write(actor,mcfile::Encoding::LittleEndian);
    db = reopen(); require(db->Put({},"actorprefix"+id,*actorBytes).ok(),"Cannot save authoritative dimension"); db.reset();
    census = scanBedrock(root,false,false,true);
    require(census["entities"].size() == 1 && census["entities"][0]["dimension"] == 1,"Authoritative actor dimension was lost");
    db = reopen(); require(db->Put({},"actorprefix"+id,"invalid NBT").ok(),"Cannot corrupt actor"); db.reset();
    rejected = false;
    try { scanBedrock(root,false,false,true); }
    catch (std::exception const &e) { rejected = std::string(e.what()).find("Corrupt actor") != std::string::npos; }
    require(rejected,"Corrupt live entities must not disappear silently");
    db = reopen(); require(db->Put({},"actorprefix"+id,*actorBytes).ok(),"Cannot restore actor"); db.reset();
    scanBedrock(root,true);
    require(scanBedrock(root)["entities"].empty(),"Excluded actors survived stripping");
    auto output = root/"java"; fs::create_directories(output);
    auto javaRoot = std::make_shared<CompoundTag>(), javaData = std::make_shared<CompoundTag>();
    auto player = std::make_shared<CompoundTag>(); std::vector<int32_t> localUuid{1,2,3,4};
    auto savedUuid = localUuid;
    (*player)[u8"UUID"] = std::make_shared<mcfile::nbt::IntArrayTag>(savedUuid);
    (*javaData)[u8"Player"] = player;
    (*javaData)[u8"DataVersion"] = std::make_shared<mcfile::nbt::IntTag>(4556);
    (*javaRoot)[u8"Data"] = javaData; saveJavaLevel(output,*javaRoot);
    auto projectile = std::make_shared<CompoundTag>(); projectile->fValue = actor.fValue;
    projectile->erase(u8"DimensionId");
    (*projectile)[u8"identifier"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:arrow");
    (*projectile)[u8"UniqueID"] = std::make_shared<mcfile::nbt::LongTag>(123);
    (*projectile)[u8"OwnerNew"] = std::make_shared<mcfile::nbt::LongTag>(321);
    auto motion = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Float);
    for (int i=0;i<3;i++) motion->push_back(std::make_shared<mcfile::nbt::FloatTag>(0.f));
    (*projectile)[u8"Motion"] = motion;
    pos->fValue[0] = std::make_shared<mcfile::nbt::FloatTag>(-1.25f);
    db = reopen();
    auto arrowId = std::string(8,'\4'), tridentId = std::string(8,'\5');
    auto encodedArrow = CompoundTag::Write(*projectile,mcfile::Encoding::LittleEndian);
    require(db->Put({},"actorprefix"+arrowId,*encodedArrow).ok(),"Cannot save arrow fixture");
    (*projectile)[u8"identifier"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:thrown_trident");
    (*projectile)[u8"UniqueID"] = std::make_shared<mcfile::nbt::LongTag>(456);
    auto item = std::make_shared<CompoundTag>();
    (*item)[u8"Name"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:trident");
    (*item)[u8"Count"] = std::make_shared<mcfile::nbt::ByteTag>(1);
    (*item)[u8"Damage"] = std::make_shared<mcfile::nbt::ShortTag>(0);
    auto itemTag = std::make_shared<CompoundTag>();
    (*itemTag)[u8"Damage"] = std::make_shared<mcfile::nbt::IntTag>(7);
    (*item)[u8"tag"] = itemTag;
    (*projectile)[u8"Trident"] = item;
    auto encodedTrident = CompoundTag::Write(*projectile,mcfile::Encoding::LittleEndian);
    require(db->Put({},"actorprefix"+tridentId,*encodedTrident).ok(),"Cannot save trident fixture");
    require(db->Put({},mcfile::be::DbKey::Digp(-1,0,mcfile::Dimension::Overworld),arrowId+tridentId).ok(),"Cannot save projectile-only chunk");
    CompoundTag local; local[u8"UniqueID"] = std::make_shared<mcfile::nbt::LongTag>(321);
    auto localBytes = CompoundTag::Write(local,mcfile::Encoding::LittleEndian);
    require(db->Put({},"~local_player",*localBytes).ok(),"Cannot save owner fixture"); db.reset();
    recoverBedrockActors(root,output);
    require(scanJava(output)["entities"].size() == 2,"Projectile-only chunks must preserve both arrow and trident");
    recoverBedrockActors(root,output);
    require(scanJava(output)["entities"].size() == 2,"Projectile recovery duplicated existing identities");
    bool checkedTrident = false; json ignored = json::array();
    regions(output/"entities",0,ignored,false,[&](CompoundTag &chunk,size_t,fs::path const &) {
      for (auto const &entry : chunk.listTag(u8"Entities")->fValue) {
        auto entity = entry->asCompound();
        auto owner = entity->intArrayTag(u8"Owner");
        require(owner && owner->fValue == localUuid,"Projectile owner identity was lost");
        if (entity->string(u8"id",u8"") != u8"minecraft:trident") continue;
        auto item = entity->compoundTag(u8"item");
        require(item && item->string(u8"id",u8"") == u8"minecraft:trident","Trident item was not converted");
        auto components = item->compoundTag(u8"components");
        require(components && components->int32(u8"minecraft:damage",-1) == 7,"Trident durability was lost");
        checkedTrident = true;
      }
    },false);
    require(checkedTrident,"Saved output has no trident");
    // Java 1.20.4 predates item components: the thrown item is "Trident" with Count/tag.
    auto legacy = root/"java-1.20.4"; fs::create_directories(legacy);
    (*javaData)[u8"DataVersion"] = std::make_shared<mcfile::nbt::IntTag>(3700);
    saveJavaLevel(legacy,*javaRoot);
    je2be::kJavaDataVersion = 3700;
    recoverBedrockActors(root,legacy);
    je2be::kJavaDataVersion = 4556;
    require(scanJava(legacy)["entities"].size() == 2,"Legacy targets must preserve both arrow and trident");
    checkedTrident = false; bool checkedArrow = false;
    regions(legacy/"entities",0,ignored,false,[&](CompoundTag &chunk,size_t,fs::path const &) {
      require(chunk.int32(u8"DataVersion",0) == 3700,"Legacy projectile chunk has the wrong schema version");
      for (auto const &entry : chunk.listTag(u8"Entities")->fValue) {
        auto entity = entry->asCompound();
        require(!entity->compoundTag(u8"item"),"Legacy projectiles must not use the component item field");
        if (entity->string(u8"id",u8"") == u8"minecraft:arrow") {
          CompoundTag downgraded; downgraded.fValue = entity->fValue;
          adaptJavaTag(downgraded,2230);
          auto most = downgraded.int64(u8"OwnerUUIDMost"), least = downgraded.int64(u8"OwnerUUIDLeast");
          require(!downgraded.intArrayTag(u8"Owner") && most && least &&
            *most == ((int64_t(1) << 32) | 2) && *least == ((int64_t(3) << 32) | 4),
            "Pre-1.16 arrow owner must use OwnerUUIDMost/OwnerUUIDLeast");
          checkedArrow = true;
          continue;
        }
        auto item = entity->compoundTag(u8"Trident");
        require(item && item->string(u8"id",u8"") == u8"minecraft:trident","Legacy trident item was not converted");
        require(item->byte(u8"Count",0) == 1,"Legacy trident item lost its count");
        auto tag = item->compoundTag(u8"tag");
        require(tag && tag->int32(u8"Damage",-1) == 7,"Legacy trident durability was lost");
        checkedTrident = true;
      }
    },false);
    require(checkedTrident && checkedArrow,"Legacy output is missing a projectile");

    // A naturally generated nest saves its bee as only ActorIdentifier with an empty SaveData.
    auto hive = std::make_shared<CompoundTag>();
    (*hive)[u8"id"] = std::make_shared<mcfile::nbt::StringTag>(u8"Beehive");
    (*hive)[u8"x"] = std::make_shared<mcfile::nbt::IntTag>(1);
    (*hive)[u8"y"] = std::make_shared<mcfile::nbt::IntTag>(64);
    (*hive)[u8"z"] = std::make_shared<mcfile::nbt::IntTag>(1);
    auto occupants = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Compound);
    auto natural = std::make_shared<CompoundTag>();
    (*natural)[u8"ActorIdentifier"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:bee<>");
    (*natural)[u8"SaveData"] = std::make_shared<CompoundTag>();
    (*natural)[u8"TicksLeftToStay"] = std::make_shared<mcfile::nbt::IntTag>(46);
    occupants->push_back(natural);
    (*hive)[u8"Occupants"] = occupants;
    auto hiveBytes = CompoundTag::Write(*hive,mcfile::Encoding::LittleEndian);
    db = reopen();
    require(db->Put({},mcfile::be::DbKey::BlockEntity(0,0,mcfile::Dimension::Overworld),*hiveBytes).ok(),"Cannot save hive fixture");
    db.reset();
    bool counted = false;
    auto bedrockCensus = scanBedrock(root);
    for (auto const &e : bedrockCensus["entities"]) counted = counted || e["type"] == "minecraft:bee@hive";
    require(counted,"A natural nest's bee must be counted from its ActorIdentifier");
    auto hiveWorld = root/"java-hive"; fs::create_directories(hiveWorld);
    (*javaData)[u8"DataVersion"] = std::make_shared<mcfile::nbt::IntTag>(4556);
    saveJavaLevel(hiveWorld,*javaRoot);
    auto terrain = std::make_shared<CompoundTag>();
    (*terrain)[u8"DataVersion"] = std::make_shared<mcfile::nbt::IntTag>(4556);
    (*terrain)[u8"Status"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:full");
    (*terrain)[u8"sections"] = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Compound);
    auto javaHive = std::make_shared<CompoundTag>();
    (*javaHive)[u8"id"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:beehive");
    (*javaHive)[u8"x"] = std::make_shared<mcfile::nbt::IntTag>(1);
    (*javaHive)[u8"y"] = std::make_shared<mcfile::nbt::IntTag>(64);
    (*javaHive)[u8"z"] = std::make_shared<mcfile::nbt::IntTag>(1);
    auto tiles = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Compound); tiles->push_back(javaHive);
    (*terrain)[u8"block_entities"] = tiles;
    // A 1.17+ terrain chunk's own Entities list is ignored by the game and must not be counted.
    auto ghosts = std::make_shared<mcfile::nbt::ListTag>(Tag::Type::Compound);
    auto ghost = std::make_shared<CompoundTag>(); ghost->fValue = actor.fValue;
    (*ghost)[u8"id"] = std::make_shared<mcfile::nbt::StringTag>(u8"minecraft:cow");
    ghosts->push_back(ghost);
    (*terrain)[u8"Entities"] = ghosts;
    appendEntityChunks(hiveWorld/"region",{{{"r.0.0.mca",0},terrain}},false);
    completeBedrockHives(root,hiveWorld);
    auto hiveCensus = scanJava(hiveWorld)["entities"];
    require(hiveCensus.size() == 1 && hiveCensus[0]["type"] == "minecraft:bee@hive",
      "The rebuilt hive must hold the bee, and the ignored terrain Entities copy must not count");
    bool checkedBee = false;
    regions(hiveWorld/"region",0,ignored,false,[&](CompoundTag &chunk,size_t,fs::path const &) {
      auto bees = chunk.listTag(u8"block_entities")->at(0)->asCompound()->listTag(u8"bees");
      require(bees && bees->size() == 1,"Natural nest bee was not written to the Java hive");
      auto bee = bees->at(0)->asCompound();
      require(bee->compoundTag(u8"entity_data")->string(u8"id",u8"") == u8"minecraft:bee","Natural nest bee lost its kind");
      require(bee->int32(u8"ticks_in_hive",-1) == 0 && bee->int32(u8"min_ticks_in_hive",-1) == 46,"Java hive occupants need both stay timers");
      checkedBee = true;
    },false);
    require(checkedBee,"Java hive chunk is missing");
    fs::remove_all(root);
    std::cout << "PASS: actor indexes, corruption/exclusions and projectile-only chunks with trident item/durability, owner identity and no duplicates, on component and pre-1.20.5 targets; natural nests; ignored terrain entity copies" << std::endl; return 0;
  } catch (std::exception const &e) { fs::remove_all(root); std::cerr << e.what() << std::endl; return 1; }
}
