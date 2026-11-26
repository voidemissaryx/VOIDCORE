#!/usr/bin/env bash
# Fetches Tor Project's official Android expert bundles and installs, per ABI:
#   tor      → android/app/src/main/jniLibs/<abi>/libtor.so
#   lyrebird → android/app/src/main/jniLibs/<abi>/liblyrebird.so
# plus Tor GeoIP data and pluggable transport configuration as app assets.
# SHA-256 values are pinned from Tor Project's signed build manifest:
# https://archive.torproject.org/tor-package-archive/torbrowser/16.0/sha256sums-signed-build.txt
# Paths are relative to this script (scripts/), so it runs from anywhere.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=16.0
# The 16.0 expert bundles are hosted in Tor Project's package archive.
# Keep the official EFF mirror as a fallback.
MIRRORS=(
  "https://archive.torproject.org/tor-package-archive/torbrowser/$VERSION"
  "https://tor.eff.org/dist/torbrowser/$VERSION"
)
JNI=../android/app/src/main/jniLibs
ASSETS=../android/app/src/main/assets

declare -A ABI=([aarch64]=arm64-v8a [armv7]=armeabi-v7a [x86_64]=x86_64)
declare -A SHA=(
  [aarch64]=bf8f4c63652fd7daa62288713c7fa512f244a5b972808f6251450e5fdfca9120
  [armv7]=13befa352b64c32ba460b63066179bb1c9eaf6c3ea7057ae860dcdd22b8acf7b
  [x86_64]=ab3152ba164bcd49e50175086c62e40ffa2bf9002a4f6473f77111bd88b0462b
)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for arch in aarch64 armv7 x86_64; do
  file="tor-expert-bundle-android-$arch-$VERSION.tar.gz"
  echo "fetching $file"
  downloaded=false
  for base in "${MIRRORS[@]}"; do
    if curl -fsSL --retry 2 --connect-timeout 20 -o "$TMP/$file" "$base/$file"; then
      if echo "${SHA[$arch]}  $TMP/$file" | sha256sum -c --quiet -; then
        downloaded=true
        break
      fi
      echo "Checksum verification failed from $base; trying the next official mirror." >&2
      rm -f "$TMP/$file"
    else
      echo "Download failed from $base; trying the next official mirror." >&2
    fi
  done
  if [ "$downloaded" != true ]; then
    echo "Unable to fetch and verify $file from any configured official mirror." >&2
    exit 1
  fi
  mkdir -p "$TMP/$arch" "$JNI/${ABI[$arch]}"
  tar -xzf "$TMP/$file" -C "$TMP/$arch"
  cp "$TMP/$arch/tor/libTor.so" "$JNI/${ABI[$arch]}/libtor.so"
  cp "$TMP/$arch/tor/pluggable_transports/lyrebird" "$JNI/${ABI[$arch]}/liblyrebird.so"
done

cp "$TMP/aarch64/data/geoip" "$ASSETS/tor_geoip"
cp "$TMP/aarch64/data/geoip6" "$ASSETS/tor_geoip6"
cp "$TMP/aarch64/tor/pluggable_transports/pt_config.json" "$ASSETS/tor_pt_config.json"
ls -la "$JNI"/*/libtor.so "$JNI"/*/liblyrebird.so "$ASSETS"/tor_*
