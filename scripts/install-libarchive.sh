#!/usr/bin/env bash

set -o errexit

# TODO detect platform
LIBARCHIVE_VERSION=3.6.1

mkdir /tmp/archive-build
pushd /tmp/archive-build
curl --remote-name \
     --location \
     "https://github.com/libarchive/libarchive/releases/download/v$LIBARCHIVE_VERSION/libarchive-$LIBARCHIVE_VERSION.tar.gz"
tar -xzf "libarchive-$LIBARCHIVE_VERSION.tar.gz"

cd "libarchive-$LIBARCHIVE_VERSION"
./configure \
    --enable-shared=no \
    --with-pic \
    --without-nettle \
    --without-openssl \
    --without-lzo2 \
    --without-expat \
    --without-xml2 \
    --without-bz2lib \
    --without-libb2 \
    --without-iconv \
    --without-zstd \
    --without-lzma \
    --without-lz4 \
    --disable-acl \
    --disable-bsdtar \
    --disable-bsdcat
make
make install
popd
