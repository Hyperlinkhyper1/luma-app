#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
setup_script=${1:-"$repo_root/tool/ci/ensure_android_ndk.sh"}
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
export ANDROID_HOME="$fixture/sdk"
export FLUTTER_ROOT="$fixture/flutter"
export NDK_TEST_STATE="$fixture/state"
mkdir -p "$fixture/bin" "$ANDROID_HOME/cmdline-tools/latest/bin" \
  "$FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin"
printf 'val ndkVersion: String = "28.2.13676358"\n' > \
  "$FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
export PATH="$fixture/bin:$PATH"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/bin/sleep"
chmod +x "$fixture/bin/sleep"

cat > "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "--sdk_root=$ANDROID_HOME" && "$2" == "--install" ]]
version=${3#ndk;}
ndk="$ANDROID_HOME/ndk/$version"
attempt=0
[[ ! -f "$NDK_TEST_STATE" ]] || attempt=$(cat "$NDK_TEST_STATE")
attempt=$((attempt + 1))
echo "$attempt" > "$NDK_TEST_STATE"
if [[ -e "$ndk" || -e "$ANDROID_HOME/.temp/corrupt.zip" ]]; then
  echo '[CXX1101] incomplete NDK or corrupt download was reused' >&2
  exit 1
fi
mkdir -p "$ndk" "$ANDROID_HOME/.temp"
if [[ "$NDK_TEST_MODE" == "always-fail" || ( "$NDK_TEST_MODE" == "fail-once" && "$attempt" == 1 ) ]]; then
  echo 'not a ZIP archive' > "$ANDROID_HOME/.temp/corrupt.zip"
  echo 'Archive is not a ZIP archive' >&2
  exit 1
fi
if [[ "$NDK_TEST_MODE" == "incomplete-once" && "$attempt" == 1 ]]; then
  exit 0
fi
printf 'Pkg.Revision = %s\n' "$version" > "$ndk/source.properties"
mkdir -p "$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin" "$ndk/build/cmake"
touch "$ndk/build/cmake/android.toolchain.cmake"
printf '#!/usr/bin/env bash\nexit 0\n' > "$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
chmod +x "$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
EOF
chmod +x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

run_setup() {
  bash "$setup_script" > "$fixture/output.log" 2>&1
}

for mode in fail-once incomplete-once always-fail; do
  rm -rf -- "$ANDROID_HOME/ndk/28.2.13676358" "$ANDROID_HOME/.temp"
  rm -f -- "$NDK_TEST_STATE"
  export NDK_TEST_MODE="$mode"
  mkdir -p "$ANDROID_HOME/ndk/28.2.13676358" "$ANDROID_HOME/ndk/other-version"
  echo keep > "$ANDROID_HOME/ndk/other-version/sentinel"
  if run_setup; then
    [[ "$mode" != always-fail ]]
    [[ $(cat "$NDK_TEST_STATE") == 2 ]]
    [[ -f "$ANDROID_HOME/ndk/28.2.13676358/source.properties" ]]
    run_setup
    [[ $(cat "$NDK_TEST_STATE") == 2 ]]
  else
    [[ "$mode" == always-fail ]]
    [[ $(cat "$NDK_TEST_STATE") == 3 ]]
    [[ ! -e "$ANDROID_HOME/ndk/28.2.13676358" ]]
    [[ ! -e "$ANDROID_HOME/.temp/corrupt.zip" ]]
    grep -q 'after 3 attempts' "$fixture/output.log"
  fi
  [[ $(cat "$ANDROID_HOME/ndk/other-version/sentinel") == keep ]]
  echo "PASS: $mode"
done

export NDK_TEST_MODE=success
rm -f -- "$NDK_TEST_STATE"
ndk_dir="$ANDROID_HOME/ndk/28.2.13676358"
mkdir -p "$ndk_dir"
echo 'Pkg.Revision = 27.0.0' > "$ndk_dir/source.properties"
run_setup
[[ $(cat "$NDK_TEST_STATE") == 1 ]]
rm -f -- "$ndk_dir/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
run_setup
[[ $(cat "$NDK_TEST_STATE") == 2 ]]
echo 'PASS: wrong revision and missing toolchain'

printf 'val ndkVersion: String = "29.0.12345678"\n' > \
  "$FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
run_setup
[[ -f "$ANDROID_HOME/ndk/29.0.12345678/source.properties" ]]
[[ -f "$ndk_dir/source.properties" ]]
echo 'PASS: follows Flutter NDK version'
