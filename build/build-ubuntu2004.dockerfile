FROM swift/ubuntu2004:latest

COPY . /tmp/swiftly
WORKDIR /tmp/swiftly

RUN ./scripts/build.sh /swiftly

RUN /swiftly --version
RUN ldd /swiftly
