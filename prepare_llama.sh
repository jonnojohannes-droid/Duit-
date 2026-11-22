#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vendor/llama.cpp"
BUILD="$SRC/build-ios"
mkdir -p "$ROOT/vendor"

if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$SRC"
else
  git -C "$SRC" fetch --depth 1 origin
  git -C "$SRC" reset --hard FETCH_HEAD
fi

cmake -S "$SRC" -B "$BUILD" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.4 \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_CURL=OFF \
  -DGGML_NATIVE=OFF \
  -DGGML_METAL=ON \
  -DGGML_ACCELERATE=ON

cmake --build "$BUILD" --config Release --target llama --parallel
ARCHIVES=()
while IFS= read -r archive; do ARCHIVES+=("$archive"); done < <(find "$BUILD" -name '*.a' -type f | sort)
if [ "${#ARCHIVES[@]}" -eq 0 ]; then
  echo "No llama.cpp static libraries produced." >&2
  exit 1
fi
libtool -static -o "$BUILD/libbuie_llama.a" "${ARCHIVES[@]}"
test -s "$BUILD/libbuie_llama.a"
echo "Created $BUILD/libbuie_llama.a"
