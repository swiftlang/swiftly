ARG base_image=swift:5.7-amazonlinux2
FROM $base_image
# needed to do again after FROM due to docker limitation
ARG swift_version
ARG ubuntu_version

# dependencies
RUN yum install -y \
    curl \
    gcc \
    make
COPY ./scripts/install-libarchive.sh /
RUN /install-libarchive.sh

# tools
RUN mkdir -p $HOME/.tools
RUN echo 'export PATH="$HOME/.tools:$PATH"' >> $HOME/.profile

# swiftformat (until part of the toolchain)

ARG swiftformat_version=0.49.18
RUN git clone --branch $swiftformat_version --depth 1 https://github.com/nicklockwood/SwiftFormat $HOME/.tools/swift-format
RUN cd $HOME/.tools/swift-format && swift build -c release
RUN ln -s $HOME/.tools/swift-format/.build/release/swiftformat $HOME/.tools/swiftformat
