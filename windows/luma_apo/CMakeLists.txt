# luma's system-wide microphone EQ: the APO that audiodg loads, and the
# elevated helper that installs it. See luma_apo.cpp and setup.cpp.
#
# Built as part of the Flutter Windows build (added from windows/
# CMakeLists.txt) and installed next to luma.exe, so the Inno installer
# ships both. Also buildable on its own for apo_test:
#   cmake -S windows/luma_apo -B build/luma_apo
#   cmake --build build/luma_apo --config Release --target luma_apo_test
cmake_minimum_required(VERSION 3.15)
project(luma_apo LANGUAGES CXX)

# audiodg and a bare elevated helper must not depend on the VC++ runtime
# being installed, so link it statically.
set(LUMA_APO_RUNTIME "MultiThreaded$<$<CONFIG:Debug>:Debug>")

function(luma_apo_settings TARGET)
  target_compile_features(${TARGET} PRIVATE cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /EHsc /wd4100)
  target_compile_definitions(${TARGET} PRIVATE UNICODE _UNICODE NOMINMAX
    WIN32_LEAN_AND_MEAN)
  set_property(TARGET ${TARGET} PROPERTY MSVC_RUNTIME_LIBRARY "${LUMA_APO_RUNTIME}")
endfunction()

add_library(luma_apo SHARED luma_apo.cpp luma_apo.def)
luma_apo_settings(luma_apo)
target_link_libraries(luma_apo PRIVATE ole32 shell32 audiomediatypecrt)

add_executable(luma_apo_setup WIN32 setup.cpp setup.manifest)
luma_apo_settings(luma_apo_setup)
target_link_libraries(luma_apo_setup PRIVATE advapi32 ole32 shell32)

add_executable(luma_apo_test EXCLUDE_FROM_ALL test/apo_test.cpp luma_apo.cpp)
luma_apo_settings(luma_apo_test)
target_compile_definitions(luma_apo_test PRIVATE LUMA_APO_TESTING)
target_link_libraries(luma_apo_test PRIVATE ole32 shell32 audiomediatypecrt)

if(DEFINED INSTALL_BUNDLE_LIB_DIR)
  install(TARGETS luma_apo luma_apo_setup
    RUNTIME DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()
