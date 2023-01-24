FROM swiftlang/swift:nightly-amazonlinux2

# swiftly build depdenencies
RUN yum install -y \
    curl \
    gcc \
    make \
    libsqlite3x-devel.x86_64 \
    sqlite-devel

COPY . /tmp/swiftly
WORKDIR /tmp/swiftly

RUN ./scripts/build-libarchive.sh
RUN SWIFTLY_CONFIGURATION=release ./scripts/build.sh /swiftly

RUN /swiftly --version
RUN ldd /swiftly
