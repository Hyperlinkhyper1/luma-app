#!/usr/bin/env bash
set -euo pipefail

# For the dedicated Android CI runner: no other SDK install may run concurrently.
sdk_root=$(cd "${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK path is missing}}" && pwd -P)
[[ "$sdk_root" != / ]] || exit 1
flutter_extension="${FLUTTER_ROOT:?Flutter SDK path is missing}/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
ndk_version=$(sed -nE 's/^[[:space:]]*val ndkVersion: String = "([0-9.]+)".*/\1/p' "$flutter_extension")
if [[ ! "$ndk_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo '::error::Could not determine Flutter NDK version.' >&2
  exit 1
fi
ndk_dir="$sdk_root/ndk/$ndk_version"

ndk_valid() {
  [[ -f "$ndk_dir/source.properties" ]] || return 1
  local installed_version
  installed_version=$(sed -nE 's/^Pkg\.Revision[[:space:]]*=[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' "$ndk_dir/source.properties")
  [[ "$installed_version" == "$ndk_version" && \
    -x "$ndk_dir/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" && \
    -f "$ndk_dir/build/cmake/android.toolchain.cmake" ]]
}

if ndk_valid; then
  echo "NDK $ndk_version is already installed and verified."
  exit 0
fi

sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x "$sdkmanager" ]]; then
  sdkmanager=$(command -v sdkmanager)
fi

clear_failed_install() {
  rm -rf -- "$ndk_dir" "$sdk_root/.temp"
}

for attempt in 1 2 3; do
  clear_failed_install
  echo "Installing NDK $ndk_version (attempt $attempt/3)."
  if { yes || true; } | "$sdkmanager" --sdk_root="$sdk_root" --install "ndk;$ndk_version" && ndk_valid; then
    echo "NDK $ndk_version installed and verified."
    exit 0
  fi
  echo "::warning::NDK $ndk_version installation failed or is incomplete."
  clear_failed_install
  if [[ "$attempt" -lt 3 ]]; then
    sleep 30
  fi
done

echo "::error::Could not install a complete NDK $ndk_version after 3 attempts." >&2
exit 1
