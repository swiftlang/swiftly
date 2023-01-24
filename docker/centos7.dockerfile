FROM swiftlang/swift:nightly-main-centos7

# swiftly build depdenencies
RUN yum install -y \
    curl \
    gcc \
    make \
    libsqlite3x-devel.x86_64

# swift dependencies
RUN yum install -y \
      binutils \
      gcc \
      git \
      glibc-static \
      libbsd-devel \
      libedit \
      libedit-devel \
      libicu-devel \
      libstdc++-static \
      pkg-config \
      python2 \
      sqlite

RUN sed -i -e 's/\*__block/\*__libc_block/g' /usr/include/unistd.h

RUN curl \
    -L \
    -o toolchain.tar.gz \
    https://download.swift.org/development/centos7/swift-DEVELOPMENT-SNAPSHOT-2022-12-05-a/swift-DEVELOPMENT-SNAPSHOT-2022-12-05-a-centos7.tar.gz

RUN tar -xzf toolchain.tar.gz
RUN mkdir /tmp/swift && mv swift-DEVELOPMENT-SNAPSHOT-2022-12-05-a-ubuntu20.04/usr /tmp/swift
RUN ln -s /tmp/swift/usr/bin/swift /usr/bin/swift

COPY . /tmp/swiftly
WORKDIR /tmp/swiftly

RUN ./scripts/build-libarchive.sh
RUN SWIFTLY_CONFIGURATION=release ./scripts/build.sh /swiftly

RUN /swiftly --version
RUN ldd /swiftly
