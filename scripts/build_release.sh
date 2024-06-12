#!/usr/bin/env bash

set -o errexit

version="$1"

if [[ -z "$version" ]]; then
    echo "Usage: build_release.sh <version tag>"
    exit 1
fi

declare -a arches=("$(uname -m)")
# macOS is capable of using docker in both X86 and ARM64 if building from ARM64
if [[ "$(uname -m)" == "arm64" && "$(uname -s)" == "Darwin" ]]; then
    declare -a arches=("$(uname -m)" "x86_64")
fi

for raw_arch in "${arches[@]}"; do
    case "$raw_arch" in
        "x86_64")
            arch=""
            export DOCKER_DEFAULT_PLATFORM="linux/amd64"
            ;;

        "aarch64" | "arm64")
            arch="-aarch64"
            export DOCKER_DEFAULT_PLATFORM="linux/aarch64"
            ;;

        *)
            echo "Error: Unsupported CPU architecture: $raw_arch"
            ;;
    esac

    image_name="swiftly-$version"
    directory_name="swiftly-$version-RELEASE-linux$arch"
    docker build -t "$image_name" -f scripts/build.dockerfile .
    container_id=$(docker create "$image_name")
    tmp_dir=$(mktemp -d)
    bin_dir="$tmp_dir/$directory_name/usr/bin"
    mkdir -p "$bin_dir"
    docker cp "$container_id:/swiftly" "$bin_dir/swiftly-init"
    docker rm -v "$container_id"
    docker image rm -f "$image_name"

    archive_name="$directory_name.tar.gz"
    tar -C "$tmp_dir" -cf - "$directory_name" | gzip -c > "$archive_name"

    gpg --yes --output "$archive_name.sig" --detach-sig "$archive_name" || echo "WARNING: No signature was generated because GPG failed to create a signature"

    echo "$archive_name has been successfully built!"
done
