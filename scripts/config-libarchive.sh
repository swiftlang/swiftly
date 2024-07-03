#!/usr/bin/env bash

# Run this script when vendoring a newer version of libarchive to get a fresh
# config.h

set -o errexit

if [ "$(uname -s)" != "Linux" ]; then
    echo "Try this script again from Linux"
    exit 1
fi

if ! command -v cmake &> /dev/null
then
    echo "Install cmake and try again"
    exit 1
fi

thisdir=$(dirname "$0")

pushd "$thisdir/../libarchive"

cmake \
    -DENABLE_NETTLE=OFF \
    -DENABLE_OPENSSL=OFF \
    -DENABLE_LZO=OFF \
    -DENABLE_EXPAT=OFF \
    -DENABLE_LIBXML2=OFF \
    -DENABLE_BZip2=OFF \
    -DENABLE_LIBB2=OFF \
    -DENABLE_ICONV=OFF \
    -DENABLE_ZSTD=OFF \
    -DENABLE_LZMA=OFF \
    -DENABLE_LZ4=OFF \
    -DENABLE_ACL=OFF \
    -DENABLE_CAT=OFF \
    -DENABLE_CPIO=OFF \
    -DENABLE_LIBGCC=OFF \
    -DENABLE_UNZIP=OFF \
    -DENABLE_XATTR=OFF \
    .

# There's a couple of options that aren't covered by the cmake options that can trip up builds
cat config.h | sed 's/#define HAVE_LIBXML_XMLREADER_H 1/#define HAVE_LIBXML_XMLREADER_H 0/' > config-edit.h
cat config-edit.h | sed 's/#define HAVE_LIBXML_XMLWRITER_H 1/#define HAVE_LIBXML_XMLWRITER_H 0/' > config.h
rm config-edit.h

# Symlink the generated config header into a place where SwiftPM will pick it up
rm libarchive/config.h || echo -n
ln -s ../config.h libarchive/config.h

popd
