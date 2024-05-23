# Dockerfile used to build a statically-linked swiftly executable for generic GNU/Linux platforms.
# See RELEASING.md for information on how to use this file.

FROM swift:5.10-amazonlinux2

# swiftly build depdenencies
RUN yum install -y \
    gpg \
    ca-certificates \
    gcc \
    make

COPY . /tmp/swiftly
WORKDIR /tmp/swiftly

RUN ./scripts/install-libarchive.sh

RUN swift build \
      --static-swift-stdlib \
      --configuration release

RUN mv .build/release/swiftly /swiftly
RUN strip /swiftly

RUN /swiftly --version
RUN ldd /swiftly
