#!/bin/bash
#
# Usage: get_release_info.sh url|name|version
#
# ORCASLICER_VERSION  release tag to use, e.g. v2.4.2 (default: latest)
# ORCASLICER_ARCH     amd64|arm64 (default: this machine's architecture)

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Wrong number of params" >&2
  exit 1
fi
request=$1

version="${ORCASLICER_VERSION:-latest}"
if [ "$version" = "latest" ]; then
  api="https://api.github.com/repos/SoftFever/OrcaSlicer/releases/latest"
else
  api="https://api.github.com/repos/SoftFever/OrcaSlicer/releases/tags/${version}"
fi

case "${ORCASLICER_ARCH:-$(uname -m)}" in
  x86_64|amd64) want_arm=false ;;
  aarch64|arm64) want_arm=true ;;
  *) echo "Unsupported architecture: ${ORCASLICER_ARCH:-$(uname -m)}" >&2; exit 1 ;;
esac

release=$(curl -fsSL "$api")

# Newer releases publish an AppImage per architecture (x86_64 builds are
# unmarked, arm builds contain "aarch64"), and some releases have more than one
# x86_64 AppImage. Pick exactly one: matching architecture, preferring the
# Ubuntu 24.04 build to match the base image.
asset=$(jq -c --argjson want_arm "$want_arm" '
  [.assets[]
    | select(.name | test("_Linux.*\\.AppImage$"))
    | select((.name | test("aarch64|arm64")) == $want_arm)]
  | (map(select(.name | test("Ubuntu2404"))) + .)
  | first // empty' <<<"$release")

if [ -z "$asset" ] && [ "$request" != "version" ]; then
  echo "No matching Linux AppImage found in release $(jq -r .tag_name <<<"$release")" >&2
  exit 1
fi

case $request in
  url)
    jq -r .browser_download_url <<<"$asset"
    ;;
  name)
    jq -r .name <<<"$asset"
    ;;
  version)
    jq -r .tag_name <<<"$release"
    ;;
  *)
    echo "Unknown request" >&2
    exit 1
    ;;
esac
