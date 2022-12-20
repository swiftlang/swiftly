FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update

# swiftly build depdenencies
RUN apt-get install -y \
    curl \
    build-essential \
    libsqlite3-dev

# Swift dependencies.
RUN apt-get install -y \
          binutils \
          git \
          gnupg2 \
          libc6-dev \
          libcurl4 \
          libedit2 \
          libgcc-9-dev \
          libpython2.7 \
          libsqlite3-0 \
          libstdc++-9-dev \
          libxml2 \
          libz3-dev \
          pkg-config \
          tzdata \
          uuid-dev \
          zlib1g-dev

RUN curl \
    -L \
    -o toolchain.tar.gz \
    https://download.swift.org/development/ubuntu2004/swift-DEVELOPMENT-SNAPSHOT-2022-12-05-a/swift-DEVELOPMENT-SNAPSHOT-2022-12-05-a-ubuntu20.04.tar.gz

RUN tar -xzf toolchain.tar.gz
RUN mkdir /tmp/swift && mv swift-DEVELOPMENT-SNAPSHOT-2022-12-05-a-ubuntu20.04/usr /tmp/swift
RUN ln -s /tmp/swift/usr/bin/swift /usr/bin/swift

COPY ./scripts/build-libarchive.sh .
RUN ./build-libarchive.sh
