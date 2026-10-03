# Expose the engine's existing version-aware NBT writers to the worker.
# Each conversion runs in a separate process; the selected version is set once
# before the engine starts its threads.
file(READ "${je2be_SOURCE_DIR}/src/_data-version.hpp" version_header)
if(version_header MATCHES "constexpr int kJavaDataVersion = 4556;")
  string(REPLACE "constexpr int kJavaDataVersion = 4556;"
    "inline int kJavaDataVersion = 4556;" version_header "${version_header}")
  string(REPLACE "return kJavaDataVersionMaxLegacy;"
    "return kJavaDataVersion < kJavaDataVersionMaxLegacy ? kJavaDataVersion : kJavaDataVersionMaxLegacy;"
    version_header "${version_header}")
  file(WRITE "${je2be_SOURCE_DIR}/src/_data-version.hpp" "${version_header}")
elseif(NOT version_header MATCHES "inline int kJavaDataVersion = 4556;")
  message(FATAL_ERROR "The pinned engine version interface has changed")
endif()

# Windows scanners can briefly hold newly created database files. Retry only
# I/O failures and preserve the original LevelDB error when they persist.
file(READ "${je2be_SOURCE_DIR}/src/java/_entity-store.hpp" entity_store)
set(old_open "    if (!DB::Open(o, dir, &db).ok()) {\n      return nullptr;\n    }")
set(new_open "    for (int attempt = 0;; ++attempt) {\n      auto status = DB::Open(o, dir, &db);\n      if (status.ok()) break;\n      if (!status.IsIOError() || attempt == 4) throw std::runtime_error(\"Cannot create entity database: \" + status.ToString());\n      std::this_thread::sleep_for(std::chrono::milliseconds(100 << attempt));\n    }")
string(FIND "${entity_store}" "${old_open}" open_offset)
if(NOT open_offset EQUAL -1)
  string(REPLACE "${old_open}" "${new_open}" entity_store "${entity_store}")
  string(REPLACE "#include <mutex>" "#include <mutex>\n#include <thread>\n#include <chrono>\n#include <stdexcept>" entity_store "${entity_store}")
  file(WRITE "${je2be_SOURCE_DIR}/src/java/_entity-store.hpp" "${entity_store}")
elseif(NOT entity_store MATCHES "Cannot create entity database")
  message(FATAL_ERROR "The pinned entity store interface has changed")
endif()
