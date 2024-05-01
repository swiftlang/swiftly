#!/usr/bin/env bash

set -o errexit

version="$1"

if [[ -z "$version" ]]; then
    echo "Usage: build_release.sh <version tag>"
    exit 1
fi

raw_arch="$(uname -m)"
case "$raw_arch" in
    "x86_64")
        arch="x86_64"
        ;;

    "aarch64" | "arm64")
        arch="aarch64"
        ;;

    *)
        echo "Error: Unsupported CPU architecture: $raw_arch"
        ;;
esac

git checkout "$version"

if [[ ! -z "$(git status --porcelain=v1 2>/dev/null)" ]]; then
    echo "There are uncommitted changes in the local tree, please commit or discard them"
    exit 1
fi

image_name="swiftly-$version"
binary_name="swiftly-$arch-unknown-linux-gnu"
docker build -t "$image_name" -f scripts/build.dockerfile .
container_id=$(docker create "$image_name")
docker cp "$container_id:/swiftly" "$binary_name"
docker rm -v "$container_id"
docker image rm -f "$image_name"

"./$binary_name" --version > /dev/null

echo "$binary_name has been successfully built!"
