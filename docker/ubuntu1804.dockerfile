FROM swiftlang/swift:nightly-bionic

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update

# swiftly build depdenencies
RUN apt-get install -y \
    curl \
    build-essential \
    libsqlite3-dev

COPY . /tmp/swiftly
WORKDIR /tmp/swiftly

RUN ./scripts/build-libarchive.sh
RUN SWIFTLY_CONFIGURATION=release ./scripts/build.sh /swiftly

RUN /swiftly --version
RUN ldd /swiftly
